//! Pentax PEF entropy validation migrated from Mecha Validate.
//!
//! Supports packed 12-bit sensor samples and Pentax's private lossless Huffman
//! path (TIFF compression 65535). Standard TIFF compression, including PackBits
//! 32773, must be removed by tiffz before bytes reach this module. All inputs
//! are borrowed memory; no I/O or allocation occurs here.
//!
//! ALGORITHM PROVENANCE: The Huffman decompression algorithm was independently
//! implemented in Zig from the mathematical description in Dave Coffin's
//! `pentax_load_raw()`. dcraw's non-Foveon code permits all uses without a
//! license requirement. This migration preserves the existing Zig lineage and
//! does not consult LibRaw or rawspeed source.
//! Reference: https://www.dechifro.org/dcraw/

const std = @import("std");
const BitReader = @import("bit_reader.zig").BitReader;

const huffman_lookup_bits: u4 = 12;
const huffman_lookup_size = 1 << huffman_lookup_bits;
const maker_note_table_start: usize = 14;
const dependency_adjustment: u16 = 12;
const dependency_mask: u16 = 15;

const HuffmanEntry = struct {
    code_bits: u8 = 0,
    difference_bits: u8 = 0,
};

pub const PefDecodeError = error{
    Truncated,
    PixelOverflow,
    InvalidHuffmanTable,
    InvalidHuffmanCode,
    DimensionsTooLarge,
    UnsupportedBitDepth,
    WorkLimitExceeded,
};

pub const PefDecodeLimits = struct {
    /// Fixed work ceiling for entropy validation; callers may choose less.
    max_pixels: u64 = 1 << 28,

    pub const default: PefDecodeLimits = .{};
};

/// Check that a packed 12-bit strip contains every declared pixel.
/// Every complete 12-bit pattern is valid, so this path detects truncation.
pub fn validatePefPacked12(
    strip_data: []const u8,
    width: u32,
    height: u32,
) ?PefDecodeError {
    if (width == 0 or height == 0) return PefDecodeError.DimensionsTooLarge;

    const row_bits = std.math.mul(u64, width, 12) catch
        return PefDecodeError.DimensionsTooLarge;
    const rounded_row_bits = std.math.add(u64, row_bits, 7) catch
        return PefDecodeError.DimensionsTooLarge;
    const bytes_per_row = rounded_row_bits / 8;
    const expected_bytes = std.math.mul(u64, bytes_per_row, height) catch
        return PefDecodeError.DimensionsTooLarge;
    if (expected_bytes > std.math.maxInt(usize)) return PefDecodeError.DimensionsTooLarge;
    if (strip_data.len < expected_bytes) return PefDecodeError.Truncated;
    return null;
}

/// Decode a PEF lossless-Huffman stream far enough to reject malformed tables,
/// truncation, and predictors that escape the declared sample bit depth.
/// Dimension and bit-depth errors take precedence over table and stream errors.
pub fn validatePefHuffman(
    strip_data: []const u8,
    width: u32,
    height: u32,
    bits_per_sample: u16,
    huff_table_data: []const u8,
) ?PefDecodeError {
    return validatePefHuffmanWithLimits(
        strip_data,
        width,
        height,
        bits_per_sample,
        huff_table_data,
        .default,
    );
}

