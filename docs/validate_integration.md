# Acyclic TIFF, RAW, and JPEG integration

## Decision

Validate owns orchestration. The static dependency graph remains:

```text
Validate -> rawz -> tiffz -> jpegz
         -> tiffz
         -> jpegz
```

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

rawz directly imports only tiffz, but tiffz currently exports one full Zig
module containing parser and codec imports. Its build graph pulls in zlib,
jpegz, zstdz, and lercz even for rawz's classification-only path. The desired
first-party-only production closure therefore does not pass yet.

tiffz should expose a parser-only module, for example `tiffz-parser`, containing
header, source, limits, IFD, tag, and decoder traversal needed to produce
semantic facts without compression codecs. rawz can then pin that module.
Tests and the full tiffz product may continue using the complete module.
