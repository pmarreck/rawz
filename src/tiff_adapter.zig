//! Adapter from tiffz's parsed container model to pure RAW classification.

const std = @import("std");
const tiffz = @import("tiffz");
const classification = @import("classification.zig");

/// Stable rawz error contract. Dependency errors are mapped at this adapter
/// boundary so tiffz changes cannot silently alter rawz's public API.
pub const Error = error{
    InvalidArgument,
    MalformedTiff,
    InvalidSemanticTag,
    LimitExceeded,
    OutOfMemory,
    Io,
    UnsupportedTiffFeature,
    Internal,
};

const Tag = struct {
    const new_subfile_type: u16 = 254;
    const make: u16 = 271;
    const model: u16 = 272;
    const sub_ifds: u16 = 330;
    const exif_ifd: u16 = 34665;
    const maker_note: u16 = 37500;
    const dng_version: u16 = 50706;
};

const PendingKind = enum(u1) {
    image,
    metadata,
};

const PendingIfd = struct {
    offset: u64,
    kind: PendingKind,
};

const EvidenceAccumulator = struct {
    const image_seen: u8 = 1 << 0;
    const metadata_seen: u8 = 1 << 1;
    const image_processed: u8 = 1 << 2;
    const metadata_processed: u8 = 1 << 3;

    allocator: std.mem.Allocator,
    source: tiffz.Source,
    endian: tiffz.header.Endian,
    offset_width: tiffz.ifd.OffsetWidth,
    limits: tiffz.Limits,
    ifds: std.ArrayListUnmanaged(classification.IfdEvidence) = .empty,
    pending: std.ArrayListUnmanaged(PendingIfd) = .empty,
    offset_states: std.AutoHashMapUnmanaged(u64, u8) = .empty,
    make_buffer: [128]u8 = undefined,
    model_buffer: [128]u8 = undefined,
    make: ?[]const u8 = null,
    model: ?[]const u8 = null,
    has_maker_note: bool = false,
    has_dng_version: bool = false,

    fn deinit(self: *EvidenceAccumulator) void {
        self.ifds.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.offset_states.deinit(self.allocator);
    }

    /// Record a decoder-owned linked IFD as processed, allowing any queued
    /// duplicate reference to be skipped without another parse.
    fn markProcessed(self: *EvidenceAccumulator, offset: u64, kind: PendingKind) !void {
        const state = try self.stateFor(offset);
        state.* |= seenMask(kind) | processedMask(kind);
    }

    /// Add one unique offset/purpose pair to the worklist while bounding the
    /// total number of distinct input-controlled offsets.
    fn enqueue(self: *EvidenceAccumulator, offset: u64, kind: PendingKind) !void {
        const state = try self.stateFor(offset);
        const seen = seenMask(kind);
        if (state.* & seen != 0) return;
        state.* |= seen;
        try self.pending.append(self.allocator, .{ .offset = offset, .kind = kind });
    }

    fn stateFor(self: *EvidenceAccumulator, offset: u64) !*u8 {
        if (offset == 0) return error.InvalidSemanticTag;
        if (self.offset_states.getPtr(offset)) |state| return state;
        if (self.offset_states.count() >= self.limits.max_ifds) {
            return error.LimitExceededIfdCount;
        }
        try self.offset_states.put(self.allocator, offset, 0);
        return self.offset_states.getPtr(offset).?;
    }

    fn beginPending(self: *EvidenceAccumulator, pending: PendingIfd) !bool {
        const state = try self.stateFor(pending.offset);
        const processed = processedMask(pending.kind);
        if (state.* & processed != 0) return false;
        state.* |= processed;
        return true;
    }

    /// Collect image-layout facts and schedule child image directories; shared
    /// metadata extraction handles Make/Model, MakerNote, DNG, and Exif links.
    fn collectImage(
        self: *EvidenceAccumulator,
        dir: *const tiffz.ifd.Ifd,
        location: classification.IfdLocation,
    ) !void {
        try self.ifds.append(self.allocator, .{
            .location = location,
            .photometric = try readScalarU16(dir, tiffz.tags.photometric, self.endian),
            .new_subfile_type = try readScalarU32(dir, Tag.new_subfile_type, self.endian),
        });
        try self.collectMetadata(dir);

        const entry = dir.get(Tag.sub_ifds) orelse return;
        switch (entry.field_type) {
            .long, .long8, .ifd8 => {},
            else => return error.InvalidSemanticTag,
        }
        if (entry.count > self.limits.max_ifds) return error.LimitExceededIfdCount;
        var child_index: u32 = 0;
        while (child_index < entry.count) : (child_index += 1) {
            const offset = try dir.arrayElementU64(
                Tag.sub_ifds,
                child_index,
                self.endian,
                self.source,
            );
            try self.enqueue(offset, .image);
        }
    }

    fn collectMetadata(self: *EvidenceAccumulator, dir: *const tiffz.ifd.Ifd) !void {
        if (self.make == null) {
            self.make = try readAscii(dir, Tag.make, self.endian, self.source, &self.make_buffer);
        } else {
            try validateAsciiTag(dir, Tag.make);
        }
        if (self.model == null) {
            self.model = try readAscii(dir, Tag.model, self.endian, self.source, &self.model_buffer);
        } else {
            try validateAsciiTag(dir, Tag.model);
        }

        const dir_has_maker_note = try hasValidMakerNote(dir);
        const dir_has_dng_version = try hasValidDngVersion(dir);
        self.has_maker_note = self.has_maker_note or dir_has_maker_note;
        self.has_dng_version = self.has_dng_version or dir_has_dng_version;

        if (try readOffset(dir, Tag.exif_ifd, self.endian)) |offset| {
            try self.enqueue(offset, .metadata);
        }
    }

    fn popPending(self: *EvidenceAccumulator) ?PendingIfd {
        if (self.pending.items.len == 0) return null;
        const pending = self.pending.items[self.pending.items.len - 1];
        self.pending.items.len -= 1;
        return pending;
    }

    fn evidence(self: *const EvidenceAccumulator) classification.Evidence {
        return .{
            .make = self.make,
            .model = self.model,
            .has_maker_note = self.has_maker_note,
            .has_dng_version = self.has_dng_version,
            .ifds = self.ifds.items,
        };
    }

    fn seenMask(kind: PendingKind) u8 {
        return switch (kind) {
            .image => image_seen,
            .metadata => metadata_seen,
        };
    }

    fn processedMask(kind: PendingKind) u8 {
        return switch (kind) {
            .image => image_processed,
            .metadata => metadata_processed,
        };
    }
};