/// Validate PEF Huffman data under an explicit pixel-work ceiling.
pub fn validatePefHuffmanWithLimits(
    strip_data: []const u8,
    width: u32,
    height: u32,
    bits_per_sample: u16,
    huff_table_data: []const u8,
    limits: PefDecodeLimits,
) ?PefDecodeError {
    if (width == 0 or height == 0) return PefDecodeError.DimensionsTooLarge;
    if (bits_per_sample == 0 or bits_per_sample > 16) return PefDecodeError.UnsupportedBitDepth;
    if (huff_table_data.len < 2) return PefDecodeError.InvalidHuffmanTable;

    const total_pixels = @as(u64, width) * @as(u64, height);
    if (total_pixels > limits.max_pixels) return PefDecodeError.WorkLimitExceeded;

    const dep_raw = std.mem.readInt(u16, huff_table_data[0..2], .little);
    const dependency_count: u8 = @intCast((dep_raw +% dependency_adjustment) & dependency_mask);
    if (dependency_count == 0) return PefDecodeError.InvalidHuffmanTable;
    const code_bytes = @as(usize, dependency_count) * 2;
    const table_end = maker_note_table_start + code_bytes + dependency_count;
    if (huff_table_data.len < table_end) return PefDecodeError.InvalidHuffmanTable;

    var huffman: [huffman_lookup_size]HuffmanEntry = .{HuffmanEntry{}} ** huffman_lookup_size;

    var difference_bits: u8 = 0;
    while (difference_bits < dependency_count) : (difference_bits += 1) {
        const code_offset = maker_note_table_start + @as(usize, difference_bits) * 2;
        const code_value = std.mem.readInt(u16, huff_table_data[code_offset..][0..2], .little);
        const bit_length = huff_table_data[maker_note_table_start + code_bytes + difference_bits];
        if (bit_length == 0 or bit_length > huffman_lookup_bits or code_value >= huffman_lookup_size) {
            return PefDecodeError.InvalidHuffmanTable;
        }

        const range: u16 = @as(u16, huffman_lookup_size) >> @intCast(bit_length);
        if (code_value % range != 0) return PefDecodeError.InvalidHuffmanTable;
        const end_exclusive = std.math.add(u32, code_value, range) catch
            return PefDecodeError.InvalidHuffmanTable;
        if (end_exclusive > huffman_lookup_size) return PefDecodeError.InvalidHuffmanTable;

        var code: u32 = code_value;
        while (code < end_exclusive) : (code += 1) {
            const index: usize = @intCast(code);
            if (huffman[index].code_bits != 0) return PefDecodeError.InvalidHuffmanTable;
            huffman[index] = .{
                .code_bits = bit_length,
                .difference_bits = difference_bits,
            };
        }
    }

    const strip_bytes = std.math.cast(u64, strip_data.len) orelse
        return PefDecodeError.DimensionsTooLarge;
    const available_bits = std.math.mul(u64, strip_bytes, 8) catch
        return PefDecodeError.DimensionsTooLarge;
    if (total_pixels > available_bits) return PefDecodeError.Truncated;

    var reader = BitReader.init(strip_data);
    var vertical_predictor: [2][2]u16 = .{ .{ 0, 0 }, .{ 0, 0 } };
    var horizontal_predictor: [2]u16 = .{ 0, 0 };

    var row: u32 = 0;
    while (row < height) : (row += 1) {
        var column: u32 = 0;
        while (column < width) : (column += 1) {
            const difference = ljpegDiff(&reader, &huffman) catch |err| return err;

            if (column < 2) {
                vertical_predictor[row & 1][column] +%= @bitCast(@as(i16, @intCast(difference)));
                horizontal_predictor[column] = vertical_predictor[row & 1][column];
            } else {
                horizontal_predictor[column & 1] +%= @bitCast(@as(i16, @intCast(difference)));
            }

            const pixel = horizontal_predictor[column & 1];
            if (bits_per_sample < 16) {
                const shift: u4 = @intCast(bits_per_sample);
                if (pixel >> shift != 0) return PefDecodeError.PixelOverflow;
            }
        }
    }

    return null;
}

/// Decode one lossless-JPEG difference using the pre-expanded lookup table.
fn ljpegDiff(reader: *BitReader, huffman: []const HuffmanEntry) PefDecodeError!i32 {
    const code = reader.peekBitsPadded(huffman_lookup_bits) orelse return PefDecodeError.Truncated;
    const entry = huffman[code];
    if (entry.code_bits == 0) return PefDecodeError.InvalidHuffmanCode;
    if (!reader.skipBits(entry.code_bits)) return PefDecodeError.Truncated;
    const length: u5 = @intCast(entry.difference_bits);

    if (length == 0) return 0;
    const raw_difference = reader.readBits(length) orelse return PefDecodeError.Truncated;
    if ((raw_difference & (@as(u32, 1) << @intCast(length - 1))) == 0) {
        return @as(i32, @intCast(raw_difference)) -
            @as(i32, @intCast((@as(u32, 1) << @intCast(length)) - 1));
    }
    return @intCast(raw_difference);
}

test "packed 12-bit validation accepts complete data and rejects truncation" {
    const complete = [_]u8{0} ** 12;
    const truncated = [_]u8{0} ** 8;

    try std.testing.expectEqual(null, validatePefPacked12(&complete, 4, 2));
    try std.testing.expectEqual(PefDecodeError.Truncated, validatePefPacked12(&truncated, 4, 2).?);
}

test "packed 12-bit validation accounts for per-row byte padding" {
    try std.testing.expectEqual(
        PefDecodeError.Truncated,
        validatePefPacked12(&.{ 0, 0, 0 }, 1, 2).?,
    );
    try std.testing.expectEqual(null, validatePefPacked12(&.{ 0, 0, 0, 0 }, 1, 2));
}

test "packed 12-bit validation permits caller-owned trailing bytes" {
    try std.testing.expectEqual(null, validatePefPacked12(&.{ 0, 0, 0, 0 }, 2, 1));
}

test "packed 12-bit dimension arithmetic cannot overflow" {
    try std.testing.expectEqual(PefDecodeError.DimensionsTooLarge, validatePefPacked12(&.{}, 0, 10).?);
    try std.testing.expectEqual(PefDecodeError.DimensionsTooLarge, validatePefPacked12(&.{}, 10, 0).?);
    try std.testing.expectEqual(
        PefDecodeError.DimensionsTooLarge,
        validatePefPacked12(&.{}, std.math.maxInt(u32), std.math.maxInt(u32)).?,
    );
}

