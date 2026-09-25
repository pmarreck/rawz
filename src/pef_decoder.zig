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
const sensor_validation = @import("sensor_validation.zig");

pub const validation = sensor_validation;
pub const compression_packbits: u16 = 32773;
pub const compression_pentax_huffman: u16 = 65535;

pub const PayloadBytes = union(enum) {
    /// Bytes before a private PEF entropy decoder has run.
    encoded: []const u8,
    /// Bytes after tiffz has validated and removed a standard TIFF codec.
    tiff_decoded: []const u8,
};

pub const PayloadInput = struct {
    compression: u16,
    payload: PayloadBytes,
    width: u32,
    height: u32,
    bits_per_sample: u16,
    huffman_table: ?[]const u8 = null,
    huffman_table_byte_order: std.builtin.Endian = .little,
    limits: PefDecodeLimits = .default,
};

pub const HuffmanTableView = struct {
    bytes: []const u8,
    byte_order: std.builtin.Endian,
    byte_offset: u64,
};

pub const HuffmanTableLookup = union(enum) {
    found: HuffmanTableView,
    structural: sensor_validation.ReachReason,
    fail: sensor_validation.Failure,
};

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

pub const GateMetrics = struct {
    valid_total: usize,
    false_positives: usize,
    known_bad_total: usize,
    false_negatives: usize,
    sniper_total: usize,
    sniper_detected: usize,
    bolter_total: usize,
    bolter_detected: usize,
    shotgun_total: usize,
    shotgun_detected: usize,
};

pub const PayloadCoverageMetrics = struct {
    known_good_total: usize,
    false_positives: usize,
    random_byte_total: usize,
    random_byte_detected: usize,
    eof_total: usize,
    eof_detected: usize,
};

/// Measure the strict PEF Huffman result over a deterministic syntax fixture.
/// The fixture's sparse codebook makes every nonzero payload bit invalid, so
/// each seeded byte replacement has an independently fixed expected verdict.
pub fn measurePayloadCoverage() PayloadCoverageMetrics {
    var metrics: PayloadCoverageMetrics = .{
        .known_good_total = 1,
        .false_positives = 0,
        .random_byte_total = 0,
        .random_byte_detected = 0,
        .eof_total = 0,
        .eof_detected = 0,
    };

    var table = [_]u8{0} ** 17;
    table[0] = 5;
    table[16] = 1;
    const valid_payload = [_]u8{0} ** 256;
    const base_input: PayloadInput = .{
        .compression = compression_pentax_huffman,
        .payload = .{ .encoded = &valid_payload },
        .width = 2048,
        .height = 1,
        .bits_per_sample = 12,
        .huffman_table = &table,
    };

    if (!isFull(validatePefPayload(base_input))) metrics.false_positives += 1;

    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    for (0..valid_payload.len) |byte_index| {
        var mutated = valid_payload;
        mutated[byte_index] = random.int(u8);
        if (mutated[byte_index] == valid_payload[byte_index]) mutated[byte_index] = 1;
        var input = base_input;
        input.payload = .{ .encoded = &mutated };
        metrics.random_byte_total += 1;
        if (isFail(validatePefPayload(input))) metrics.random_byte_detected += 1;
    }

    for (0..valid_payload.len) |cut| {
        var input = base_input;
        input.payload = .{ .encoded = valid_payload[0..cut] };
        metrics.eof_total += 1;
        if (isFail(validatePefPayload(input))) metrics.eof_detected += 1;
    }

    return metrics;
}

fn isFull(result: sensor_validation.Result) bool {
    return switch (result) {
        .full => true,
        else => false,
    };
}

fn isFail(result: sensor_validation.Result) bool {
    return switch (result) {
        .fail => true,
        else => false,
    };
}