/// Classify an in-memory TIFF-family container by adapting tiffz's parsed IFD
/// facts into the allocation-free semantic classifier.
pub fn classifyBuffer(allocator: std.mem.Allocator, bytes: []const u8) Error!classification.Format {
    return classifyBufferInner(allocator, bytes) catch |err| return mapError(err);
}

fn classifyBufferInner(allocator: std.mem.Allocator, bytes: []const u8) !classification.Format {
    var handle = tiffz.source.BufferHandle.init(bytes);
    const source = tiffz.Source.fromBuffer(&handle);
    var decoder = try tiffz.Decoder.open(allocator, source);
    defer decoder.deinit();
    var accumulator: EvidenceAccumulator = .{
        .allocator = allocator,
        .source = source,
        .endian = decoder.endian,
        .offset_width = if (decoder.bigtiff) .big else .classic,
        .limits = decoder.limits,
    };
    defer accumulator.deinit();

    var index: usize = 0;
    while (true) : (index += 1) {
        const dir = decoder.ifd(index) catch |err| switch (err) {
            error.InvalidArgument => break,
            else => return err,
        };
        try accumulator.markProcessed(decoder.ifd_offsets.items[index], .image);
        try accumulator.collectImage(dir, if (index == 0) .primary else .child);
    }

    while (accumulator.popPending()) |pending| {
        if (!try accumulator.beginPending(pending)) continue;
        var dir = try tiffz.ifd.parse(
            allocator,
            source,
            decoder.endian,
            pending.offset,
            decoder.limits,
            accumulator.offset_width,
        );
        defer dir.deinit();
        switch (pending.kind) {
            .image => try accumulator.collectImage(&dir, .child),
            .metadata => try accumulator.collectMetadata(&dir),
        }
    }

    return classification.classify(accumulator.evidence());
}

fn mapError(err: anyerror) Error {
    return switch (err) {
        error.InvalidArgument => error.InvalidArgument,
        error.Malformed,
        error.SourceSeekTooFarBack,
        error.SourceShortRead,
        error.SourceTooShort,
        error.IfdChainCycle,
        => error.MalformedTiff,
        error.InvalidSemanticTag => error.InvalidSemanticTag,
        error.LimitExceededIfdCount,
        error.LimitExceededTagCount,
        error.LimitExceededTagValueBytes,
        error.LimitExceededStripCount,
        error.LimitExceededDimension,
        error.LimitExceededTotalSamples,
        error.LimitExceededCodecScratch,
        error.LimitExceededCompressedStripBytes,
        error.LimitExceededDecompressedStripBytes,
        => error.LimitExceeded,
        error.OutOfMemory => error.OutOfMemory,
        error.Io => error.Io,
        error.UnsupportedCompression,
        error.UnsupportedPhotometric,
        error.UnsupportedPredictor,
        error.UnsupportedBitDepth,
        error.UnsupportedTagType,
        error.JpegInTiffPayload,
        => error.UnsupportedTiffFeature,
        error.Bug,
        error.DestTooSmall,
        => error.Internal,
        else => error.Internal,
    };
}

