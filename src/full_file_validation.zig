//! End-to-end validation routing for one complete in-memory RAW file.

const std = @import("std");
const classification = @import("classification.zig");
const nef_sensor = @import("nef_sensor.zig");
const nikon_huffman = @import("nikon_huffman.zig");
const sensor_validation = @import("sensor_validation.zig");
const sony_sensor = @import("sony_sensor.zig");
const tiff_adapter = @import("tiff_adapter.zig");

pub const ContainerFailure = enum {
    malformed_tiff,
    invalid_semantic_tag,
    limit_exceeded,
    unsupported_tiff_feature,
};

pub const Rejection = union(enum) {
    container: ContainerFailure,
    not_camera_raw: classification.Format,
    sensor: sensor_validation.Failure,
};

pub const Acceptance = struct {
    format: classification.Format,
    reach: union(enum) {
        full: void,
        structural: sensor_validation.ReachReason,
    },
};

pub const Result = union(enum) {
    accepted: Acceptance,
    rejected: Rejection,
};

pub const Error = error{
    OutOfMemory,
    Io,
    Internal,
};

/// Route a complete TIFF-family RAW through every first-party check that rawz
/// can reach from the file alone. Unsupported sensor codecs remain accepted at
/// structural reach; malformed containers, metadata and payload syntax reject.
pub fn validate(allocator: std.mem.Allocator, bytes: []const u8) Error!Result {
    const format = tiff_adapter.classifyBuffer(allocator, bytes) catch |err| switch (err) {
        error.MalformedTiff => return rejectContainer(.malformed_tiff),
        error.InvalidSemanticTag => return rejectContainer(.invalid_semantic_tag),
        error.LimitExceeded => return rejectContainer(.limit_exceeded),
        error.UnsupportedTiffFeature => return rejectContainer(.unsupported_tiff_feature),
        error.OutOfMemory => return error.OutOfMemory,
        error.Io => return error.Io,
        error.Internal, error.InvalidArgument => return error.Internal,
    };

    return switch (format) {
        .tiff, .raw_unknown => .{ .rejected = .{ .not_camera_raw = format } },
        .arw => validateSony(allocator, bytes),
        .nef => validateNikon(allocator, bytes),
        .dng, .cr2, .orf, .pef, .three_fr, .rw2 => acceptStructural(
            format,
            .unsupported_compression,
        ),
    };
}

fn validateSony(allocator: std.mem.Allocator, bytes: []const u8) Error!Result {
    const located = try sony_sensor.locateSensorPayload(allocator, bytes);
    return switch (located) {
        .structural => |reason| acceptStructural(.arw, reason),
        .fail => |failure| rejectSensor(failure),
        .payload => |payload| blk: {
            const start: usize = @intCast(payload.host_offset);
            const end: usize = @intCast(payload.host_offset + payload.byte_count);
            break :blk fromSensorResult(.arw, sony_sensor.validateCompressed(.{
                .payload = bytes[start..end],
                .width = payload.width,
                .height = payload.height,
                .bits_per_sample = payload.bits_per_sample,
            }));
        },
    };
}

fn validateNikon(allocator: std.mem.Allocator, bytes: []const u8) Error!Result {
    const located = try nef_sensor.locateSensorPayload(allocator, bytes);
    const payload = switch (located) {
        .structural => |reason| return acceptStructural(.nef, reason),
        .fail => |failure| return rejectSensor(failure),
        .payload => |value| value,
    };
    if (payload.codec == .uncompressed_words) {
        return acceptStructural(.nef, .metadata_levels_unavailable);
    }

    const located_metadata = try nef_sensor.locateHuffmanMetadata(allocator, bytes);
    const metadata = switch (located_metadata) {
        .structural => |reason| return acceptStructural(.nef, reason),
        .fail => |failure| return rejectSensor(failure),
        .metadata => |value| value,
    };
    const payload_start: usize = @intCast(payload.host_offset);
    const payload_end: usize = @intCast(payload.host_offset + payload.byte_count);
    const metadata_start: usize = @intCast(metadata.host_offset);
    const metadata_end: usize = @intCast(metadata.host_offset + metadata.byte_count);
    return fromSensorResult(.nef, nikon_huffman.validate(.{
        .payload = bytes[payload_start..payload_end],
        .width = payload.width,
        .height = payload.height,
        .bits_per_sample = payload.bits_per_sample,
        .linearization_table = bytes[metadata_start..metadata_end],
        .metadata_byte_order = metadata.byte_order,
    }));
}

