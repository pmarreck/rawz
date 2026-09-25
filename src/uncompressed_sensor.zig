//! Validation for uncompressed sensor samples stored in 16-bit words.

const std = @import("std");
const sensor_validation = @import("sensor_validation.zig");

pub const Result = sensor_validation.Result;

pub const Levels = struct {
    black: u16,
    white: u16,
};

pub const Input = struct {
    bytes: []const u8,
    width: u32,
    height: u32,
    bits_per_sample: u8,
    byte_order: std.builtin.Endian,
    levels: ?Levels,
};

/// Validate one CFA sample per 16-bit word. Every supplied byte belongs to one
/// declared sample; padding and packed layouts must use another validator.
/// Successful validation remains structural because each sample's low byte can
/// hold any value, exceeding the fleet's 10% any-legal-byte ceiling for full.
pub fn validate16BitWords(input: Input) Result {
    if (input.width == 0 or input.height == 0) {
        return metadataFailure(.invalid_dimensions);
    }
    if (input.bits_per_sample != 12 and input.bits_per_sample != 14) {
        return metadataFailure(.unsupported_bit_depth);
    }

    const sample_count = std.math.mul(u64, input.width, input.height) catch {
        return metadataFailure(.invalid_dimensions);
    };
    const expected_bytes = std.math.mul(u64, sample_count, 2) catch {
        return metadataFailure(.invalid_dimensions);
    };
    if (input.bytes.len < expected_bytes) {
        return payloadFailure(.truncated, input.bytes.len);
    }
    if (input.bytes.len > expected_bytes) {
        return payloadFailure(.trailing_mismatch, expected_bytes);
    }

    const max_sample = (@as(u16, 1) << @intCast(input.bits_per_sample)) - 1;
    if (input.levels) |levels| {
        if (levels.black > levels.white or levels.white > max_sample) {
            return metadataFailure(.malformed_metadata);
        }
    }

    var byte_offset: usize = 0;
    while (byte_offset < input.bytes.len) : (byte_offset += 2) {
        const sample = std.mem.readInt(
            u16,
            input.bytes[byte_offset..][0..2],
            input.byte_order,
        );
        if (sample > max_sample) {
            return payloadFailure(.sample_overflow, byte_offset);
        }
        if (input.levels) |levels| {
            if (sample < levels.black) {
                return payloadFailure(.sample_below_black_level, byte_offset);
            }
            if (sample > levels.white) {
                return payloadFailure(.sample_above_white_level, byte_offset);
            }
        }
    }

    return if (input.levels == null)
        .{ .structural = .metadata_levels_unavailable }
    else
        .{ .structural = .sample_values_have_no_integrity_signal };
}

fn metadataFailure(code: sensor_validation.ErrorCode) Result {
    return .{ .fail = .{
        .code = code,
        .region = .metadata,
        .byte_offset = 0,
    } };
}

fn payloadFailure(code: sensor_validation.ErrorCode, byte_offset: u64) Result {
    return .{ .fail = .{
        .code = code,
        .region = .payload,
        .byte_offset = byte_offset,
    } };
}

test "valid level-bounded words stay structural because low bytes carry no integrity signal" {
    const bytes = [_]u8{
        0x00, 0x01,
        0x00, 0x08,
        0xff, 0x0e,
        0x34, 0x02,
    };

    try std.testing.expectEqual(
        Result{ .structural = .sample_values_have_no_integrity_signal },
        validate16BitWords(.{
            .bytes = &bytes,
            .width = 2,
            .height = 2,
            .bits_per_sample = 12,
            .byte_order = .little,
            .levels = .{ .black = 256, .white = 3839 },
        }),
    );
}

test "rejects a 12-bit word whose high bits are nonzero at its byte offset" {
    const bytes = [_]u8{ 0x00, 0x01, 0x00, 0x10 };

    try std.testing.expectEqual(
        Result{ .fail = .{
            .code = .sample_overflow,
            .region = .payload,
            .byte_offset = 2,
        } },
        validate16BitWords(.{
            .bytes = &bytes,
            .width = 2,
            .height = 1,
            .bits_per_sample = 12,
            .byte_order = .little,
            .levels = .{ .black = 0, .white = 4095 },
        }),
    );
}

