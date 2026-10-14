//! Sony ARW2 compressed sensor-payload validation.

const std = @import("std");
const tiffz = @import("tiffz");
const sensor_validation = @import("sensor_validation.zig");

const sub_ifds_tag: u16 = 330;

pub const Input = struct {
    payload: []const u8,
    width: u32,
    height: u32,
    bits_per_sample: u8,
};

pub const compression_arw2: u16 = 32767;

pub const Payload = struct {
    host_offset: u64,
    byte_count: u64,
    width: u32,
    height: u32,
    bits_per_sample: u8,
};

pub const LocateResult = union(enum) {
    payload: Payload,
    structural: sensor_validation.ReachReason,
    fail: sensor_validation.Failure,
};

pub fn locateSensorPayload(
    allocator: std.mem.Allocator,
    bytes: []const u8,
) error{OutOfMemory}!LocateResult {
    var handle = tiffz.source.BufferHandle.init(bytes);
    const source = tiffz.Source.fromBuffer(&handle);
    const limits: tiffz.Limits = .{};
    const header = tiffz.header.parse(source) catch
        return locateFailure(.malformed_metadata, 0);
    const offset_width: tiffz.ifd.OffsetWidth = if (header.bigtiff) .big else .classic;

    var primary = tiffz.ifd.parse(
        allocator,
        source,
        header.endian,
        header.ifd0_offset,
        limits,
        offset_width,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return locateFailure(.malformed_metadata, header.ifd0_offset),
    };
    defer primary.deinit();

    const sub_ifds = primary.get(sub_ifds_tag) orelse
        return .{ .structural = .unsupported_metadata_layout };
    if (sub_ifds.count == 0 or sub_ifds.count > limits.max_ifds) {
        return locateFailure(.malformed_metadata, header.ifd0_offset);
    }
    switch (sub_ifds.field_type) {
        .long, .long8, .ifd8 => {},
        else => return locateFailure(.malformed_metadata, header.ifd0_offset),
    }

    var index: u32 = 0;
    while (index < sub_ifds.count) : (index += 1) {
        const child_offset = primary.arrayElementU64(
            sub_ifds_tag,
            index,
            header.endian,
            source,
        ) catch return locateFailure(.malformed_metadata, header.ifd0_offset);
        var child = tiffz.ifd.parse(
            allocator,
            source,
            header.endian,
            child_offset,
            limits,
            offset_width,
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return locateFailure(.malformed_metadata, child_offset),
        };
        defer child.deinit();

        const photometric = readSingle(&child, tiffz.tags.photometric, header.endian, source) catch
            return locateFailure(.malformed_metadata, child_offset);
        if (photometric == null or photometric.? != tiffz.tags.photometric_color_filter_array) continue;
        return locateInSensorIfd(bytes.len, source, header.endian, child_offset, &child);
    }

    return .{ .structural = .unsupported_metadata_layout };
}