fn readScalarU16(dir: *const tiffz.ifd.Ifd, tag: u16, endian: tiffz.header.Endian) !?u16 {
    const entry = dir.get(tag) orelse return null;
    if (entry.count != 1) return error.InvalidSemanticTag;
    return switch (entry.field_type) {
        .short => tiffz.header.readU16(entry.raw_value_or_offset[0..2], endian),
        else => error.InvalidSemanticTag,
    };
}

fn readScalarU32(dir: *const tiffz.ifd.Ifd, tag: u16, endian: tiffz.header.Endian) !?u32 {
    const entry = dir.get(tag) orelse return null;
    if (entry.count != 1) return error.InvalidSemanticTag;
    return switch (entry.field_type) {
        .long => tiffz.header.readU32(entry.raw_value_or_offset[0..4], endian),
        else => error.InvalidSemanticTag,
    };
}

fn readOffset(dir: *const tiffz.ifd.Ifd, tag: u16, endian: tiffz.header.Endian) !?u64 {
    const entry = dir.get(tag) orelse return null;
    if (entry.count != 1) return error.InvalidSemanticTag;
    return switch (entry.field_type) {
        .long => @as(u64, tiffz.header.readU32(entry.raw_value_or_offset[0..4], endian)),
        .long8, .ifd8 => tiffz.header.readU64(&entry.raw_value_or_offset, endian),
        else => error.InvalidSemanticTag,
    };
}

fn hasValidMakerNote(dir: *const tiffz.ifd.Ifd) !bool {
    const entry = dir.get(Tag.maker_note) orelse return false;
    if (entry.field_type != .undefined or entry.count == 0) return error.InvalidSemanticTag;
    return true;
}

fn hasValidDngVersion(dir: *const tiffz.ifd.Ifd) !bool {
    const entry = dir.get(Tag.dng_version) orelse return false;
    if (entry.field_type != .byte or entry.count != 4) return error.InvalidSemanticTag;
    return true;
}

fn validateAsciiTag(dir: *const tiffz.ifd.Ifd, tag: u16) !void {
    const entry = dir.get(tag) orelse return;
    if (entry.field_type != .ascii or entry.count == 0) return error.InvalidSemanticTag;
}

fn readAscii(
    dir: *const tiffz.ifd.Ifd,
    tag: u16,
    endian: tiffz.header.Endian,
    source: tiffz.Source,
    destination: []u8,
) !?[]const u8 {
    const entry = dir.get(tag) orelse return null;
    if (entry.field_type != .ascii or entry.count == 0) return error.InvalidSemanticTag;
    const byte_count = tiffz.ifd.Ifd.entryValueBytes(entry.*);
    if (byte_count <= destination.len) {
        const value = destination[0..@intCast(byte_count)];
        try dir.readEntryValueCached(tag, endian, source, value);
        return value;
    }

    const cached = dir.cachedValueBytes(tag) orelse return error.InvalidSemanticTag;
    std.mem.copyForwards(u8, destination, cached[0..destination.len]);
    return destination;
}

