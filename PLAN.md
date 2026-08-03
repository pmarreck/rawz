# rawz — Plan

## In Progress

- [ ] **M3 — migrate `pef_decoder.zig` out of validate** (Pentax PEF). It lives
  in the consumer app purely by accident of history.
  - [ ] Sequencing constraint lifted by Peter via Einstein (2026-07-31 13:58
    EDT): validate is not mid-release, so the migration may proceed after M2.
  - [ ] Coordinate the validate-side change through its agent with the moved
    path, rawz import path, and exact SHA to pin.
  - [ ] Keep both repositories green and stage only explicit paths; never sweep
    other agents' concurrent work into a commit.

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
- [ ] Mechatron Prime CI: land Einstein's `.mechatron-prime/targets` only with
  the green M2 commit.
  - [ ] Stage every new source explicitly before Nix validation; Git-backed
    flakes cannot see untracked files.
  - [ ] Directly build `checks.x86_64-linux.build` and
    `checks.x86_64-linux.test`, then run canonical `./test`.
  - [ ] Push `yolo`, independently verify `origin/yolo == HEAD`, and tell
    Einstein the exact SHA so he can provision the webhook with Peter's sudo.
  - [ ] Verify that exact commit reaches a terminal `PASSING` result; HTTP 200
    delivery alone is not queue/acceptance evidence.

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