/// Measure a bounded, deterministic PEF Huffman gate. The mutation oracle is
/// the sparse valid code table fixed before mutation: every injected one-bit
/// enters an unassigned prefix and is therefore provably invalid.
pub fn measureV1Gate() GateMetrics {
    var metrics: GateMetrics = .{
        .valid_total = 3,
        .false_positives = 0,
        .known_bad_total = 4,
        .false_negatives = 0,
        .sniper_total = 0,
        .sniper_detected = 0,
        .bolter_total = 0,
        .bolter_detected = 0,
        .shotgun_total = 1,
        .shotgun_detected = 0,
    };

    var sparse_table = [_]u8{0} ** 17;
    sparse_table[0] = 5;
    sparse_table[16] = 1;
    const zero_payload = [_]u8{0} ** 256;

    var signed_table = [_]u8{0} ** 20;
    signed_table[0] = 6;
    signed_table[17] = 8;
    signed_table[18] = 1;
    signed_table[19] = 1;
    if (validatePefHuffman(&zero_payload, 2048, 1, 12, &sparse_table) != null) {
        metrics.false_positives += 1;
    }
    if (validatePefPacked12(&([_]u8{0} ** 12), 4, 2) != null) {
        metrics.false_positives += 1;
    }
    if (validatePefHuffman(&.{ 0xff, 0xfa, 0x00 }, 3, 3, 12, &signed_table) != null) {
        metrics.false_positives += 1;
    }

    const known_bad_detected = [_]bool{
        validatePefHuffman(&.{}, 1, 1, 12, &.{}) != null,
        validatePefHuffman(&.{}, 1, 1, 12, &sparse_table) != null,
        validatePefHuffman(&.{0x80}, 1, 1, 12, &sparse_table) != null,
        validatePefHuffman(&.{0xfc}, 3, 1, 1, &signed_table) != null,
    };
    for (known_bad_detected) |detected| {
        if (!detected) metrics.false_negatives += 1;
    }

    var byte_index: usize = 0;
    while (byte_index < zero_payload.len) : (byte_index += 1) {
        var bit_index: u3 = 0;
        while (true) {
            var mutated = zero_payload;
            mutated[byte_index] ^= @as(u8, 1) << bit_index;
            metrics.sniper_total += 1;
            if (validatePefHuffman(&mutated, 2048, 1, 12, &sparse_table) != null) {
                metrics.sniper_detected += 1;
            }
            if (bit_index == 7) break;
            bit_index += 1;
        }
    }

    var block_start: usize = 0;
    while (block_start < zero_payload.len) : (block_start += 16) {
        var mutated = zero_payload;
        @memset(mutated[block_start..][0..16], 0xff);
        metrics.bolter_total += 1;
        if (validatePefHuffman(&mutated, 2048, 1, 12, &sparse_table) != null) {
            metrics.bolter_detected += 1;
        }
    }

    var shotgun = zero_payload;
    var pellet: usize = 0;
    while (pellet < 64) : (pellet += 1) shotgun[(pellet * 37) % shotgun.len] = 0xff;
    if (validatePefHuffman(&shotgun, 2048, 1, 12, &sparse_table) != null) {
        metrics.shotgun_detected = 1;
    }

    return metrics;
}

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
    const finding = validatePefHuffmanDetailed(
        strip_data,
        width,
        height,
        bits_per_sample,
        huff_table_data,
        .little,
        limits,
        false,
    ) orelse return null;
    return decodeErrorFromCode(finding.code);
}