test "distinguishes samples below black and above white metadata levels" {
    const below = [_]u8{ 0xff, 0x00 };
    const above = [_]u8{ 0x00, 0x0f };

    try std.testing.expectEqual(
        Result{ .fail = .{
            .code = .sample_below_black_level,
            .region = .payload,
            .byte_offset = 0,
        } },
        validate16BitWords(.{
            .bytes = &below,
            .width = 1,
            .height = 1,
            .bits_per_sample = 12,
            .byte_order = .little,
            .levels = .{ .black = 256, .white = 3839 },
        }),
    );
    try std.testing.expectEqual(
        Result{ .fail = .{
            .code = .sample_above_white_level,
            .region = .payload,
            .byte_offset = 0,
        } },
        validate16BitWords(.{
            .bytes = &above,
            .width = 1,
            .height = 1,
            .bits_per_sample = 12,
            .byte_order = .little,
            .levels = .{ .black = 256, .white = 3839 },
        }),
    );
}

test "checks headroom but stays structural when level metadata is unavailable" {
    const bytes = [_]u8{ 0x34, 0x02 };

    try std.testing.expectEqual(
        Result{ .structural = .metadata_levels_unavailable },
        validate16BitWords(.{
            .bytes = &bytes,
            .width = 1,
            .height = 1,
            .bits_per_sample = 14,
            .byte_order = .little,
            .levels = null,
        }),
    );
}

test "classifies 12- and 14-bit word byte orders as one supported set" {
    const Case = struct {
        bytes: [2]u8,
        bits_per_sample: u8,
        byte_order: std.builtin.Endian,
    };
    const cases = [_]Case{
        .{ .bytes = .{ 0x34, 0x02 }, .bits_per_sample = 12, .byte_order = .little },
        .{ .bytes = .{ 0x02, 0x34 }, .bits_per_sample = 12, .byte_order = .big },
        .{ .bytes = .{ 0x34, 0x22 }, .bits_per_sample = 14, .byte_order = .little },
        .{ .bytes = .{ 0x22, 0x34 }, .bits_per_sample = 14, .byte_order = .big },
    };

    for (cases) |case| {
        try std.testing.expectEqual(
            Result{ .structural = .sample_values_have_no_integrity_signal },
            validate16BitWords(.{
                .bytes = &case.bytes,
                .width = 1,
                .height = 1,
                .bits_per_sample = case.bits_per_sample,
                .byte_order = case.byte_order,
                .levels = .{
                    .black = 0,
                    .white = (@as(u16, 1) << @intCast(case.bits_per_sample)) - 1,
                },
            }),
        );
    }
}

test "pins truncated and trailing word extents with exact offsets" {
    const bytes = [_]u8{ 0x34, 0x02, 0x78, 0x06, 0x00 };
    const Case = struct {
        bytes: []const u8,
        expected: Result,
    };
    const cases = [_]Case{
        .{
            .bytes = bytes[0..3],
            .expected = .{ .fail = .{
                .code = .truncated,
                .region = .payload,
                .byte_offset = 3,
            } },
        },
        .{
            .bytes = &bytes,
            .expected = .{ .fail = .{
                .code = .trailing_mismatch,
                .region = .payload,
                .byte_offset = 4,
            } },
        },
    };

    for (cases) |case| {
        try std.testing.expectEqual(
            case.expected,
            validate16BitWords(.{
                .bytes = case.bytes,
                .width = 2,
                .height = 1,
                .bits_per_sample = 12,
                .byte_order = .little,
                .levels = .{ .black = 0, .white = 4095 },
            }),
        );
    }
}

test "classifies invalid dimensions, bit depth, and level metadata as one set" {
    const bytes = [_]u8{ 0x34, 0x02 };
    const Case = struct {
        input: Input,
        expected_code: sensor_validation.ErrorCode,
    };
    const cases = [_]Case{
        .{
            .input = .{
                .bytes = &bytes,
                .width = 0,
                .height = 1,
                .bits_per_sample = 12,
                .byte_order = .little,
                .levels = null,
            },
            .expected_code = .invalid_dimensions,
        },
        .{
            .input = .{
                .bytes = &bytes,
                .width = 1,
                .height = 1,
                .bits_per_sample = 16,
                .byte_order = .little,
                .levels = null,
            },
            .expected_code = .unsupported_bit_depth,
        },
        .{
            .input = .{
                .bytes = &bytes,
                .width = 1,
                .height = 1,
                .bits_per_sample = 12,
                .byte_order = .little,
                .levels = .{ .black = 512, .white = 511 },
            },
            .expected_code = .malformed_metadata,
        },
    };

    for (cases) |case| {
        const result = validate16BitWords(case.input);
        try std.testing.expectEqual(case.expected_code, result.fail.code);
        try std.testing.expectEqual(sensor_validation.Region.metadata, result.fail.region);
        try std.testing.expectEqual(@as(u64, 0), result.fail.byte_offset);
    }
}
