# Acyclic TIFF, RAW, and JPEG integration

## Decision

Validate owns orchestration. The static dependency graph remains:

```text
Validate -> rawz -> tiffz-parser
         -> tiffz
         -> jpegz
```

The `rawz` build resolves one exact tiffz package instance and injects its
named `tiffz-parser` module into every rawz compilation root. Validate should
inject that same dependency instance when it composes rawz and full tiffz, so
the coordinator cannot silently compile two parser versions.

`tiffz` must never import `rawz`. A direct reverse edge would create the
`tiffz <-> rawz` cycle that Peter's requested TIFF/RAW sequence exposed.

## Runtime sequence

1. Validate gives tiffz a bounded source view and receives standards-based
   TIFF facts and findings.
2. Validate gives those facts, plus vendor-private byte ranges, to rawz.
3. rawz classifies and checks only vendor-private RAW semantics. DNG remains
   owned by tiffz because it is a public TIFF/EP profile.
4. Validate routes JPEG-family payloads to jpegz when tiffz has not already
   validated them.
5. Validate merges findings and renders one product verdict.

This higher-level coordinator is simpler than making tiffz aware of every
camera vendor. If a future streaming path requires tiffz to dispatch private
payloads while it parses, Validate may inject a callback registry at runtime.
The registry must be an interface owned below neither package, and tiffz must
remain buildable with an empty registry.

## Offset contract

Embedded parsing uses a declared view `[host_base, host_base + view_len)`.
Parser offsets stay view-relative. The coordinator derives host offsets with a
checked addition of `host_base + view_offset`; overflow or a range beyond the
host source is an invalid argument. `rawz.tiff_adapter.classifySubrange` proves
the bounded-view behavior without copying and rejects both overflow and an
oversized declared range.

Future structured findings need both fields:

- `view_offset`: byte offset inside the bounded TIFF or private RAW payload.
- `host_offset`: checked translation into the top-level file, plus an
  exact/inexact flag when a parser can identify only a containing range.

The current classification API returns no findings, so it makes no offset
claim beyond the tested bounded view.

## Production closure gate

rawz pins tiffz commit `c57166db87132742c7591c34161c5549133bd09a` and
imports its `tiffz-parser` module. The named module contains the header, source,
limits, IFD, tag, and decoder traversal surface without compression codecs.

The blocking release check verifies the verbose Zig compiler graph maps the
sole local `tiffz` import to `src/parser.zig`. It also inspects ELF or Mach-O
load metadata and rejects codec paths. Nix independently rejects zlib,
OpenJPEG, libjpeg, libjxl, zstd, and lerc as direct references or transitive
runtime requisites. Release artifacts are stripped so build-tool source paths
cannot pull Zig's own codec closure into the shipped output.