/// Locate Pentax Huffman tag 0x0220 in an AOC MakerNote. Pentax stores the
/// table offset relative to the host file, so the caller supplies the
/// MakerNote's host offset. Returned bytes borrow `maker_note`; the returned
/// offset is relative to that slice.
pub fn findPefHuffmanTable(
    maker_note: []const u8,
    maker_note_host_offset: u64,
) HuffmanTableLookup {
    const maker_header_size: usize = 6;
    if (maker_note.len < 4 or !std.mem.eql(u8, maker_note[0..4], "AOC\x00")) {
        return .{ .structural = .unsupported_metadata_layout };
    }
    if (maker_note.len < maker_header_size + 2) {
        return .{ .fail = makeFailure(.metadata_out_of_bounds, .metadata, maker_note.len) };
    }

    const byte_order: std.builtin.Endian = if (std.mem.eql(u8, maker_note[4..6], "II"))
        .little
    else if (std.mem.eql(u8, maker_note[4..6], "MM"))
        .big
    else
        return .{ .structural = .unsupported_metadata_layout };

    const entry_count = std.mem.readInt(u16, maker_note[maker_header_size..][0..2], byte_order);
    const entries_start = maker_header_size + 2;
    const entries_bytes = std.math.mul(usize, entry_count, 12) catch
        return .{ .fail = makeFailure(.metadata_out_of_bounds, .metadata, maker_header_size) };
    const entries_end = std.math.add(usize, entries_start, entries_bytes) catch
        return .{ .fail = makeFailure(.metadata_out_of_bounds, .metadata, maker_header_size) };
    const directory_end = std.math.add(usize, entries_end, 4) catch
        return .{ .fail = makeFailure(.metadata_out_of_bounds, .metadata, maker_header_size) };
    if (directory_end > maker_note.len) {
        return .{ .fail = makeFailure(.metadata_out_of_bounds, .metadata, maker_header_size) };
    }

    var entry_index: usize = 0;
    while (entry_index < entry_count) : (entry_index += 1) {
        const entry_offset = entries_start + entry_index * 12;
        const entry = maker_note[entry_offset..][0..12];
        const tag = std.mem.readInt(u16, entry[0..2], byte_order);
        if (tag != 0x0220) continue;

        const field_type = std.mem.readInt(u16, entry[2..4], byte_order);
        const byte_count_u32 = std.mem.readInt(u32, entry[4..8], byte_order);
        if (field_type != 7 or byte_count_u32 == 0) {
            return .{ .fail = makeFailure(.malformed_metadata, .metadata, entry_offset + 2) };
        }
        const byte_count: usize = @intCast(byte_count_u32);
        if (byte_count <= 4) {
            return .{ .found = .{
                .bytes = entry[8 .. 8 + byte_count],
                .byte_order = byte_order,
                .byte_offset = @intCast(entry_offset + 8),
            } };
        }

        const host_value_offset = @as(u64, std.mem.readInt(u32, entry[8..12], byte_order));
        const view_value_offset_u64 = std.math.sub(u64, host_value_offset, maker_note_host_offset) catch
            return .{ .fail = makeFailure(.metadata_out_of_bounds, .metadata, entry_offset + 8) };
        const view_value_offset = std.math.cast(usize, view_value_offset_u64) orelse
            return .{ .fail = makeFailure(.metadata_out_of_bounds, .metadata, entry_offset + 8) };
        const value_end = std.math.add(usize, view_value_offset, byte_count) catch
            return .{ .fail = makeFailure(.metadata_out_of_bounds, .metadata, entry_offset + 8) };
        if (value_end > maker_note.len) {
            return .{ .fail = makeFailure(.metadata_out_of_bounds, .metadata, entry_offset + 8) };
        }
        return .{ .found = .{
            .bytes = maker_note[view_value_offset..value_end],
            .byte_order = byte_order,
            .byte_offset = view_value_offset_u64,
        } };
    }

    return .{ .structural = .huffman_table_unavailable };
}

/// Validate one PEF sensor payload with compression-aware byte-stage dispatch.
/// Standard TIFF PackBits must be removed by tiffz before the extent check;
/// Pentax compression 65535 is checked here as an encoded Huffman stream.
pub fn validatePefPayload(input: PayloadInput) sensor_validation.Result {
    switch (input.compression) {
        compression_packbits => switch (input.payload) {
            .encoded => return .{ .structural = .requires_tiff_decompression },
            .tiff_decoded => |decoded| {
                if (input.bits_per_sample != 12) {
                    return fail(.unsupported_bit_depth, .metadata, 0);
                }
                if (validatePefPacked12(decoded, input.width, input.height)) |err| {
                    return switch (err) {
                        error.Truncated => fail(.truncated, .payload, decoded.len),
                        error.DimensionsTooLarge => fail(.invalid_dimensions, .metadata, 0),
                        else => unreachable,
                    };
                }
                return .{ .structural = .sample_values_have_no_integrity_signal };
            },
        },
        compression_pentax_huffman => switch (input.payload) {
            .tiff_decoded => return .{ .structural = .encoded_payload_required },
            .encoded => |encoded| {
                const table = input.huffman_table orelse
                    return .{ .structural = .huffman_table_unavailable };
                if (validatePefHuffmanDetailed(
                    encoded,
                    input.width,
                    input.height,
                    input.bits_per_sample,
                    table,
                    input.huffman_table_byte_order,
                    input.limits,
                    true,
                )) |finding| return .{ .fail = finding };
                return .{ .full = {} };
            },
        },
        else => return .{ .structural = .unsupported_compression },
    }
}

