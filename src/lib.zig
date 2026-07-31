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

// ── C FFI exports ───────────────────────────────────────────────────────

export fn rawz_version() [*:0]const u8 {
	return "0.1.0";
}

// ── Tests ───────────────────────────────────────────────────────────────

test "version is a non-empty string" {
	const v = std.mem.span(rawz_version());
	try std.testing.expect(v.len > 0);
	try std.testing.expectEqualStrings("0.1.0", v);
}
