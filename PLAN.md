# rawz — Plan

## In Progress

- [ ] **M1 — add tiffz as a dependency.** rawz parses RAW *semantics*; tiffz
  parses the container. Do NOT reimplement TIFF.
  - [ ] Add tiffz to `build.zig.zon` (pin a SHA).
  - [ ] Flip `hasDeps = true` in `flake.nix` and regenerate `zigDepsHash`
    (set to `pkgs.lib.fakeHash`, `nix build`, take the printed hash).
  - [ ] Curiosity poke: an **empty-tree FOD hash usually means the builder
    could not fetch** — if the hash looks suspiciously constant, that is the
    failure, not success.
- [ ] **M2 — format classification, as a set classifier.** Answer "is this a
  photographic TIFF or camera RAW, and which vendor?" from tiffz-reported tags:
  `PhotometricInterpretation == 32803` (CFA), `DNGVersion`, `Make`/`Model`,
  `NewSubfileType`/SubIFD layout.
  - [ ] Test as a **classifier over sets** (sensitivity + specificity), not a
    predicate over examples. Must include the real-world trap: `pc260001.tif`
    is an **ORF**, not a TIFF — validate's sweep published 0/0/0 for the wrong
    format because of exactly this.
- [ ] **M3 — migrate `pef_decoder.zig` out of validate** (Pentax PEF). It lives
  in the consumer app purely by accident of history.
  - [ ] **Sequencing constraint: do NOT land this while validate is mid-release.**
    Changing validate's dependency graph during a release push is not worth it.
    Build new work in rawz first; migrate when Peter says validate has shipped.

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
- [ ] Mechatron Prime CI: invoke the `mechatron-ci` skill once flake outputs are
  real and locally verified.

## Deferred / explicitly not doing

- Demosaicing, colour science, rendering, conversion. Out of scope for v1; see
  `PROJECT_OVERVIEW.md`.
- Moving `dng.zig` out of tiffz. It is correctly placed — DNG is a public
  TIFF/EP standard.

## Completed

- [x] **M0 — scaffold verified green** (2026-07-31 13:42 EDT).
  - [x] Confirmed `.fingerprint = 0x79c9610f3a3708b0` was already committed in
    the untouched scaffold (`038340c`).
  - [x] `./test` passed both the sandboxed ReleaseSafe test check and the
    ReleaseFast package build before any project-code change.