fn validatePefHuffmanDetailed(
    strip_data: []const u8,
    width: u32,
    height: u32,
    bits_per_sample: u16,
    huff_table_data: []const u8,
    huffman_table_byte_order: std.builtin.Endian,
    limits: PefDecodeLimits,
    strict_end: bool,
) ?sensor_validation.Failure {
    if (width == 0 or height == 0) return makeFailure(.invalid_dimensions, .metadata, 0);
    if (bits_per_sample == 0 or bits_per_sample > 16) return makeFailure(.unsupported_bit_depth, .metadata, 0);
    if (huff_table_data.len < 2) return makeFailure(.invalid_huffman_table, .metadata, huff_table_data.len);

    const total_pixels = @as(u64, width) * @as(u64, height);
    if (total_pixels > limits.max_pixels) return makeFailure(.work_limit_exceeded, .metadata, 0);

    const dep_raw = std.mem.readInt(u16, huff_table_data[0..2], huffman_table_byte_order);
    const dependency_count: u8 = @intCast((dep_raw +% dependency_adjustment) & dependency_mask);
    if (dependency_count == 0) return makeFailure(.invalid_huffman_table, .metadata, 0);
    const code_bytes = @as(usize, dependency_count) * 2;
    const table_end = maker_note_table_start + code_bytes + dependency_count;
    if (huff_table_data.len < table_end) return makeFailure(.invalid_huffman_table, .metadata, huff_table_data.len);

    var huffman: [huffman_lookup_size]HuffmanEntry = .{HuffmanEntry{}} ** huffman_lookup_size;

    var difference_bits: u8 = 0;
    while (difference_bits < dependency_count) : (difference_bits += 1) {
        const code_offset = maker_note_table_start + @as(usize, difference_bits) * 2;
        const code_value = std.mem.readInt(u16, huff_table_data[code_offset..][0..2], huffman_table_byte_order);
        const bit_length = huff_table_data[maker_note_table_start + code_bytes + difference_bits];
        if (bit_length == 0 or bit_length > huffman_lookup_bits or code_value >= huffman_lookup_size) {
            return makeFailure(.invalid_huffman_table, .metadata, code_offset);
        }

        const range: u16 = @as(u16, huffman_lookup_size) >> @intCast(bit_length);
        if (code_value % range != 0) return makeFailure(.invalid_huffman_table, .metadata, code_offset);
        const end_exclusive = std.math.add(u32, code_value, range) catch
            return makeFailure(.invalid_huffman_table, .metadata, code_offset);
        if (end_exclusive > huffman_lookup_size) return makeFailure(.invalid_huffman_table, .metadata, code_offset);

        var code: u32 = code_value;
        while (code < end_exclusive) : (code += 1) {
            const index: usize = @intCast(code);
            if (huffman[index].code_bits != 0) return makeFailure(.invalid_huffman_table, .metadata, code_offset);
            huffman[index] = .{
                .code_bits = bit_length,
                .difference_bits = difference_bits,
            };
        }
    }

    const strip_bytes = std.math.cast(u64, strip_data.len) orelse
        return makeFailure(.invalid_dimensions, .metadata, 0);
    const available_bits = std.math.mul(u64, strip_bytes, 8) catch
        return makeFailure(.invalid_dimensions, .metadata, 0);
    if (total_pixels > available_bits) return makeFailure(.truncated, .payload, strip_data.len);

    var reader = BitReader.init(strip_data);
    var vertical_predictor: [2][2]u16 = .{ .{ 0, 0 }, .{ 0, 0 } };
    var horizontal_predictor: [2]u16 = .{ 0, 0 };

    var row: u32 = 0;
    while (row < height) : (row += 1) {
        var column: u32 = 0;
        while (column < width) : (column += 1) {
            const difference = ljpegDiff(&reader, &huffman) catch |err| {
                return makeFailure(
                    codeFromDecodeError(err),
                    .payload,
                    @min(reader.bit_position / 8, strip_data.len),
                );
            };

            if (column < 2) {
                vertical_predictor[row & 1][column] +%= @bitCast(@as(i16, @intCast(difference)));
                horizontal_predictor[column] = vertical_predictor[row & 1][column];
            } else {
                horizontal_predictor[column & 1] +%= @bitCast(@as(i16, @intCast(difference)));
            }

            const pixel = horizontal_predictor[column & 1];
            if (bits_per_sample < 16) {
                const shift: u4 = @intCast(bits_per_sample);
                if (pixel >> shift != 0) {
                    const byte_offset = if (reader.bit_position == 0) 0 else (reader.bit_position - 1) / 8;
                    return makeFailure(.sample_overflow, .payload, byte_offset);
                }
            }
        }
    }

    if (strict_end) {
        const partial_bits = reader.bit_position % 8;
        if (partial_bits != 0) {
            const padding_bits: u4 = @intCast(8 - partial_bits);
            const padding_mask: u8 = @intCast((@as(u16, 1) << padding_bits) - 1);
            const byte_offset = reader.bit_position / 8;
            if (strip_data[byte_offset] & padding_mask != 0) {
                return makeFailure(.trailing_mismatch, .payload, byte_offset);
            }
        }
        const consumed_bytes = (reader.bit_position + 7) / 8;
        if (consumed_bytes < strip_data.len) {
            return makeFailure(.trailing_mismatch, .payload, consumed_bytes);
        }
    }

    return null;
}

