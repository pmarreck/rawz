//! Canon CR2 sensor-payload discovery.

const std = @import("std");
const tiffz = @import("tiffz");
const sensor_validation = @import("sensor_validation.zig");

pub const Codec = enum(u16) {
    lossless_jpeg = 0,
};

pub const Payload = struct {
    codec: Codec,
    compression: u16,
    host_offset: u64,
    byte_count: u64,
};

pub const LocateResult = union(enum) {
    payload: Payload,
    structural: sensor_validation.ReachReason,
    fail: sensor_validation.Failure,
};

/// Locate the sensor stream named by the proprietary CR2 header's raw-IFD
/// pointer. Returned offsets are relative to the supplied complete CR2 file.
pub fn locateSensorPayload(
    allocator: std.mem.Allocator,
    bytes: []const u8,
) error{OutOfMemory}!LocateResult {
    if (bytes.len < 16) return metadataFailure(.malformed_metadata, bytes.len);
    if (!std.mem.eql(u8, bytes[8..12], "CR\x02\x00")) {
        return metadataFailure(.malformed_metadata, 8);
    }

    var handle = tiffz.source.BufferHandle.init(bytes);
    const source = tiffz.Source.fromBuffer(&handle);
    const header = tiffz.header.parse(source) catch {
        return metadataFailure(.malformed_metadata, 0);
    };
    if (header.bigtiff) return .{ .structural = .unsupported_metadata_layout };

    const raw_ifd_offset = @as(u64, tiffz.header.readU32(bytes[12..16], header.endian));
    if (raw_ifd_offset >= bytes.len) {
        return metadataFailure(.metadata_out_of_bounds, 12);
    }

    var dir = tiffz.ifd.parse(
        allocator,
        source,
        header.endian,
        raw_ifd_offset,
        .{},
        .classic,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return metadataFailure(.malformed_metadata, raw_ifd_offset),
    };
    defer dir.deinit();

    const compression = readSingleValue(&dir, tiffz.tags.compression, header.endian, source) catch {
        return metadataFailure(.malformed_metadata, raw_ifd_offset);
    } orelse return metadataFailure(.malformed_metadata, raw_ifd_offset);
    if (compression != tiffz.tags.compression_jpeg_old and
        compression != tiffz.tags.compression_jpeg)
    {
        return .{ .structural = .unsupported_compression };
    }

    const strip_offsets_entry = dir.get(tiffz.tags.strip_offsets) orelse
        return metadataFailure(.malformed_metadata, raw_ifd_offset);
    const strip_byte_counts_entry = dir.get(tiffz.tags.strip_byte_counts) orelse
        return metadataFailure(.malformed_metadata, raw_ifd_offset);
    if (strip_offsets_entry.count != strip_byte_counts_entry.count or
        strip_offsets_entry.count == 0)
    {
        return metadataFailure(.malformed_metadata, raw_ifd_offset);
    }
    if (strip_offsets_entry.count != 1) {
        return .{ .structural = .unsupported_metadata_layout };
    }

    const strip_offset = readSingleValue(&dir, tiffz.tags.strip_offsets, header.endian, source) catch {
        return metadataFailure(.malformed_metadata, raw_ifd_offset);
    } orelse return metadataFailure(.malformed_metadata, raw_ifd_offset);
    const strip_byte_count = readSingleValue(&dir, tiffz.tags.strip_byte_counts, header.endian, source) catch {
        return metadataFailure(.malformed_metadata, raw_ifd_offset);
    } orelse return metadataFailure(.malformed_metadata, raw_ifd_offset);
    if (strip_byte_count == 0) return metadataFailure(.malformed_metadata, raw_ifd_offset);
    if (strip_offset > bytes.len) {
        return metadataFailure(
            .metadata_out_of_bounds,
            classicEntryValueOffset(&dir, raw_ifd_offset, tiffz.tags.strip_offsets),
        );
    }
    const strip_end = std.math.add(u64, strip_offset, strip_byte_count) catch {
        return metadataFailure(
            .metadata_out_of_bounds,
            classicEntryValueOffset(&dir, raw_ifd_offset, tiffz.tags.strip_byte_counts),
        );
    };
    if (strip_end > bytes.len) {
        return metadataFailure(
            .metadata_out_of_bounds,
            classicEntryValueOffset(&dir, raw_ifd_offset, tiffz.tags.strip_byte_counts),
        );
    }

    return .{ .payload = .{
        .codec = .lossless_jpeg,
        .compression = @intCast(compression),
        .host_offset = strip_offset,
        .byte_count = strip_byte_count,
    } };
}

fn readSingleValue(
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

fn classicEntryValueOffset(dir: *const tiffz.ifd.Ifd, ifd_offset: u64, tag: u16) u64 {
    for (dir.entries, 0..) |entry, index| {
        if (entry.tag != tag) continue;
        const entry_offset = std.math.add(u64, ifd_offset, 2 + @as(u64, index) * 12) catch
            return ifd_offset;
        return std.math.add(u64, entry_offset, 8) catch ifd_offset;
    }
    return ifd_offset;
}

test "locates the CR2 raw IFD lossless-JPEG strip" {
    try std.testing.expectEqual(u16, @typeInfo(Codec).@"enum".tag_type);
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(Codec.lossless_jpeg));

    const cr2 = "II\x2a\x00\x10\x00\x00\x00CR\x02\x00\x20\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" ++
        "\x03\x00" ++
        "\x03\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00" ++
        "\x11\x01\x04\x00\x01\x00\x00\x00\x50\x00\x00\x00" ++
        "\x17\x01\x04\x00\x01\x00\x00\x00\x04\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00" ++
        "\xff\xd8\xff\xd9";

    const result = try locateSensorPayload(std.testing.allocator, cr2);
    try std.testing.expectEqual(
        LocateResult{ .payload = .{
            .codec = .lossless_jpeg,
            .compression = 6,
            .host_offset = 80,
            .byte_count = 4,
        } },
        result,
    );
}

test "reports a valid multi-strip CR2 layout as structurally unsupported" {
    const cr2 = "II\x2a\x00\x10\x00\x00\x00CR\x02\x00\x20\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" ++
        "\x03\x00" ++
        "\x03\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00" ++
        "\x11\x01\x04\x00\x02\x00\x00\x00\x50\x00\x00\x00" ++
        "\x17\x01\x04\x00\x02\x00\x00\x00\x58\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00" ++
        "\x60\x00\x00\x00\x64\x00\x00\x00" ++
        "\x04\x00\x00\x00\x04\x00\x00\x00";

    try std.testing.expectEqual(
        LocateResult{ .structural = .unsupported_metadata_layout },
        try locateSensorPayload(std.testing.allocator, cr2),
    );
}

test "reports the exact CR2 strip-offset field when its extent exceeds the file" {
    const cr2 = "II\x2a\x00\x10\x00\x00\x00CR\x02\x00\x20\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" ++
        "\x03\x00" ++
        "\x03\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00" ++
        "\x11\x01\x04\x00\x01\x00\x00\x00\x00\x01\x00\x00" ++
        "\x17\x01\x04\x00\x01\x00\x00\x00\x04\x00\x00\x00" ++
        "\x00\x00\x00\x00";

    try std.testing.expectEqual(
        LocateResult{ .fail = .{
            .code = .metadata_out_of_bounds,
            .region = .metadata,
            .byte_offset = 54,
        } },
        try locateSensorPayload(std.testing.allocator, cr2),
    );
}
