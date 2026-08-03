//! Pure camera-RAW format classification from TIFF semantic evidence.
//!
//! Byte decoding and IFD traversal belong to the tiffz adapter; this module
//! owns only the policy that distinguishes photographic TIFF from camera RAW.

const std = @import("std");

pub const Format = enum {
    tiff,
    dng,
    cr2,
    nef,
    arw,
    orf,
    pef,
    three_fr,
    rw2,
    raw_unknown,
};

pub const IfdLocation = enum {
    primary,
    child,
};

pub const IfdEvidence = struct {
    location: IfdLocation = .primary,
    photometric: ?u16 = null,
    new_subfile_type: ?u32 = null,
};

pub const Evidence = struct {
    make: ?[]const u8 = null,
    model: ?[]const u8 = null,
    has_maker_note: bool = false,
    has_dng_version: bool = false,
    ifds: []const IfdEvidence = &.{},
};

const cfa_photometric: u16 = 32803;

const Vendor = enum {
    canon,
    nikon,
    sony,
    olympus,
    pentax,
    hasselblad,
    panasonic,
};

/// Distinguish photographic TIFF from vendor RAW without trusting extensions.
/// DNG wins by its public tag; proprietary formats require RAW layout evidence
/// plus a matching MakerNote/vendor identity pair.
pub fn classify(evidence: Evidence) Format {
    if (evidence.has_dng_version) return .dng;
    if (!hasRawLayout(evidence.ifds)) return .tiff;
    if (!evidence.has_maker_note) return .raw_unknown;

    const vendor = identifyVendor(evidence.make) orelse identifyVendor(evidence.model) orelse
        return .raw_unknown;
    return switch (vendor) {
        .canon => .cr2,
        .nikon => .nef,
        .sony => .arw,
        .olympus => .orf,
        .pentax => .pef,
        .hasselblad => .three_fr,
        .panasonic => .rw2,
    };
}

/// Recognize either an explicit CFA image or the common RAW arrangement of a
/// reduced primary preview followed by a full-resolution sensor SubIFD.
fn hasRawLayout(ifds: []const IfdEvidence) bool {
    var has_reduced_primary = false;
    var has_full_sub_ifd = false;
    for (ifds) |ifd| {
        if (ifd.photometric == cfa_photometric) return true;
        const new_subfile_type = ifd.new_subfile_type orelse continue;
        const is_reduced = new_subfile_type & 1 != 0;
        switch (ifd.location) {
            .primary => has_reduced_primary = has_reduced_primary or is_reduced,
            .child => {
                const lacks_rendered_photometric = ifd.photometric == null;
                has_full_sub_ifd = has_full_sub_ifd or (!is_reduced and lacks_rendered_photometric);
            },
        }
    }
    return has_reduced_primary and has_full_sub_ifd;
}

/// Map TIFF Make/Model strings without allocating, tolerating ASCII case and
/// the NUL/space padding commonly present in fixed-width metadata fields.
fn identifyVendor(maybe_text: ?[]const u8) ?Vendor {
    const text = trimTiffAscii(maybe_text orelse return null);
    const names = [_]struct { prefix: []const u8, vendor: Vendor }{
        .{ .prefix = "canon", .vendor = .canon },
        .{ .prefix = "nikon", .vendor = .nikon },
        .{ .prefix = "sony", .vendor = .sony },
        .{ .prefix = "olympus", .vendor = .olympus },
        .{ .prefix = "om digital", .vendor = .olympus },
        .{ .prefix = "pentax", .vendor = .pentax },
        .{ .prefix = "aoc", .vendor = .pentax },
        .{ .prefix = "ricoh", .vendor = .pentax },
        .{ .prefix = "hasselblad", .vendor = .hasselblad },
        .{ .prefix = "panasonic", .vendor = .panasonic },
    };
    for (names) |name| {
        if (matchesVendorName(text, name.prefix)) return name.vendor;
    }
    return null;
}

fn matchesVendorName(text: []const u8, prefix: []const u8) bool {
    if (text.len < prefix.len or !std.ascii.eqlIgnoreCase(text[0..prefix.len], prefix)) return false;
    return text.len == prefix.len or std.ascii.isWhitespace(text[prefix.len]);
}

fn trimTiffAscii(text: []const u8) []const u8 {
    return std.mem.trim(u8, std.mem.sliceTo(text, 0), &std.ascii.whitespace);
}

