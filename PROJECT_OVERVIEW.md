# rawz — Project Overview

## What this is

A **cleanroom camera RAW parsing and validation library** in Zig, with a C FFI
and a C CLI that dogfoods it. Part of the Mecha fleet, feeding **Mecha Validate**.

## Scope

**In scope (v1):** parsing and **error reporting**. Identify the format,
walk the container, interpret RAW semantics, and report *specific, actionable*
findings when something is malformed or corrupt.

**Explicitly OUT of scope:** demosaicing, colour science, rendering,
conversion. That is darktable/RawTherapee territory — years of work, and the
obvious way a focused parser becomes a bottomless project. Conversion may
become a *separate* product later; it is not this library's v1.

## The boundary with tiffz (read this first)

Full rationale: **`~/Code/tiffz/docs/tiff_raw_boundary.md`**. Summary:

> **Standardized, publicly specified TIFF profiles → tiffz.**
> **Proprietary, reverse-engineered vendor formats → rawz.**
> **rawz depends on tiffz for container parsing.**

Most RAW formats **are TIFF containers** — CR2, NEF, ARW, ORF, PEF, 3FR are all
TIFF-based; DNG is TIFF/EP. So rawz does *not* reimplement TIFF. tiffz reports
IFDs/tags; rawz interprets RAW meaning.

- **`dng.zig` stays in tiffz.** DNG is a public Adobe/TIFF-EP standard and
  belongs with the standards-based container library. Do not move it.
- **CR3 is not TIFF** — it is ISO BMFF (MP4-style boxes) and needs its own
  container parser inside rawz.

## Terminology

| Term | Meaning |
|---|---|
| **CFA** | Colour Filter Array — the sensor mosaic (Bayer, X-Trans). TIFF tag `PhotometricInterpretation = 32803` marks CFA data. |
| **IFD** | Image File Directory — TIFF's tag/metadata block. |
| **MakerNote** | Vendor-private metadata blob inside EXIF; per-vendor, per-model, reverse-engineered. |
| **Bit depth vs storage width** | Sensors are typically 12- or 14-bit but stored in 16-bit words — leaving guaranteed-zero high bits. See "detection ideas" below. |
| **Black / white level** | Per-file declared valid sample range; samples outside it are invalid *by the file's own metadata*. |
| **Compression variant** | The same extension ships compressed AND uncompressed (NEF, ARW, CR2). Corruption detectability differs **fundamentally** between them. |

## Why it exists (the product argument)

Mecha Validate currently reports **~0% corruption detection on RAW**, and the
working explanation was "fundamental — no checksum, sensor data dominates the
file." That is **partly true and partly a measurement artifact**, and untangling
it needs a library that owns RAW semantics rather than a 137-line wrapper.

Two concrete detection avenues to test (hypotheses, not claims):

1. **Compressed RAW is entropy-coded**, so a bit flip desynchronizes the stream
   — it should be detectable like JPEG, not like BMP. If the current 0% comes
   from *uncompressed* fixtures, that is a fixture-selection artifact.
2. **Bit-depth headroom** — 12/14-bit samples in 16-bit words means the top
   2–4 bits are zero *by construction*. Random corruption violates that with
   near-certainty across a few thousand samples. Exact, cheap, needs no
   checksum. Plus white/black-level bounds from the file's own metadata.

## Architecture

```
validate / any consumer ──► C FFI (include/rawz.h) ──► Zig core (src/, no I/O)
                                                            │
                                                            └──► tiffz (container)
```

- Core is **pure Zig, no I/O**. All I/O lives in the C CLI.
- The CLI is **C on purpose**: C *cannot* `@import` a Zig module, so bypassing
  the FFI is inexpressible rather than merely forbidden.
- Sibling-Zig exception applies: because the C CLI dogfoods the FFI, Zig
  consumers (validate) may import the `rawz` module directly.

## Licensing posture

validate currently links **LibRaw** (CDDL-1.0 elected) as an *oracle*, not as an
implementation — the Zig cleanroom lineage is intact. A mature rawz can
eventually let validate drop that dependency, removing a license obligation from
a commercial product. Same motivation as cleanroom `z7z` / `jpegz`.

**Do not read or port LibRaw / rawspeed source.** They are differential
*oracles* only — run them, compare outputs, never copy. Cleanroom means derived
from public specs and observed behaviour.
