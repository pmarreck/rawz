//! Nikon compression 34713 entropy-stream validation.
//!
//! ALGORITHM PROVENANCE: The lossless Huffman codebooks and predictor math were
//! independently implemented in Zig from Dave Coffin's public-domain dcraw
//! description. LibRaw and rawspeed source were not consulted; rawspeed was
//! executed only as a black-box differential oracle.
//! Reference: https://www.dechifro.org/dcraw/

const std = @import("std");
const BitReader = @import("bit_reader.zig").BitReader;
const sensor_validation = @import("sensor_validation.zig");

const Table = struct {
    counts: [16]u8,
    symbols: []const u8,
};

const LookupEntry = struct {
    bit_count: u4 = 0,
    symbol: u8 = 0,
};

const lossless_12_counts = [_]u8{ 0, 1, 4, 2, 3, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
const lossless_12_symbols = [_]u8{ 5, 4, 6, 3, 7, 2, 8, 1, 9, 0, 10, 11, 12 };
const lossless_14_counts = [_]u8{ 0, 1, 4, 2, 2, 3, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0 };
const lossless_14_symbols = [_]u8{ 7, 6, 8, 5, 9, 4, 10, 3, 11, 12, 2, 0, 1, 13, 14 };

pub const Input = struct {
    payload: []const u8,
    width: u32,
    height: u32,
    bits_per_sample: u8,
    linearization_table: []const u8,
    metadata_byte_order: std.builtin.Endian,
    limits: Limits = .default,
};

pub const Limits = struct {
    max_samples: u64 = 1 << 28,

    pub const default: Limits = .{};
};

/// Validate Nikon's version-0x46 lossless Huffman stream through the declared
/// final sample. Other table versions remain structural.
pub fn validate(input: Input) sensor_validation.Result {
    if (input.width == 0 or input.height == 0) return metadataFailure(.invalid_dimensions, 0);
    if (input.bits_per_sample != 12 and input.bits_per_sample != 14) {
        return metadataFailure(.unsupported_bit_depth, 0);
    }
    if (input.linearization_table.len < 12) {
        return metadataFailure(.truncated, input.linearization_table.len);
    }
    if (input.linearization_table[0] != 0x46) {
        return .{ .structural = .unsupported_metadata_layout };
    }

    var predictors: [2][2]i32 = undefined;
    for (0..2) |row| {
        for (0..2) |column| {
            const offset = 2 + (row * 2 + column) * 2;
            predictors[row][column] = std.mem.readInt(
                u16,
                input.linearization_table[offset..][0..2],
                input.metadata_byte_order,
            );
        }
    }

    const sample_count = std.math.mul(u64, input.width, input.height) catch
        return metadataFailure(.invalid_dimensions, 0);
    if (sample_count > input.limits.max_samples) {
        return metadataFailure(.work_limit_exceeded, 0);
    }
    const table: Table = if (input.bits_per_sample == 12)
        .{ .counts = lossless_12_counts, .symbols = &lossless_12_symbols }
    else
        .{ .counts = lossless_14_counts, .symbols = &lossless_14_symbols };
    const maximum: i32 = @as(i32, 1) << @intCast(input.bits_per_sample);
    const lookup = buildLookup(table);
    var horizontal = [_]i32{ 0, 0 };
    var reader = BitReader.init(input.payload);

    var sample_index: u64 = 0;
    while (sample_index < sample_count) : (sample_index += 1) {
        const row: u32 = @intCast(sample_index / input.width);
        const column: u32 = @intCast(sample_index % input.width);
        const symbol = decodeSymbol(&reader, &lookup) orelse
            return payloadFailure(.truncated, input.payload.len);
        const difference = readDifference(&reader, symbol) orelse
            return payloadFailure(.truncated, input.payload.len);
        const parity: usize = @intCast(column & 1);
        if (column < 2) {
            const row_parity: usize = @intCast(row & 1);
            predictors[row_parity][parity] += difference;
            horizontal[parity] = predictors[row_parity][parity];
        } else {
            horizontal[parity] += difference;
        }
        if (horizontal[parity] < 0 or horizontal[parity] >= maximum) {
            return payloadFailure(.sample_overflow, reader.bit_position / 8);
        }
    }

    const consumed_bytes = std.math.divCeil(usize, reader.bit_position, 8) catch unreachable;
    if (consumed_bytes != input.payload.len) {
        return payloadFailure(.trailing_mismatch, consumed_bytes);
    }
    return .{ .full = {} };
}

fn buildLookup(table: Table) [256]LookupEntry {
    var lookup = [_]LookupEntry{.{}} ** 256;
    var first_code: usize = 0;
    var symbol_index: usize = 0;
    for (table.counts, 1..) |count, bit_length| {
        const end_code = first_code + count;
        if (count != 0) {
            std.debug.assert(bit_length <= 8);
            const suffix_bits = 8 - bit_length;
            for (first_code..end_code) |code| {
                const start = code << @intCast(suffix_bits);
                const end = start + (@as(usize, 1) << @intCast(suffix_bits));
                for (start..end) |index| {
                    lookup[index] = .{
                        .bit_count = @intCast(bit_length),
                        .symbol = table.symbols[symbol_index + code - first_code],
                    };
                }
            }
        }
        symbol_index += count;
        first_code = end_code << 1;
    }
    return lookup;
}

fn decodeSymbol(reader: *BitReader, lookup: *const [256]LookupEntry) ?u8 {
    const prefix = reader.peekBitsPadded(8) orelse return null;
    const entry = lookup[prefix];
    if (entry.bit_count == 0 or !reader.skipBits(entry.bit_count)) return null;
    return entry.symbol;
}

fn readDifference(reader: *BitReader, symbol: u8) ?i32 {
    const bit_count: u5 = @intCast(symbol & 0x0f);
    const shift: u4 = @intCast(symbol >> 4);
    if (bit_count == 0) return 0;
    if (shift > bit_count) return null;
    const encoded = reader.readBits(@intCast(bit_count - shift)) orelse return null;
    var difference: i32 = @intCast(((@as(u64, encoded) << 1) + 1) << shift >> 1);
    if ((difference & (@as(i32, 1) << @intCast(bit_count - 1))) == 0) {
        difference -= (@as(i32, 1) << @intCast(bit_count)) - @intFromBool(shift == 0);
    }
    return difference;
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

test "accepts an exact 12-bit lossless stream with zero differences" {
    const metadata = [_]u8{
        0x46, 0x30,
        0x02, 0x00,
        0x02, 0x00,
        0x02, 0x00,
        0x02, 0x00,
        0x00, 0x00,
    };
    const payload = [_]u8{ 0xf7, 0xbd, 0xe0 };

    const result = validate(.{
        .payload = &payload,
        .width = 2,
        .height = 2,
        .bits_per_sample = 12,
        .linearization_table = &metadata,
        .metadata_byte_order = .little,
    });
    try std.testing.expectEqual(sensor_validation.Result{ .full = {} }, result);
}

test "rejects dimensions above the explicit sample-work ceiling before reading payload" {
    const metadata = [_]u8{
        0x46, 0x30,
        0x02, 0x00,
        0x02, 0x00,
        0x02, 0x00,
        0x02, 0x00,
        0x00, 0x00,
    };

    try std.testing.expectEqual(
        sensor_validation.Result{ .fail = .{
            .code = .work_limit_exceeded,
            .region = .metadata,
            .byte_offset = 0,
        } },
        validate(.{
            .payload = &.{},
            .width = 1024,
            .height = 1024,
            .bits_per_sample = 12,
            .linearization_table = &metadata,
            .metadata_byte_order = .little,
            .limits = .{ .max_samples = 1024 },
        }),
    );
}

test "pins truncated and trailing streams to exact payload offsets" {
    const metadata = [_]u8{
        0x46, 0x30,
        0x02, 0x00,
        0x02, 0x00,
        0x02, 0x00,
        0x02, 0x00,
        0x00, 0x00,
    };
    const bytes = [_]u8{ 0xf7, 0xbd, 0xe0, 0x00 };
    const cases = [_]struct { []const u8, sensor_validation.Result }{
        .{ bytes[0..2], .{ .fail = .{
            .code = .truncated,
            .region = .payload,
            .byte_offset = 2,
        } } },
        .{ &bytes, .{ .fail = .{
            .code = .trailing_mismatch,
            .region = .payload,
            .byte_offset = 3,
        } } },
    };

    for (cases) |case| {
        try std.testing.expectEqual(case[1], validate(.{
            .payload = case[0],
            .width = 2,
            .height = 2,
            .bits_per_sample = 12,
            .linearization_table = &metadata,
            .metadata_byte_order = .little,
        }));
    }
}

test "rejects positive and negative predictor escapes as one set" {
    const Case = struct {
        initial: u16,
        payload: u8,
    };
    const cases = [_]Case{
        .{ .initial = 4095, .payload = 0xe4 },
        .{ .initial = 0, .payload = 0xe0 },
    };

    for (cases) |case| {
        var metadata = [_]u8{
            0x46, 0x30,
            0x00, 0x00,
            0x00, 0x00,
            0x00, 0x00,
            0x00, 0x00,
            0x00, 0x00,
        };
        std.mem.writeInt(u16, metadata[2..4], case.initial, .big);
        try std.testing.expectEqual(
            sensor_validation.Result{ .fail = .{
                .code = .sample_overflow,
                .region = .payload,
                .byte_offset = 0,
            } },
            validate(.{
                .payload = (&case.payload)[0..1],
                .width = 1,
                .height = 1,
                .bits_per_sample = 12,
                .linearization_table = &metadata,
                .metadata_byte_order = .big,
            }),
        );
    }
}

test "accepts the 14-bit lossless table and parent big-endian predictors" {
    const metadata = [_]u8{
        0x46, 0x30,
        0x02, 0x00,
        0x02, 0x00,
        0x02, 0x00,
        0x02, 0x00,
        0x00, 0x00,
    };

    try std.testing.expectEqual(
        sensor_validation.Result{ .full = {} },
        validate(.{
            .payload = &.{0xf8},
            .width = 1,
            .height = 1,
            .bits_per_sample = 14,
            .linearization_table = &metadata,
            .metadata_byte_order = .big,
        }),
    );
}

test "classifies unsupported metadata and malformed input before entropy work" {
    const short_metadata = [_]u8{ 0x46, 0x30 };
    const other_version = [_]u8{0} ** 12;
    const cases = [_]struct { Input, sensor_validation.Result }{
        .{ .{
            .payload = &.{},
            .width = 1,
            .height = 1,
            .bits_per_sample = 12,
            .linearization_table = &short_metadata,
            .metadata_byte_order = .big,
        }, .{ .fail = .{
            .code = .truncated,
            .region = .metadata,
            .byte_offset = 2,
        } } },
        .{ .{
            .payload = &.{},
            .width = 1,
            .height = 1,
            .bits_per_sample = 12,
            .linearization_table = &other_version,
            .metadata_byte_order = .big,
        }, .{ .structural = .unsupported_metadata_layout } },
    };

    for (cases) |case| try std.testing.expectEqual(case[1], validate(case[0]));
}