fn locateInSensorIfd(
    source_len: usize,
    source: tiffz.Source,
    endian: tiffz.header.Endian,
    ifd_offset: u64,
    dir: *const tiffz.ifd.Ifd,
) LocateResult {
    const width_value = readSingle(dir, tiffz.tags.image_width, endian, source) catch
        return locateFailure(.malformed_metadata, ifd_offset);
    const height_value = readSingle(dir, tiffz.tags.image_length, endian, source) catch
        return locateFailure(.malformed_metadata, ifd_offset);
    const bits_value = readSingle(dir, tiffz.tags.bits_per_sample, endian, source) catch
        return locateFailure(.malformed_metadata, ifd_offset);
    const compression_value = readSingle(dir, tiffz.tags.compression, endian, source) catch
        return locateFailure(.malformed_metadata, ifd_offset);
    if (width_value == null or height_value == null or bits_value == null or compression_value == null) {
        return locateFailure(.malformed_metadata, ifd_offset);
    }
    if (width_value.? == 0 or height_value.? == 0 or
        width_value.? > std.math.maxInt(u32) or height_value.? > std.math.maxInt(u32))
    {
        return locateFailure(.invalid_dimensions, ifd_offset);
    }
    if (bits_value.? > std.math.maxInt(u8) or compression_value.? > std.math.maxInt(u16)) {
        return locateFailure(.malformed_metadata, ifd_offset);
    }
    if (compression_value.? != compression_arw2) {
        return .{ .structural = .unsupported_compression };
    }

    const offsets = dir.get(tiffz.tags.strip_offsets) orelse
        return locateFailure(.malformed_metadata, ifd_offset);
    const counts = dir.get(tiffz.tags.strip_byte_counts) orelse
        return locateFailure(.malformed_metadata, ifd_offset);
    if (offsets.count != 1 or counts.count != 1) {
        return .{ .structural = .unsupported_metadata_layout };
    }
    const host_offset = dir.arrayElementU64(tiffz.tags.strip_offsets, 0, endian, source) catch
        return locateFailure(.malformed_metadata, ifd_offset);
    const byte_count = dir.arrayElementU64(tiffz.tags.strip_byte_counts, 0, endian, source) catch
        return locateFailure(.malformed_metadata, ifd_offset);
    if (byte_count == 0) return locateFailure(.malformed_metadata, ifd_offset);
    const payload_end = std.math.add(u64, host_offset, byte_count) catch
        return locateFailure(.metadata_out_of_bounds, ifd_offset);
    if (payload_end > source_len) {
        return locateFailure(.metadata_out_of_bounds, ifd_offset);
    }

    return .{ .payload = .{
        .host_offset = host_offset,
        .byte_count = byte_count,
        .width = @intCast(width_value.?),
        .height = @intCast(height_value.?),
        .bits_per_sample = @intCast(bits_value.?),
    } };
}

fn readSingle(
    dir: *const tiffz.ifd.Ifd,
    tag: u16,
    endian: tiffz.header.Endian,
    source: tiffz.Source,
) !?u64 {
    const entry = dir.get(tag) orelse return null;
    if (entry.count != 1) return error.Malformed;
    return try dir.arrayElementU64(tag, 0, endian, source);
}

fn locateFailure(code: sensor_validation.ErrorCode, byte_offset: u64) LocateResult {
    return .{ .fail = .{
        .code = code,
        .region = .metadata,
        .byte_offset = byte_offset,
    } };
}

/// Validate the fixed-width packet grammar used by the admitted ARW2 cRAW
/// variant. Successful syntax remains structural until its analytical ceiling
/// and external mutation evidence are complete.
pub fn validateCompressed(input: Input) sensor_validation.Result {
    if (input.width == 0 or input.height == 0) {
        return metadataFailure(.invalid_dimensions, 0);
    }
    if (input.bits_per_sample != 14 or input.width % 32 != 0) {
        return .{ .structural = .unsupported_metadata_layout };
    }

    const expected_len = std.math.mul(u64, input.width, input.height) catch
        return metadataFailure(.invalid_dimensions, 0);
    const actual_len: u64 = @intCast(input.payload.len);
    if (actual_len < expected_len) return payloadFailure(.truncated, actual_len);
    if (actual_len > expected_len) return payloadFailure(.trailing_mismatch, expected_len);

    var packet_offset: usize = 0;
    while (packet_offset < input.payload.len) : (packet_offset += 16) {
        const word = std.mem.readInt(u32, input.payload[packet_offset..][0..4], .little);
        const maximum: u11 = @truncate(word);
        const minimum: u11 = @truncate(word >> 11);
        const maximum_position: u4 = @truncate(word >> 22);
        const minimum_position: u4 = @truncate(word >> 26);
        if (maximum < minimum or
            (maximum != minimum and maximum_position == minimum_position))
        {
            return payloadFailure(.invalid_packet_header, @intCast(packet_offset));
        }
    }

    return .{ .structural = .analytical_ceiling_unestablished };
}

fn metadataFailure(code: sensor_validation.ErrorCode, byte_offset: u64) sensor_validation.Result {
    return .{ .fail = .{
        .code = code,
        .region = .metadata,
        .byte_offset = byte_offset,
    } };
}

fn payloadFailure(code: sensor_validation.ErrorCode, byte_offset: u64) sensor_validation.Result {
    return .{ .fail = .{
        .code = code,
        .region = .payload,
        .byte_offset = byte_offset,
    } };
}

fn validTwoPacketRow() [32]u8 {
    var payload = [_]u8{0} ** 32;
    // max == min == 100, with distinct extrema positions 0 and 1.
    payload[0..4].* = .{ 0x64, 0x20, 0x03, 0x04 };
    payload[16..20].* = .{ 0x64, 0x20, 0x03, 0x04 };
    return payload;
}

