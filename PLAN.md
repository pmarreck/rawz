# rawz — Plan

## In Progress

- [ ] **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT).
  - [x] Repinned tiffz to `b3b8871ab17defa209f8ce368900a43eb6540a50`
    and regenerated both Zig and Nix dependency hashes (2026-08-05 00:21 EDT).
  - [x] Proved the old pin rejected a valid BigTIFF IFD8 SubIFD, then made the
    same 28-case suite pass on the new pin (2026-08-05 00:18 EDT).
  - [x] Added a checked, bounded embedded-source classifier and pinned the new
    dependency error mapping inside rawz's stable error domain (2026-08-05
    00:23 EDT).
  - [x] Published and machine-checked the professional-family matrix in
    `src/CAPABILITIES.json`, including honest unsupported states (2026-08-05
    00:23 EDT).
  - [x] Added deterministic PEF Huffman known-good/known-bad and
    sniper/bolter/shotgun measurements whose declared JSON values are checked
    against the executable measurement (2026-08-05 00:24 EDT).
  - [x] Documented the higher-level Validate coordinator and rejected a direct
    `tiffz <-> rawz` dependency cycle (2026-08-05 00:25 EDT).
  - [ ] Split a parser-only tiffz module before claiming the requested
    first-party-only production closure. The current full module includes
    zlib, jpegz, zstdz, and lercz even on rawz's classification path.
  - [ ] Pass canonical local, exact Nix, pushed-commit, and terminal Mechatron
    gates for this unit.

- [ ] **M3 — migrate `pef_decoder.zig` out of validate** (Pentax PEF). It lives
  in the consumer app purely by accident of history.
  - [x] Sequencing constraint lifted by Peter via Einstein (2026-07-31 13:58
    EDT): validate is not mid-release, so the migration may proceed after M2.
  - [ ] Coordinate the validate-side change through its agent with the moved
    path, rawz import path, and exact SHA to pin.
  - [ ] Keep both repositories green and stage only explicit paths; never sweep
    other agents' concurrent work into a commit.
  - [x] Repin tiffz from vulnerable `d03c9d2` to at least `b3b8871a`, which
    includes the `Ifd.parse` allocation-failure double-free fix (`2a431856`)
    and BigTIFF `IFD8` support. Regenerate dependency hashes and pass the full
    rawz gates before validate pins M3.
    - Curiosity poke: the intervening commits add bounded subranges and a
      distinct embedded-JPEG error, so verify rawz's adapter error mapping and
      offset semantics rather than treating this as a hash-only repin.
  - [x] Reproduce validate's packed-12 behavior in rawz before moving code, and
    add the missing maximum-dimension overflow case.
  - [x] Give rawz a focused in-memory MSB bit reader for the PEF Huffman path;
    validate's shared media reader stays with its other consumers.
  - [ ] Preserve the existing public names so validate's change is an import
    replacement, then publish the exact rawz SHA for its agent to pin.
  - [ ] Correct validate's dispatch contract: TIFF compression 32773 is
    PackBits, so tiffz must decompress it before `validatePefPacked12`; Pentax's
    private Huffman compression is 65535.
  - [x] Curiosity poke: malformed Huffman tables and unsupported bit depths
    must return typed errors without a trap or an unbounded decode loop.
  - [x] Rerun all 13 deep-review dimensions sequentially after the prior OOM;
    fix every functional, coverage, complexity, clarity, and error-domain
    finding before publishing the rawz migration commit.
  - [x] Pass direct sandboxed build/test checks and canonical `./test` for the
    rawz-side migration.

## Next