test "classifies a set of parsed TIFF containers" {
    const olympus_orf = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x04\x00" ++
        "\x06\x01\x03\x00\x01\x00\x00\x00\x23\x80\x00\x00" ++
        "\x0f\x01\x02\x00\x08\x00\x00\x00\x3e\x00\x00\x00" ++
        "\x10\x01\x02\x00\x04\x00\x00\x00E-1\x00" ++
        "\x7c\x92\x07\x00\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "OLYMPUS\x00";
    const olympus_exif_orf = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x03\x00" ++
        "\x06\x01\x03\x00\x01\x00\x00\x00\x23\x80\x00\x00" ++
        "\x0f\x01\x02\x00\x08\x00\x00\x00\x32\x00\x00\x00" ++
        "\x69\x87\x04\x00\x01\x00\x00\x00\x3a\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "OLYMPUS\x00" ++
        "\x01\x00" ++
        "\x7c\x92\x07\x00\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00";
    const rgb_tiff = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x06\x01\x03\x00\x01\x00\x00\x00\x02\x00\x00\x00" ++
        "\x00\x00\x00\x00";
    const dng = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x12\xc6\x01\x00\x04\x00\x00\x00\x01\x04\x00\x00" ++
        "\x00\x00\x00\x00";
    const big_endian_rgb_tiff = "MM\x00\x2a\x00\x00\x00\x08" ++
        "\x00\x01" ++
        "\x01\x06\x00\x03\x00\x00\x00\x01\x00\x02\x00\x00" ++
        "\x00\x00\x00\x00";
    const bigtiff_dng = "II\x2b\x00\x08\x00\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00" ++
        "\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x12\xc6\x01\x00\x04\x00\x00\x00\x00\x00\x00\x00\x01\x04\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00\x00\x00";
    const canon_cr2 = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x05\x00" ++
        "\xfe\x00\x04\x00\x01\x00\x00\x00\x01\x00\x00\x00" ++
        "\x06\x01\x03\x00\x01\x00\x00\x00\x02\x00\x00\x00" ++
        "\x0f\x01\x02\x00\x06\x00\x00\x00\x4a\x00\x00\x00" ++
        "\x4a\x01\x04\x00\x01\x00\x00\x00\x50\x00\x00\x00" ++
        "\x7c\x92\x07\x00\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "Canon\x00" ++
        "\x01\x00" ++
        "\xfe\x00\x04\x00\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00";
    const linked_cfa_cr2 = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x02\x00" ++
        "\x0f\x01\x02\x00\x06\x00\x00\x00\x26\x00\x00\x00" ++
        "\x7c\x92\x07\x00\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x2c\x00\x00\x00" ++ "Canon\x00" ++
        "\x01\x00" ++
        "\x06\x01\x03\x00\x01\x00\x00\x00\x23\x80\x00\x00" ++
        "\x00\x00\x00\x00";
    const nested_cycle_cr2 = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x03\x00" ++
        "\x0f\x01\x02\x00\x06\x00\x00\x00\x32\x00\x00\x00" ++
        "\x4a\x01\x04\x00\x01\x00\x00\x00\x38\x00\x00\x00" ++
        "\x7c\x92\x07\x00\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++ "Canon\x00" ++
        "\x01\x00" ++
        "\x4a\x01\x04\x00\x01\x00\x00\x00\x4a\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x02\x00" ++
        "\x06\x01\x03\x00\x01\x00\x00\x00\x23\x80\x00\x00" ++
        "\x4a\x01\x04\x00\x01\x00\x00\x00\x38\x00\x00\x00" ++
        "\x00\x00\x00\x00";
    const bigtiff_out_of_line_sub_ifd = "II\x2b\x00\x08\x00\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00" ++
        "\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x4a\x01\x10\x00\x02\x00\x00\x00\x00\x00\x00\x00\x34\x00\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00\x00\x00" ++
        "\x44\x00\x00\x00\x00\x00\x00\x00\x44\x00\x00\x00\x00\x00\x00\x00" ++
        "\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x12\xc6\x01\x00\x04\x00\x00\x00\x00\x00\x00\x00\x01\x04\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00\x00\x00\x00\x00";

    const Case = struct {
        name: []const u8,
        bytes: []const u8,
        expected: classification.Format,
    };
    const cases = [_]Case{
        .{ .name = "ORF", .bytes = olympus_orf, .expected = .orf },
        .{ .name = "ORF with MakerNote in Exif IFD", .bytes = olympus_exif_orf, .expected = .orf },
        .{ .name = "photographic TIFF", .bytes = rgb_tiff, .expected = .tiff },
        .{ .name = "DNG", .bytes = dng, .expected = .dng },
        .{ .name = "big-endian photographic TIFF", .bytes = big_endian_rgb_tiff, .expected = .tiff },
        .{ .name = "BigTIFF DNG", .bytes = bigtiff_dng, .expected = .dng },
        .{ .name = "CR2 sensor SubIFD", .bytes = canon_cr2, .expected = .cr2 },
        .{ .name = "CR2 sensor in linked IFD", .bytes = linked_cfa_cr2, .expected = .cr2 },
        .{ .name = "CR2 nested SubIFD cycle", .bytes = nested_cycle_cr2, .expected = .cr2 },
        .{ .name = "BigTIFF repeated out-of-line SubIFD", .bytes = bigtiff_out_of_line_sub_ifd, .expected = .dng },
    };

    for (cases) |case| {
        const actual = classifyBuffer(std.testing.allocator, case.bytes) catch |err| {
            std.debug.print("parsed TIFF classifier case errored: {s}: {s}\n", .{
                case.name,
                @errorName(err),
            });
            return err;
        };
        std.testing.expectEqual(case.expected, actual) catch |err| {
            std.debug.print("parsed TIFF classifier case failed: {s}\n", .{case.name});
            return err;
        };
    }
}