test "classifies ARW2 packet grammar over valid malformed and legal counterexample sets" {
    const expected_reach = sensor_validation.Result{
        .structural = .analytical_ceiling_unestablished,
    };
    const expected_header_failure = sensor_validation.Result{ .fail = .{
        .code = .invalid_packet_header,
        .region = .payload,
        .byte_offset = 0,
    } };

    const valid = validTwoPacketRow();
    var max_below_min = valid;
    max_below_min[0] = 0x63;
    var coincident_extrema = valid;
    coincident_extrema[0..4].* = .{ 0x64, 0x90, 0x41, 0x04 };
    var delta_above_stored_max = valid;
    // max=100, min=0, then a legal seven-bit delta of 127 for sample 2.
    delta_above_stored_max[0..5].* = .{ 0x64, 0x00, 0x00, 0xc4, 0x1f };

    const cases = [_]struct {
        name: []const u8,
        payload: []const u8,
        expected: sensor_validation.Result,
    }{
        .{ .name = "legal max equals min", .payload = &valid, .expected = expected_reach },
        .{ .name = "maximum below minimum", .payload = &max_below_min, .expected = expected_header_failure },
        .{ .name = "coincident extrema positions", .payload = &coincident_extrema, .expected = expected_header_failure },
        .{ .name = "legal delta above stored maximum", .payload = &delta_above_stored_max, .expected = expected_reach },
        .{
            .name = "one byte truncated",
            .payload = valid[0..31],
            .expected = .{ .fail = .{
                .code = .truncated,
                .region = .payload,
                .byte_offset = 31,
            } },
        },
    };

    for (cases) |case| {
        std.testing.expectEqual(
            case.expected,
            validateCompressed(.{
                .payload = case.payload,
                .width = 32,
                .height = 1,
                .bits_per_sample = 14,
            }),
        ) catch |err| {
            std.debug.print("ARW2 packet case failed: {s}\n", .{case.name});
            return err;
        };
    }
}

test "rejects trailing ARW2 bytes at the exact declared payload end" {
    var payload = [_]u8{0} ** 33;
    const valid = validTwoPacketRow();
    @memcpy(payload[0..32], &valid);

    try std.testing.expectEqual(
        sensor_validation.Result{ .fail = .{
            .code = .trailing_mismatch,
            .region = .payload,
            .byte_offset = 32,
        } },
        validateCompressed(.{
            .payload = &payload,
            .width = 32,
            .height = 1,
            .bits_per_sample = 14,
        }),
    );
}

test "locates one exact ARW2 CFA strip and rejects its truncated file peer" {
    const arw = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x4a\x01\x04\x00\x01\x00\x00\x00\x1a\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x07\x00" ++
        "\x00\x01\x04\x00\x01\x00\x00\x00\x20\x00\x00\x00" ++
        "\x01\x01\x04\x00\x01\x00\x00\x00\x01\x00\x00\x00" ++
        "\x02\x01\x03\x00\x01\x00\x00\x00\x0e\x00\x00\x00" ++
        "\x03\x01\x03\x00\x01\x00\x00\x00\xff\x7f\x00\x00" ++
        "\x06\x01\x03\x00\x01\x00\x00\x00\x23\x80\x00\x00" ++
        "\x11\x01\x04\x00\x01\x00\x00\x00\x80\x00\x00\x00" ++
        "\x17\x01\x04\x00\x01\x00\x00\x00\x20\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" ++
        "\x64\x20\x03\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" ++
        "\x64\x20\x03\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    try std.testing.expectEqual(@as(usize, 160), arw.len);

    try std.testing.expectEqual(
        LocateResult{ .payload = .{
            .host_offset = 128,
            .byte_count = 32,
            .width = 32,
            .height = 1,
            .bits_per_sample = 14,
        } },
        try locateSensorPayload(std.testing.allocator, arw),
    );
    try std.testing.expectEqual(
        LocateResult{ .fail = .{
            .code = .metadata_out_of_bounds,
            .region = .metadata,
            .byte_offset = 26,
        } },
        try locateSensorPayload(std.testing.allocator, arw[0 .. arw.len - 1]),
    );
}