fn fail(
    code: sensor_validation.ErrorCode,
    region: sensor_validation.Region,
    byte_offset: usize,
) sensor_validation.Result {
    return .{ .fail = makeFailure(code, region, byte_offset) };
}

fn makeFailure(
    code: sensor_validation.ErrorCode,
    region: sensor_validation.Region,
    byte_offset: usize,
) sensor_validation.Failure {
    return .{
        .code = code,
        .region = region,
        .byte_offset = @intCast(byte_offset),
    };
}

fn codeFromDecodeError(err: PefDecodeError) sensor_validation.ErrorCode {
    return switch (err) {
        error.Truncated => .truncated,
        error.PixelOverflow => .sample_overflow,
        error.InvalidHuffmanTable => .invalid_huffman_table,
        error.InvalidHuffmanCode => .invalid_huffman_code,
        error.DimensionsTooLarge => .invalid_dimensions,
        error.UnsupportedBitDepth => .unsupported_bit_depth,
        error.WorkLimitExceeded => .work_limit_exceeded,
    };
}

fn decodeErrorFromCode(code: sensor_validation.ErrorCode) PefDecodeError {
    return switch (code) {
        .truncated => error.Truncated,
        .sample_overflow => error.PixelOverflow,
        .invalid_huffman_table => error.InvalidHuffmanTable,
        .invalid_huffman_code => error.InvalidHuffmanCode,
        .invalid_dimensions => error.DimensionsTooLarge,
        .unsupported_bit_depth => error.UnsupportedBitDepth,
        .work_limit_exceeded => error.WorkLimitExceeded,
        .trailing_mismatch, .metadata_out_of_bounds, .malformed_metadata => error.InvalidHuffmanCode,
    };
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

test "bounded PEF v1 corpus and sniper bolter shotgun mutations have fixed scores" {
    const metrics = measureV1Gate();
    try std.testing.expectEqual(@as(usize, 3), metrics.valid_total);
    try std.testing.expectEqual(@as(usize, 0), metrics.false_positives);
    try std.testing.expectEqual(@as(usize, 4), metrics.known_bad_total);
    try std.testing.expectEqual(@as(usize, 0), metrics.false_negatives);
    try std.testing.expectEqual(@as(usize, 2048), metrics.sniper_total);
    try std.testing.expectEqual(metrics.sniper_total, metrics.sniper_detected);
    try std.testing.expectEqual(@as(usize, 16), metrics.bolter_total);
    try std.testing.expectEqual(metrics.bolter_total, metrics.bolter_detected);
    try std.testing.expectEqual(@as(usize, 1), metrics.shotgun_total);
    try std.testing.expectEqual(metrics.shotgun_total, metrics.shotgun_detected);
}

test "PEF payload dispatch distinguishes TIFF PackBits from Pentax Huffman" {
    var table = [_]u8{0} ** 17;
    table[0] = 5;
    table[16] = 1;

    const packbits = validatePefPayload(.{
        .compression = 32773,
        .payload = .{ .tiff_decoded = &([_]u8{0} ** 12) },
        .width = 4,
        .height = 2,
        .bits_per_sample = 12,
    });
    try std.testing.expectEqual(
        sensor_validation.Result{ .structural = .sample_values_have_no_integrity_signal },
        packbits,
    );

    const huffman = validatePefPayload(.{
        .compression = 65535,
        .payload = .{ .encoded = &.{0} },
        .width = 1,
        .height = 1,
        .bits_per_sample = 12,
        .huffman_table = &table,
    });
    try std.testing.expectEqual(sensor_validation.Result{ .full = {} }, huffman);
}

test "PEF payload dispatch names every non-full integration reach" {
    const dimensions = .{
        .width = @as(u32, 1),
        .height = @as(u32, 1),
        .bits_per_sample = @as(u16, 12),
    };
    try std.testing.expectEqual(
        sensor_validation.Result{ .structural = .requires_tiff_decompression },
        validatePefPayload(.{
            .compression = compression_packbits,
            .payload = .{ .encoded = &.{0} },
            .width = dimensions.width,
            .height = dimensions.height,
            .bits_per_sample = dimensions.bits_per_sample,
        }),
    );
    try std.testing.expectEqual(
        sensor_validation.Result{ .structural = .encoded_payload_required },
        validatePefPayload(.{
            .compression = compression_pentax_huffman,
            .payload = .{ .tiff_decoded = &.{0} },
            .width = dimensions.width,
            .height = dimensions.height,
            .bits_per_sample = dimensions.bits_per_sample,
        }),
    );
    try std.testing.expectEqual(
        sensor_validation.Result{ .structural = .huffman_table_unavailable },
        validatePefPayload(.{
            .compression = compression_pentax_huffman,
            .payload = .{ .encoded = &.{0} },
            .width = dimensions.width,
            .height = dimensions.height,
            .bits_per_sample = dimensions.bits_per_sample,
        }),
    );
    try std.testing.expectEqual(
        sensor_validation.Result{ .structural = .unsupported_compression },
        validatePefPayload(.{
            .compression = 1,
            .payload = .{ .encoded = &.{0} },
            .width = dimensions.width,
            .height = dimensions.height,
            .bits_per_sample = dimensions.bits_per_sample,
        }),
    );
}

test "PEF strict Huffman result rejects nonzero padding and trailing bytes with offsets" {
    var table = [_]u8{0} ** 17;
    table[0] = 5;
    table[16] = 1;

    const nonzero_padding = validatePefPayload(.{
        .compression = 65535,
        .payload = .{ .encoded = &.{0x01} },
        .width = 1,
        .height = 1,
        .bits_per_sample = 12,
        .huffman_table = &table,
    });
    try std.testing.expectEqual(
        sensor_validation.Result{ .fail = .{
            .code = .trailing_mismatch,
            .region = .payload,
            .byte_offset = 0,
        } },
        nonzero_padding,
    );

    const trailing_byte = validatePefPayload(.{
        .compression = 65535,
        .payload = .{ .encoded = &.{ 0, 0 } },
        .width = 1,
        .height = 1,
        .bits_per_sample = 12,
        .huffman_table = &table,
    });
    try std.testing.expectEqual(
        sensor_validation.Result{ .fail = .{
            .code = .trailing_mismatch,
            .region = .payload,
            .byte_offset = 1,
        } },
        trailing_byte,
    );
}

test "PEF payload failures report the failing byte region and offset" {
    var table = [_]u8{0} ** 17;
    table[0] = 5;
    table[16] = 1;

    const truncated = validatePefPayload(.{
        .compression = 65535,
        .payload = .{ .encoded = &.{} },
        .width = 1,
        .height = 1,
        .bits_per_sample = 12,
        .huffman_table = &table,
    });
    try std.testing.expectEqual(
        sensor_validation.Result{ .fail = .{
            .code = .truncated,
            .region = .payload,
            .byte_offset = 0,
        } },
        truncated,
    );

    const malformed_table = validatePefPayload(.{
        .compression = 65535,
        .payload = .{ .encoded = &.{0} },
        .width = 1,
        .height = 1,
        .bits_per_sample = 12,
        .huffman_table = &.{},
    });
    try std.testing.expectEqual(
        sensor_validation.Result{ .fail = .{
            .code = .invalid_huffman_table,
            .region = .metadata,
            .byte_offset = 0,
        } },
        malformed_table,
    );
}

test "PEF strict payload coverage measures seeded random-byte and every EOF cut" {
    const metrics = measurePayloadCoverage();
    try std.testing.expectEqual(@as(usize, 256), metrics.random_byte_total);
    try std.testing.expectEqual(metrics.random_byte_total, metrics.random_byte_detected);
    try std.testing.expectEqual(@as(usize, 256), metrics.eof_total);
    try std.testing.expectEqual(metrics.eof_total, metrics.eof_detected);
}

test "PEF Huffman tables honor the MakerNote byte order" {
    const k10d_table = [_]u8{
        0x00, 0x01, 0x00, 0x00, 0x00, 0x16, 0x00, 0x28,
        0x00, 0x49, 0x00, 0x23, 0x00, 0x4d, 0x0f, 0x00,
        0x0c, 0x00, 0x08, 0x00, 0x00, 0x00, 0x04, 0x00,
        0x0a, 0x00, 0x0e, 0x00, 0x0f, 0x80, 0x0f, 0xc0,
        0x0f, 0xe0, 0x0f, 0xf0, 0x0f, 0xf8, 0x0f, 0xfc,
        0x05, 0x03, 0x03, 0x02, 0x02, 0x03, 0x04, 0x06,
        0x07, 0x08, 0x09, 0x0a, 0x0a,
    };
    const result = validatePefPayload(.{
        .compression = compression_pentax_huffman,
        .payload = .{ .encoded = &.{0x20} },
        .width = 1,
        .height = 1,
        .bits_per_sample = 12,
        .huffman_table = &k10d_table,
        .huffman_table_byte_order = .big,
    });
    try std.testing.expectEqual(sensor_validation.Result{ .full = {} }, result);
}

test "PEF AOC MakerNote lookup returns Huffman table bytes, order, and offset" {
    var maker_note = [_]u8{0} ** 37;
    @memcpy(maker_note[0..4], "AOC\x00");
    @memcpy(maker_note[4..6], "MM");
    std.mem.writeInt(u16, maker_note[6..8], 1, .big);
    std.mem.writeInt(u16, maker_note[8..10], 0x0220, .big);
    std.mem.writeInt(u16, maker_note[10..12], 7, .big);
    std.mem.writeInt(u32, maker_note[12..16], 5, .big);
    std.mem.writeInt(u32, maker_note[16..20], 132, .big);
    const table_bytes = [_]u8{ 1, 2, 3, 4, 5 };
    @memcpy(maker_note[32..37], &table_bytes);

    const lookup = findPefHuffmanTable(&maker_note, 100);
    switch (lookup) {
        .found => |table| {
            try std.testing.expectEqual(std.builtin.Endian.big, table.byte_order);
            try std.testing.expectEqual(@as(u64, 32), table.byte_offset);
            try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5 }, table.bytes);
        },
        else => return error.ExpectedHuffmanTable,
    }
}