test "rejects malformed TIFF adapter inputs" {
    try std.testing.expectError(error.MalformedTiff, classifyBuffer(std.testing.allocator, "II"));

    const invalid_exif_offset = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x69\x87\x04\x00\x01\x00\x00\x00\x00\x01\x00\x00" ++
        "\x00\x00\x00\x00";
    try std.testing.expectError(
        error.MalformedTiff,
        classifyBuffer(std.testing.allocator, invalid_exif_offset),
    );

    const malformed_photometric = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x06\x01\x02\x00\x01\x00\x00\x00\x02\x00\x00\x00" ++
        "\x00\x00\x00\x00";
    try std.testing.expectError(
        error.InvalidSemanticTag,
        classifyBuffer(std.testing.allocator, malformed_photometric),
    );

    const oversized_long_photometric = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x06\x01\x04\x00\x01\x00\x00\x00\x02\x00\x01\x00" ++
        "\x00\x00\x00\x00";
    try std.testing.expectError(
        error.InvalidSemanticTag,
        classifyBuffer(std.testing.allocator, oversized_long_photometric),
    );

    const malformed_dng_version = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x12\xc6\x02\x00\x04\x00\x00\x00bad\x00" ++
        "\x00\x00\x00\x00";
    try std.testing.expectError(
        error.InvalidSemanticTag,
        classifyBuffer(std.testing.allocator, malformed_dng_version),
    );
}

test "uses a bounded prefix of long TIFF ASCII vendor values" {
    const long_make_value = "Canon " ++
        "AAAAAAAAAAAAAAAA" ++ "AAAAAAAAAAAAAAAA" ++ "AAAAAAAAAAAAAAAA" ++
        "AAAAAAAAAAAAAAAA" ++ "AAAAAAAAAAAAAAAA" ++ "AAAAAAAAAAAAAAAA" ++
        "AAAAAAAAAAAAAAAA" ++ "AAAAAAAAAA" ++ "\x00";
    comptime std.debug.assert(long_make_value.len == 129);
    const long_make_cr2 = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x03\x00" ++
        "\x06\x01\x03\x00\x01\x00\x00\x00\x23\x80\x00\x00" ++
        "\x0f\x01\x02\x00\x81\x00\x00\x00\x32\x00\x00\x00" ++
        "\x7c\x92\x07\x00\x01\x00\x00\x00\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++ long_make_value;

    try std.testing.expectEqual(
        classification.Format.cr2,
        try classifyBuffer(std.testing.allocator, long_make_cr2),
    );
}

test "IFD discovery deduplicates purposes and enforces one unique-offset limit" {
    var empty_handle = tiffz.source.BufferHandle.init("");
    var accumulator: EvidenceAccumulator = .{
        .allocator = std.testing.allocator,
        .source = tiffz.Source.fromBuffer(&empty_handle),
        .endian = .little,
        .offset_width = .classic,
        .limits = .{ .max_ifds = 2 },
    };
    defer accumulator.deinit();

    try accumulator.enqueue(100, .image);
    try accumulator.enqueue(100, .image);
    try accumulator.enqueue(100, .metadata);
    try accumulator.enqueue(200, .image);

    try std.testing.expectEqual(@as(usize, 2), accumulator.offset_states.count());
    try std.testing.expectEqual(@as(usize, 3), accumulator.pending.items.len);
    try std.testing.expectError(error.LimitExceededIfdCount, accumulator.enqueue(300, .image));
}

test "validates semantic tags in every linked directory" {
    const valid_then_malformed_dng = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x12\xc6\x01\x00\x04\x00\x00\x00\x01\x04\x00\x00" ++
        "\x1a\x00\x00\x00" ++
        "\x01\x00" ++
        "\x12\xc6\x02\x00\x04\x00\x00\x00bad\x00" ++
        "\x00\x00\x00\x00";

    try std.testing.expectError(
        error.InvalidSemanticTag,
        classifyBuffer(std.testing.allocator, valid_then_malformed_dng),
    );
}

test "cleans up when rawz worklist allocation fails" {
    var empty_handle = tiffz.source.BufferHandle.init("");
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{
        .fail_index = 0,
    });
    var accumulator: EvidenceAccumulator = .{
        .allocator = failing.allocator(),
        .source = tiffz.Source.fromBuffer(&empty_handle),
        .endian = .little,
        .offset_width = .classic,
        .limits = .{},
    };
    defer accumulator.deinit();

    try std.testing.expectError(error.OutOfMemory, accumulator.enqueue(100, .image));
}
