//! rawz — cleanroom camera RAW parsing and validation.
//!
//! Scope: PARSING and ERROR REPORTING only. Explicitly NOT demosaicing or
//! colour science — that is darktable/RawTherapee territory and the obvious
//! way a focused parser becomes a bottomless project.
//!
//! Layering: rawz sits ON TOP OF tiffz. Most RAW formats (CR2/NEF/ARW/ORF/PEF)
//! are TIFF containers, so tiffz parses the container and rawz interprets RAW
//! semantics. See tiffz/docs/tiff_raw_boundary.md for the full boundary.
//!
//! Pure Zig, no I/O. All I/O belongs in the C CLI.

const std = @import("std");
const tiffz = @import("tiffz");

pub const classification = @import("classification.zig");
pub const capabilities = @import("capabilities.zig");
pub const pef_decoder = @import("pef_decoder.zig");
pub const tiff_adapter = @import("tiff_adapter.zig");

// ── C FFI exports ───────────────────────────────────────────────────────

/// Append-only C ABI status values. `ok` is zero for conventional C tests.
pub const RawzStatus = enum(c_int) {
    ok = 0,
    invalid_argument = 1,
    malformed_tiff = 2,
    invalid_semantic_tag = 3,
    limit_exceeded = 4,
    out_of_memory = 5,
    io = 6,
    unsupported_tiff_feature = 7,
    internal = 8,
};

/// Append-only C ABI format values. `unknown` is reserved for uninitialized
/// output; every successful classification returns a more specific value.
pub const RawzFormat = enum(c_int) {
    unknown = 0,
    tiff = 1,
    dng = 2,
    cr2 = 3,
    nef = 4,
    arw = 5,
    orf = 6,
    pef = 7,
    three_fr = 8,
    rw2 = 9,
    raw_unknown = 10,
};

export fn rawz_version() [*:0]const u8 {
    return "0.1.0";
}

/// Classify one caller-owned in-memory buffer. The input is borrowed for the
/// duration of the call; `out_format` is written only when status is `ok`.
export fn rawz_classify_buffer(
    data: ?[*]const u8,
    len: usize,
    out_format: ?*RawzFormat,
) RawzStatus {
    const input = data orelse return .invalid_argument;
    const output = out_format orelse return .invalid_argument;
    const format = tiff_adapter.classifyBuffer(std.heap.smp_allocator, input[0..len]) catch |err| {
        return statusFromError(err);
    };
    output.* = formatForC(format);
    return .ok;
}

fn formatForC(format: classification.Format) RawzFormat {
    return switch (format) {
        .tiff => .tiff,
        .dng => .dng,
        .cr2 => .cr2,
        .nef => .nef,
        .arw => .arw,
        .orf => .orf,
        .pef => .pef,
        .three_fr => .three_fr,
        .rw2 => .rw2,
        .raw_unknown => .raw_unknown,
    };
}

fn statusFromError(err: tiff_adapter.Error) RawzStatus {
    return switch (err) {
        error.InvalidArgument => .invalid_argument,
        error.MalformedTiff => .malformed_tiff,
        error.InvalidSemanticTag => .invalid_semantic_tag,
        error.LimitExceeded => .limit_exceeded,
        error.OutOfMemory => .out_of_memory,
        error.Io => .io,
        error.UnsupportedTiffFeature => .unsupported_tiff_feature,
        error.Internal => .internal,
    };
}

// ── Tests ───────────────────────────────────────────────────────────────

test "version is a non-empty string" {
    const v = std.mem.span(rawz_version());
    try std.testing.expect(v.len > 0);
    try std.testing.expectEqualStrings("0.1.0", v);
}

test "C ABI classifies a DNG with stable numeric values" {
    const dng = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x12\xc6\x01\x00\x04\x00\x00\x00\x01\x04\x00\x00" ++
        "\x00\x00\x00\x00";
    var format: RawzFormat = .unknown;

    try std.testing.expectEqual(
        RawzStatus.ok,
        rawz_classify_buffer(dng.ptr, dng.len, &format),
    );
    try std.testing.expectEqual(RawzFormat.dng, format);
    try std.testing.expectEqual(@as(c_int, 0), @intFromEnum(RawzStatus.ok));
    try std.testing.expectEqual(@as(c_int, 2), @intFromEnum(RawzFormat.dng));
}

test "C ABI validates pointers and maps classification errors" {
    var format: RawzFormat = .unknown;
    try std.testing.expectEqual(
        RawzStatus.invalid_argument,
        rawz_classify_buffer(null, 0, &format),
    );
    try std.testing.expectEqual(
        RawzStatus.invalid_argument,
        rawz_classify_buffer("II".ptr, 2, null),
    );
    try std.testing.expectEqual(
        RawzStatus.malformed_tiff,
        rawz_classify_buffer("II".ptr, 2, &format),
    );

    const malformed_photometric = "II\x2a\x00\x08\x00\x00\x00" ++
        "\x01\x00" ++
        "\x06\x01\x02\x00\x01\x00\x00\x00\x02\x00\x00\x00" ++
        "\x00\x00\x00\x00";
    try std.testing.expectEqual(
        RawzStatus.invalid_semantic_tag,
        rawz_classify_buffer(
            malformed_photometric.ptr,
            malformed_photometric.len,
            &format,
        ),
    );
    try std.testing.expectEqual(RawzFormat.unknown, format);
}

test "every Zig format and error has one stable C mapping" {
    const format_cases = [_]struct { classification.Format, RawzFormat }{
        .{ .tiff, .tiff },
        .{ .dng, .dng },
        .{ .cr2, .cr2 },
        .{ .nef, .nef },
        .{ .arw, .arw },
        .{ .orf, .orf },
        .{ .pef, .pef },
        .{ .three_fr, .three_fr },
        .{ .rw2, .rw2 },
        .{ .raw_unknown, .raw_unknown },
    };
    for (format_cases) |case| try std.testing.expectEqual(case[1], formatForC(case[0]));

    const status_cases = [_]struct { tiff_adapter.Error, RawzStatus }{
        .{ error.InvalidArgument, .invalid_argument },
        .{ error.MalformedTiff, .malformed_tiff },
        .{ error.InvalidSemanticTag, .invalid_semantic_tag },
        .{ error.LimitExceeded, .limit_exceeded },
        .{ error.OutOfMemory, .out_of_memory },
        .{ error.Io, .io },
        .{ error.UnsupportedTiffFeature, .unsupported_tiff_feature },
        .{ error.Internal, .internal },
    };
    for (status_cases) |case| try std.testing.expectEqual(case[1], statusFromError(case[0]));
}

test "public parsing modules are available through rawz" {
    _ = tiffz;
    _ = classification;
    _ = capabilities;
    _ = tiff_adapter;
}

test "PEF decoder is available through the public rawz module" {
    const complete = [_]u8{0} ** 12;

    try std.testing.expectEqual(
        null,
        pef_decoder.validatePefPacked12(&complete, 4, 2),
    );
}