test "PEF MakerNote lookup distinguishes absent, unsupported, and out-of-bounds tables" {
    var absent = [_]u8{0} ** 24;
    @memcpy(absent[0..4], "AOC\x00");
    @memcpy(absent[4..6], "II");
    std.mem.writeInt(u16, absent[6..8], 0, .little);
    try std.testing.expectEqual(
        HuffmanTableLookup{ .structural = .huffman_table_unavailable },
        findPefHuffmanTable(&absent, 0),
    );
    try std.testing.expectEqual(
        HuffmanTableLookup{ .structural = .unsupported_metadata_layout },
        findPefHuffmanTable("PENTAX", 0),
    );

    var out_of_bounds = [_]u8{0} ** 24;
    @memcpy(out_of_bounds[0..4], "AOC\x00");
    @memcpy(out_of_bounds[4..6], "MM");
    std.mem.writeInt(u16, out_of_bounds[6..8], 1, .big);
    std.mem.writeInt(u16, out_of_bounds[8..10], 0x0220, .big);
    std.mem.writeInt(u16, out_of_bounds[10..12], 7, .big);
    std.mem.writeInt(u32, out_of_bounds[12..16], 53, .big);
    std.mem.writeInt(u32, out_of_bounds[16..20], 132, .big);
    try std.testing.expectEqual(
        HuffmanTableLookup{ .fail = .{
            .code = .metadata_out_of_bounds,
            .region = .metadata,
            .byte_offset = 16,
        } },
        findPefHuffmanTable(&out_of_bounds, 100),
    );
}