- [ ] **M4 — detection research (the product payoff).** Test the two hypotheses
  in `PROJECT_OVERVIEW.md` against real data:
  - [ ] **Compression-variant split.** Re-measure corruption detection per
    *compression variant*, never per extension. NEF/ARW/CR2 ship compressed AND
    uncompressed; entropy-coded data desynchronizes on a bit flip and should be
    detectable like JPEG. A uniform "RAW ≈ 0%" strongly suggests uncompressed
    fixtures.
  - [ ] **Bit-depth headroom check.** 12/14-bit samples in 16-bit words ⇒ top
    2–4 bits zero by construction. Assert across the sample array. Exact, cheap,
    no checksum needed. Add white/black-level bounds from file metadata.
  - [ ] Bayer neighbour statistics — only if the above fall short. Statistical,
    so it needs a specificity corpus (legitimate high-ISO noise must NOT trip).
- [ ] **M5 — corpus.** `raw.pixls.us` (CC0, purpose-built for RAW software
  testing) is the primary source — **verify license terms at fetch time**.
  Cover the axes that matter: compression variant, bit depth, CFA vs X-Trans.
  darktable **cannot generate** RAW, only read it.
- [ ] **M6 — differential oracle.** darktable 5.6.0 is installed (79 makers /
  1,389 models via rawspeed). Mutate known-good RAW; compare rawz's verdict to
  rawspeed's decode. *rawspeed rejects + we pass* = a gap worth closing. Both
  pass = genuinely undetectable, and Mecha RotShield parity is the honest
  answer. **Run it, never read it** — cleanroom.
- [ ] CR3 support (ISO BMFF container, not TIFF).

## Deferred / explicitly not doing

- Demosaicing, colour science, rendering, conversion. Out of scope for v1; see
  `PROJECT_OVERVIEW.md`.
- Moving `dng.zig` out of tiffz. It is correctly placed — DNG is a public
  TIFF/EP standard.

## Completed

- [x] **M2 — format classification, as a set classifier** (2026-08-03 11:19
  EDT). Answers "is this a photographic TIFF or camera RAW, and which vendor?"
  from tiffz-reported semantic evidence.
  - [x] Separated the allocation-free `Evidence` policy from TIFF byte/tag
    decoding in the tiffz adapter.
  - [x] Classified CR2/NEF/ARW/ORF/PEF/DNG/3FR/RW2 sensitivity and photographic
    TIFF specificity cases in one table, including the `pc260001.tif` ORF trap.
  - [x] Normalized vendor ASCII without allocating and kept bounded prefixes of
    long Make/Model values.
  - [x] Traversed linked, Exif, nested, repeated, and cyclic IFD references with
    one deduplicated, aggregate-limited offset set.
  - [x] Reran all 13 OOM-interrupted review dimensions sequentially and recorded
    every disposition in `CODE_REVIEW.md`.
  - [x] Published stable append-only C format/status enums and
    `rawz_classify_buffer`, tested through Zig and a compiled C consumer.
  - [x] Passed direct sandboxed build/test checks and canonical `./test`.
- [x] **Mechatron Prime CI activated** (2026-08-03 11:22 EDT).
  - [x] Published M2 as `c79d729668668aa66e405a3e88bf1523794b220e` and
    independently verified `origin/yolo` matched.
  - [x] Mechatron built the manifest-selected package and test targets for that
    exact commit and reported terminal `success` in 20 seconds.
- [x] **M1 — added tiffz as a dependency** (2026-07-31 13:47 EDT).
  - [x] Pinned tiffz `d03c9d2` and raised the package minimum to Zig 0.16.0.
  - [x] Proved the import contract red before wiring the module, then green.
  - [x] Added zlib to native and sandbox environments and forwarded explicit
    paths for Darwin builds.
  - [x] Regenerated the non-empty dependency FOD hash and proved its offline
    cache with both canonical `./test` checks.
- [x] **M0 — scaffold verified green** (2026-07-31 13:42 EDT).
  - [x] Confirmed `.fingerprint = 0x79c9610f3a3708b0` was already committed in
    the untouched scaffold (`038340c`).
  - [x] `./test` passed both the sandboxed ReleaseSafe test check and the
    ReleaseFast package build before any project-code change.