test "Huffman validation rejects malformed controls without decoding" {
    try std.testing.expectEqual(
        PefDecodeError.DimensionsTooLarge,
        validatePefHuffman(&.{}, 0, 1, 12, &.{}).?,
    );
    try std.testing.expectEqual(
        PefDecodeError.UnsupportedBitDepth,
        validatePefHuffman(&.{}, 1, 1, 0, &.{}).?,
    );
    try std.testing.expectEqual(
        PefDecodeError.UnsupportedBitDepth,
        validatePefHuffman(&.{}, 1, 1, 17, &.{}).?,
    );
    try std.testing.expectEqual(
        PefDecodeError.InvalidHuffmanTable,
        validatePefHuffman(&.{}, 1, 1, 12, &.{}).?,
    );

    var zero_length_table = [_]u8{0} ** 17;
    zero_length_table[0] = 5;
    try std.testing.expectEqual(
        PefDecodeError.InvalidHuffmanTable,
        validatePefHuffman(&.{}, 1, 1, 12, &zero_length_table).?,
    );

    var overlapping_table = [_]u8{0} ** 20;
    overlapping_table[0] = 6;
    overlapping_table[18] = 1;
    overlapping_table[19] = 1;
    try std.testing.expectEqual(
        PefDecodeError.InvalidHuffmanTable,
        validatePefHuffman(&.{ 0, 0 }, 1, 1, 12, &overlapping_table).?,
    );

    var misaligned_table = [_]u8{0} ** 17;
    misaligned_table[0] = 5;
    misaligned_table[14] = 1;
    misaligned_table[16] = 1;
    try std.testing.expectEqual(
        PefDecodeError.InvalidHuffmanTable,
        validatePefHuffman(&.{0}, 1, 1, 12, &misaligned_table).?,
    );

    var truncated_table = [_]u8{0} ** 16;
    truncated_table[0] = 5;
    try std.testing.expectEqual(
        PefDecodeError.InvalidHuffmanTable,
        validatePefHuffman(&.{0}, 1, 1, 12, &truncated_table).?,
    );

    var long_code_table = [_]u8{0} ** 17;
    long_code_table[0] = 5;
    long_code_table[16] = 13;
    try std.testing.expectEqual(
        PefDecodeError.InvalidHuffmanTable,
        validatePefHuffman(&.{0}, 1, 1, 12, &long_code_table).?,
    );

    var out_of_range_table = [_]u8{0} ** 17;
    out_of_range_table[0] = 5;
    out_of_range_table[15] = 0x10;
    out_of_range_table[16] = 1;
    try std.testing.expectEqual(
        PefDecodeError.InvalidHuffmanTable,
        validatePefHuffman(&.{0}, 1, 1, 12, &out_of_range_table).?,
    );
}

test "valid Huffman metadata with no strip bits is truncated" {
    var table = [_]u8{0} ** 17;
    table[0] = 5;
    table[16] = 1;
    try std.testing.expectEqual(
        PefDecodeError.Truncated,
        validatePefHuffman(&.{}, 1, 1, 12, &table).?,
    );
}

test "Huffman table decodes assigned zero differences and rejects gaps" {
    var table = [_]u8{0} ** 17;
    table[0] = 5;
    table[16] = 1;

    try std.testing.expectEqual(null, validatePefHuffman(&.{0}, 1, 1, 12, &table));
    try std.testing.expectEqual(
        PefDecodeError.InvalidHuffmanCode,
        validatePefHuffman(&.{ 0x80, 0 }, 1, 1, 12, &table).?,
    );
}

test "Huffman validation exercises predictors and signed differences" {
    var table = [_]u8{0} ** 20;
    table[0] = 6;
    table[17] = 8;
    table[18] = 1;
    table[19] = 1;

    try std.testing.expectEqual(
        null,
        validatePefHuffman(&.{ 0xff, 0xfa, 0x00 }, 3, 3, 12, &table),
    );
    try std.testing.expectEqual(
        PefDecodeError.PixelOverflow,
        validatePefHuffman(&.{0xfc}, 3, 1, 1, &table).?,
    );
}

test "Huffman validation rejects missing payload and incomplete final codes" {
    var payload_table = [_]u8{0} ** 20;
    payload_table[0] = 6;
    payload_table[17] = 8;
    payload_table[18] = 1;
    payload_table[19] = 1;
    try std.testing.expectEqual(
        PefDecodeError.Truncated,
        validatePefHuffman(&.{0x01}, 8, 1, 12, &payload_table).?,
    );

    var code_table = payload_table;
    code_table[19] = 2;
    try std.testing.expectEqual(
        PefDecodeError.Truncated,
        validatePefHuffman(&.{0x01}, 8, 1, 12, &code_table).?,
    );
}

test "Huffman validation enforces caller-selected work limits" {
    var table = [_]u8{0} ** 17;
    table[0] = 5;
    table[16] = 1;

    try std.testing.expectEqual(
        null,
        validatePefHuffmanWithLimits(&.{0}, 1, 1, 12, &table, .{ .max_pixels = 1 }),
    );
    try std.testing.expectEqual(
        PefDecodeError.WorkLimitExceeded,
        validatePefHuffmanWithLimits(&.{0}, 2, 1, 12, &table, .{ .max_pixels = 1 }).?,
    );
}