fn fromSensorResult(format: classification.Format, result: sensor_validation.Result) Result {
    return switch (result) {
        .full => .{ .accepted = .{ .format = format, .reach = .{ .full = {} } } },
        .structural => |reason| acceptStructural(format, reason),
        .fail => |failure| rejectSensor(failure),
    };
}

fn acceptStructural(format: classification.Format, reason: sensor_validation.ReachReason) Result {
    return .{ .accepted = .{ .format = format, .reach = .{ .structural = reason } } };
}

fn rejectSensor(failure: sensor_validation.Failure) Result {
    return .{ .rejected = .{ .sensor = failure } };
}

fn rejectContainer(failure: ContainerFailure) Result {
    return .{ .rejected = .{ .container = failure } };
}

fn putU16(bytes: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, bytes[offset..][0..2], value, .little);
}

fn putU32(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
}

fn putEntry(bytes: []u8, offset: usize, tag: u16, field_type: u16, count: u32, value: u32) void {
    putU16(bytes, offset, tag);
    putU16(bytes, offset + 2, field_type);
    putU32(bytes, offset + 4, count);
    putU32(bytes, offset + 8, value);
}

fn validSonyArw() [192]u8 {
    var bytes = [_]u8{0} ** 192;
    bytes[0..2].* = "II".*;
    putU16(&bytes, 2, 42);
    putU32(&bytes, 4, 8);

    putU16(&bytes, 8, 3);
    putEntry(&bytes, 10, 271, 2, 5, 50); // Make = SONY
    putEntry(&bytes, 22, 330, 4, 1, 56); // CFA SubIFD
    putEntry(&bytes, 34, 37500, 7, 1, 1); // MakerNote evidence
    putU32(&bytes, 46, 0);
    bytes[50..55].* = "SONY\x00".*;

    putU16(&bytes, 56, 7);
    putEntry(&bytes, 58, 256, 4, 1, 32);
    putEntry(&bytes, 70, 257, 4, 1, 1);
    putEntry(&bytes, 82, 258, 3, 1, 14);
    putEntry(&bytes, 94, 259, 3, 1, 32767);
    putEntry(&bytes, 106, 262, 3, 1, 32803);
    putEntry(&bytes, 118, 273, 4, 1, 160);
    putEntry(&bytes, 130, 279, 4, 1, 32);
    putU32(&bytes, 142, 0);

    bytes[160..164].* = .{ 0x64, 0x20, 0x03, 0x04 };
    bytes[176..180].* = .{ 0x64, 0x20, 0x03, 0x04 };
    return bytes;
}

test "full-file routing accepts one pristine RAW and rejects container and sensor damage" {
    const valid = validSonyArw();
    try std.testing.expectEqual(
        Result{ .accepted = .{
            .format = .arw,
            .reach = .{ .structural = .analytical_ceiling_unestablished },
        } },
        try validate(std.testing.allocator, &valid),
    );

    var invalid_packet = valid;
    invalid_packet[160] = 0x63;
    try std.testing.expectEqual(
        Result{ .rejected = .{ .sensor = .{
            .code = .invalid_packet_header,
            .region = .payload,
            .byte_offset = 0,
        } } },
        try validate(std.testing.allocator, &invalid_packet),
    );

    try std.testing.expectEqual(
        Result{ .rejected = .{ .container = .malformed_tiff } },
        try validate(std.testing.allocator, "not a TIFF"),
    );
}
