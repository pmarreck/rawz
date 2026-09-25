//! Nikon NEF sensor-payload discovery.

const std = @import("std");
const tiffz = @import("tiffz");
const sensor_validation = @import("sensor_validation.zig");

const sub_ifds_tag: u16 = 330;
pub const compression_nikon_huffman: u16 = 34713;

pub const Codec = enum(u16) {
    uncompressed_words = 0,
    nikon_huffman = 1,
};

pub const Payload = struct {
    codec: Codec,
    compression: u16,
    host_offset: u64,
    byte_count: u64,
    width: u32,
    height: u32,
    bits_per_sample: u8,
    byte_order: std.builtin.Endian,
};

pub const LocateResult = union(enum) {
    payload: Payload,
    structural: sensor_validation.ReachReason,
    fail: sensor_validation.Failure,
};

/// Locate the CFA sensor SubIFD and collapse its strips only when they form one
/// exact contiguous range. Returned offsets are relative to the complete NEF.
pub fn locateSensorPayload(
    allocator: std.mem.Allocator,
    bytes: []const u8,
) error{OutOfMemory}!LocateResult {
    var handle = tiffz.source.BufferHandle.init(bytes);
    const source = tiffz.Source.fromBuffer(&handle);
    const limits: tiffz.Limits = .{};
    const header = tiffz.header.parse(source) catch {
        return metadataFailure(.malformed_metadata, 0);
    };
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
        else => return metadataFailure(.malformed_metadata, header.ifd0_offset),
    };
    defer primary.deinit();

    const sub_ifds = primary.get(sub_ifds_tag) orelse
        return .{ .structural = .unsupported_metadata_layout };
    if (sub_ifds.count == 0 or sub_ifds.count > std.math.maxInt(u32)) {
        return metadataFailure(.malformed_metadata, header.ifd0_offset);
    }
    if (sub_ifds.count > limits.max_ifds) {
        return metadataFailure(.work_limit_exceeded, header.ifd0_offset);
    }
    switch (sub_ifds.field_type) {
        .long, .long8, .ifd8 => {},
        else => return metadataFailure(.malformed_metadata, header.ifd0_offset),
    }

    var index: u32 = 0;
    while (index < sub_ifds.count) : (index += 1) {
        const child_offset = primary.arrayElementU64(
            sub_ifds_tag,
            index,
            header.endian,
            source,
        ) catch return metadataFailure(.malformed_metadata, header.ifd0_offset);
        var child = tiffz.ifd.parse(
            allocator,
            source,
            header.endian,
            child_offset,
            limits,
            offset_width,
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return metadataFailure(.malformed_metadata, child_offset),
        };
        defer child.deinit();

        const photometric = readSingle(&child, tiffz.tags.photometric, header.endian, source) catch
            return metadataFailure(.malformed_metadata, child_offset);
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
        return metadataFailure(.malformed_metadata, ifd_offset);
    const height_value = readSingle(dir, tiffz.tags.image_length, endian, source) catch
        return metadataFailure(.malformed_metadata, ifd_offset);
    const bits_value = readSingle(dir, tiffz.tags.bits_per_sample, endian, source) catch
        return metadataFailure(.malformed_metadata, ifd_offset);
    const compression_value = readSingle(dir, tiffz.tags.compression, endian, source) catch
        return metadataFailure(.malformed_metadata, ifd_offset);
    if (width_value == null or height_value == null or bits_value == null or compression_value == null) {
        return metadataFailure(.malformed_metadata, ifd_offset);
    }
    if (width_value.? == 0 or height_value.? == 0 or
        width_value.? > std.math.maxInt(u32) or height_value.? > std.math.maxInt(u32))
    {
        return metadataFailure(.invalid_dimensions, ifd_offset);
    }
    if (bits_value.? > std.math.maxInt(u8) or compression_value.? > std.math.maxInt(u16)) {
        return metadataFailure(.malformed_metadata, ifd_offset);
    }

    const codec: Codec = switch (@as(u16, @intCast(compression_value.?))) {
        tiffz.tags.compression_none => .uncompressed_words,
        compression_nikon_huffman => .nikon_huffman,
        else => return .{ .structural = .unsupported_compression },
    };

    const offsets_entry = dir.get(tiffz.tags.strip_offsets) orelse
        return metadataFailure(.malformed_metadata, ifd_offset);
    const counts_entry = dir.get(tiffz.tags.strip_byte_counts) orelse
        return metadataFailure(.malformed_metadata, ifd_offset);
    if (offsets_entry.count == 0 or offsets_entry.count != counts_entry.count or
        offsets_entry.count > std.math.maxInt(u32))
    {
        return metadataFailure(.malformed_metadata, ifd_offset);
    }

    var first_offset: u64 = 0;
    var combined_end: u64 = 0;
    var strip_index: u32 = 0;
    while (strip_index < offsets_entry.count) : (strip_index += 1) {
        const offset = dir.arrayElementU64(tiffz.tags.strip_offsets, strip_index, endian, source) catch
            return metadataFailure(.malformed_metadata, ifd_offset);
        const count = dir.arrayElementU64(tiffz.tags.strip_byte_counts, strip_index, endian, source) catch
            return metadataFailure(.malformed_metadata, ifd_offset);
        if (count == 0) return metadataFailure(.malformed_metadata, ifd_offset);
        if (strip_index == 0) {
            first_offset = offset;
            combined_end = offset;
        } else if (offset != combined_end) {
            return .{ .structural = .unsupported_metadata_layout };
        }
        combined_end = std.math.add(u64, combined_end, count) catch
            return metadataFailure(.metadata_out_of_bounds, ifd_offset);
    }
    if (combined_end > source_len) {
        return metadataFailure(.metadata_out_of_bounds, ifd_offset);
    }
    const byte_count = combined_end - first_offset;

    const width: u32 = @intCast(width_value.?);
    const height: u32 = @intCast(height_value.?);
    const bits_per_sample: u8 = @intCast(bits_value.?);
    if (codec == .uncompressed_words) {
        if (bits_per_sample != 12 and bits_per_sample != 14) {
            return .{ .structural = .unsupported_metadata_layout };
        }
        const samples = std.math.mul(u64, width, height) catch
            return metadataFailure(.invalid_dimensions, ifd_offset);
        const expected_bytes = std.math.mul(u64, samples, 2) catch
            return metadataFailure(.invalid_dimensions, ifd_offset);
        if (byte_count != expected_bytes) {
            return .{ .structural = .unsupported_metadata_layout };
        }
    }

    return .{ .payload = .{
        .codec = codec,
        .compression = @intCast(compression_value.?),
        .host_offset = first_offset,
        .byte_count = byte_count,
        .width = width,
        .height = height,
        .bits_per_sample = bits_per_sample,
        .byte_order = switch (endian) {
            .little => .little,
            .big => .big,
        },
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

fn metadataFailure(code: sensor_validation.ErrorCode, byte_offset: u64) LocateResult {
    return .{ .fail = .{
        .code = code,
        .region = .metadata,
        .byte_offset = byte_offset,
    } };
}

test "locates a big-endian uncompressed Nikon CFA SubIFD" {
    try std.testing.expectEqual(u16, @typeInfo(Codec).@"enum".tag_type);
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(Codec.uncompressed_words));
    try std.testing.expectEqual(@as(u16, 1), @intFromEnum(Codec.nikon_huffman));

    const nef = "MM\x00\x2a\x00\x00\x00\x08" ++
        "\x00\x01" ++
        "\x01\x4a\x00\x04\x00\x00\x00\x01\x00\x00\x00\x20" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00" ++
        "\x00\x07" ++
        "\x01\x00\x00\x04\x00\x00\x00\x01\x00\x00\x00\x02" ++
        "\x01\x01\x00\x04\x00\x00\x00\x01\x00\x00\x00\x02" ++
        "\x01\x02\x00\x03\x00\x00\x00\x01\x00\x0e\x00\x00" ++
        "\x01\x03\x00\x03\x00\x00\x00\x01\x00\x01\x00\x00" ++
        "\x01\x06\x00\x03\x00\x00\x00\x01\x80\x23\x00\x00" ++
        "\x01\x11\x00\x04\x00\x00\x00\x01\x00\x00\x00\x80" ++
        "\x01\x17\x00\x04\x00\x00\x00\x01\x00\x00\x00\x08" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00" ++
        "\x09\xdc\x11\x5a\x0a\x36\x11\x16";

    try std.testing.expectEqual(
        LocateResult{ .payload = .{
            .codec = .uncompressed_words,
            .compression = 1,
            .host_offset = 128,
            .byte_count = 8,
            .width = 2,
            .height = 2,
            .bits_per_sample = 14,
            .byte_order = .big,
        } },
        try locateSensorPayload(std.testing.allocator, nef),
    );
}

test "combines contiguous NEF strips and rejects a gap without condemning the file" {
    const contiguous = "MM\x00\x2a\x00\x00\x00\x08" ++
        "\x00\x01" ++
        "\x01\x4a\x00\x04\x00\x00\x00\x01\x00\x00\x00\x20" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00" ++
        "\x00\x07" ++
        "\x01\x00\x00\x04\x00\x00\x00\x01\x00\x00\x00\x02" ++
        "\x01\x01\x00\x04\x00\x00\x00\x01\x00\x00\x00\x02" ++
        "\x01\x02\x00\x03\x00\x00\x00\x01\x00\x0e\x00\x00" ++
        "\x01\x03\x00\x03\x00\x00\x00\x01\x00\x01\x00\x00" ++
        "\x01\x06\x00\x03\x00\x00\x00\x01\x80\x23\x00\x00" ++
        "\x01\x11\x00\x04\x00\x00\x00\x02\x00\x00\x00\x80" ++
        "\x01\x17\x00\x04\x00\x00\x00\x02\x00\x00\x00\x88" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x90\x00\x00\x00\x94" ++
        "\x00\x00\x00\x04\x00\x00\x00\x04" ++
        "\x09\xdc\x11\x5a\x0a\x36\x11\x16";
    var gapped = contiguous.*;
    gapped[135] = 0x95;

    const located = try locateSensorPayload(std.testing.allocator, contiguous);
    try std.testing.expectEqual(@as(u64, 144), located.payload.host_offset);
    try std.testing.expectEqual(@as(u64, 8), located.payload.byte_count);
    try std.testing.expectEqual(
        LocateResult{ .structural = .unsupported_metadata_layout },
        try locateSensorPayload(std.testing.allocator, &gapped),
    );
}
