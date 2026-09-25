//! Stable result vocabulary shared by camera sensor-payload validators.

const std = @import("std");

/// Append-only codes. Consumers may map these directly without parsing text.
pub const ErrorCode = enum(u16) {
    invalid_dimensions = 0,
    unsupported_bit_depth = 1,
    invalid_huffman_table = 2,
    invalid_huffman_code = 3,
    truncated = 4,
    sample_overflow = 5,
    work_limit_exceeded = 6,
    trailing_mismatch = 7,
    metadata_out_of_bounds = 8,
    malformed_metadata = 9,
    sample_below_black_level = 10,
    sample_above_white_level = 11,
};

/// The byte range in which a failure offset is measured.
pub const Region = enum {
    payload,
    metadata,
};

pub const Failure = struct {
    code: ErrorCode,
    region: Region,
    byte_offset: u64,
};

/// Named reasons a syntactically valid input cannot earn full depth.
pub const ReachReason = enum(u16) {
    requires_tiff_decompression = 0,
    encoded_payload_required = 1,
    sample_values_have_no_integrity_signal = 2,
    huffman_table_unavailable = 3,
    unsupported_compression = 4,
    unsupported_metadata_layout = 5,
    metadata_levels_unavailable = 6,
};

/// A direct mapping surface for Validate: full, structural, or fail.
pub const Result = union(enum) {
    full: void,
    structural: ReachReason,
    fail: Failure,
};

test "sensor result codes use stable explicit 16-bit values" {
    try std.testing.expectEqual(u16, @typeInfo(ErrorCode).@"enum".tag_type);
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(ErrorCode.invalid_dimensions));
    try std.testing.expectEqual(@as(u16, 7), @intFromEnum(ErrorCode.trailing_mismatch));
    try std.testing.expectEqual(@as(u16, 9), @intFromEnum(ErrorCode.malformed_metadata));
    try std.testing.expectEqual(@as(u16, 10), @intFromEnum(ErrorCode.sample_below_black_level));
    try std.testing.expectEqual(@as(u16, 11), @intFromEnum(ErrorCode.sample_above_white_level));
    try std.testing.expectEqual(u16, @typeInfo(ReachReason).@"enum".tag_type);
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(ReachReason.requires_tiff_decompression));
    try std.testing.expectEqual(@as(u16, 4), @intFromEnum(ReachReason.unsupported_compression));
    try std.testing.expectEqual(@as(u16, 5), @intFromEnum(ReachReason.unsupported_metadata_layout));
    try std.testing.expectEqual(@as(u16, 6), @intFromEnum(ReachReason.metadata_levels_unavailable));
}