test "classifies the RAW sensitivity and TIFF specificity corpora as one set" {
    const Case = struct {
        name: []const u8,
        evidence: Evidence,
        expected: Format,
    };
    const cases = [_]Case{
        .{
            .name = "pc260001.tif is ORF despite its TIFF extension",
            .evidence = .{
                .make = "OLYMPUS IMAGING CORP.\x00",
                .model = "E-1\x00",
                .has_maker_note = true,
                .ifds = &.{
                    .{ .photometric = 2, .new_subfile_type = 1 },
                    .{ .location = .child, .photometric = 32803, .new_subfile_type = 0 },
                },
            },
            .expected = .orf,
        },
        .{
            .name = "Canon CR2 via reduced preview plus full sensor SubIFD",
            .evidence = .{
                .make = "Canon",
                .model = "Canon EOS 5D Mark IV",
                .has_maker_note = true,
                .ifds = &.{
                    .{ .photometric = 2, .new_subfile_type = 1 },
                    .{ .location = .child, .new_subfile_type = 0 },
                },
            },
            .expected = .cr2,
        },
        .{
            .name = "Nikon NEF",
            .evidence = .{
                .make = "NIKON CORPORATION",
                .model = "NIKON D850",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .nef,
        },
        .{
            .name = "Sony ARW with lowercase padded make",
            .evidence = .{
                .make = "sony\x00   ",
                .model = "ILCE-7M4",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .arw,
        },
        .{
            .name = "Sony ARW with leading and trailing space padding",
            .evidence = .{
                .make = "  sony   ",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .arw,
        },
        .{
            .name = "Pentax PEF",
            .evidence = .{
                .make = "PENTAX",
                .model = "PENTAX K-1",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .pef,
        },
        .{
            .name = "Hasselblad 3FR",
            .evidence = .{
                .make = "Hasselblad",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .three_fr,
        },
        .{
            .name = "Panasonic RW2",
            .evidence = .{
                .make = "Panasonic",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .rw2,
        },
        .{
            .name = "OM Digital Solutions ORF alias",
            .evidence = .{
                .make = "OM Digital Solutions",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .orf,
        },
        .{
            .name = "AOC PEF alias",
            .evidence = .{
                .make = "AOC",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .pef,
        },
        .{
            .name = "Ricoh PEF alias",
            .evidence = .{
                .make = "RICOH IMAGING COMPANY, LTD.",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .pef,
        },
        .{
            .name = "model identifies vendor when Make is absent",
            .evidence = .{
                .model = "NIKON D850",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .nef,
        },
        .{
            .name = "DNGVersion is authoritative",
            .evidence = .{
                .make = "Leica Camera AG",
                .has_dng_version = true,
            },
            .expected = .dng,
        },
        .{
            .name = "ordinary RGB TIFF",
            .evidence = .{ .ifds = &.{.{ .photometric = 2 }} },
            .expected = .tiff,
        },
        .{
            .name = "camera-authored RGB TIFF with MakerNote",
            .evidence = .{
                .make = "Canon",
                .model = "Canon EOS R5",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 2, .new_subfile_type = 0 }},
            },
            .expected = .tiff,
        },
        .{
            .name = "RGB TIFF pyramid is not a sensor layout",
            .evidence = .{
                .make = "Canon",
                .has_maker_note = true,
                .ifds = &.{
                    .{ .photometric = 2, .new_subfile_type = 0 },
                    .{ .location = .child, .photometric = 2, .new_subfile_type = 1 },
                },
            },
            .expected = .tiff,
        },
        .{
            .name = "reduced preview plus full RGB SubIFD is still TIFF",
            .evidence = .{
                .make = "Canon",
                .has_maker_note = true,
                .ifds = &.{
                    .{ .photometric = 2, .new_subfile_type = 1 },
                    .{ .location = .child, .photometric = 2, .new_subfile_type = 0 },
                },
            },
            .expected = .tiff,
        },
        .{
            .name = "unknown CFA vendor is not guessed",
            .evidence = .{ .ifds = &.{.{ .photometric = 32803 }} },
            .expected = .raw_unknown,
        },
        .{
            .name = "CFA plus Canon name without MakerNote is not called CR2",
            .evidence = .{
                .make = "Canon",
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .raw_unknown,
        },
        .{
            .name = "vendor prefixes inside longer names are not trusted",
            .evidence = .{
                .make = "Canonical Labs",
                .has_maker_note = true,
                .ifds = &.{.{ .photometric = 32803 }},
            },
            .expected = .raw_unknown,
        },
    };

    for (cases) |case| {
        const actual = classify(case.evidence);
        std.testing.expectEqual(case.expected, actual) catch |err| {
            std.debug.print("classifier case failed: {s}\n", .{case.name});
            return err;
        };
    }
}
