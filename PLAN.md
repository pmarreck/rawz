# PLAN

Completed work is retained in [`docs/PLAN_LOG.md`](docs/PLAN_LOG.md).

## In Progress

- [x] Update rawz to current tiffz and flake inputs; package heads were already current, nixpkgs advanced to `34ca302a`, the resolved graph and all gates passed, and Mechatron passed `f793ce6` in 54 seconds (done 2026-09-24 17:03 EDT; commits `662fca3`, `f793ce6`).

- [ ] **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT).
  - [ ] Deliver sensor-data checks Validate needs for full-depth RAW promotion, reporting each family by exact SHA and measured coverage (context: `docs/plan_context/sensor_data_checks.md`).
    - [x] Ship PEF syntax validation first: compression-aware 32773/65535 dispatch, bounded AOC MakerNote lookup, stable depth results with offsets, real 97/100 random-byte and 100/100 EOF coverage, exact-SHA Validate handoff, and terminal Mechatron pass (done 2026-09-24 20:10 EDT; `ef74184`).
    - [ ] Ship DNG/CR2/compressed-NEF sensor syntax validation and independent per-variant coverage.
      - [x] Ship the bounded CR2 raw-IFD lossless-JPEG locator with exact offsets and real CC0 evidence; strict validation is blocked on jpegz's two-component subsampled SOF3 support (done 2026-09-24 20:24 EDT).
      - [ ] Integrate DNG CFA compression 7 after tiffz delivers its jpegz-owned path.
      - [ ] Integrate CR2 after jpegz delivers Canon's two-component subsampled SOF3 path and tiffz repins it.
      - [ ] Implement Nikon Huffman for compressed NEF; the ratified matrix identifies this as proprietary entropy coding, not the DNG/CR2 lossless-JPEG seam.
        - [x] Ship a bounded NEF CFA SubIFD locator that combines contiguous strips and distinguishes uncompressed words from Nikon compression 34713 (done 2026-09-24 20:46 EDT).
        - [x] Ship Nikon version-0x46 lossless Huffman validation with bounded MakerNote table lookup, a real D300 baseline, 69/100 byte and 100/100 EOF detection, and a 100-mutation rawspeed differential run (done 2026-09-24 21:30 EDT).
    - [x] Ship uncompressed 12/14-bit word headroom and metadata-bound checks with stable offsets, a named missing-level reach reason, and real CC0 D300 evidence (done 2026-09-24 20:38 EDT).
    - [x] Keep every uncompressed-word path structural under Peter's 10% any-legal-byte ceiling, including streams with valid black/white levels (done 2026-09-24 20:52 EDT).
    - [ ] Ship Sony ARW, Fuji RAF, Olympus ORF, and Panasonic RW2 entropy syntax checks with per-variant coverage.
    - [ ] Add the ISO BMFF container before Canon CR3 CRX syntax validation and coverage.
  - [x] Documented the higher-level Validate coordinator and rejected a direct `tiffz <-> rawz` dependency cycle (2026-08-05 00:25 EDT).
  - [x] Adopt tiffz's parser-only module and prove the requested first-party-only production closure (2026-08-05 01:40 EDT).
    - [x] Repin exact terminal-green tiffz `c57166db87132742c7591c34161c5549133bd09a` and inject its `tiffz-parser` module exactly once. Curiosity poke: remove every obsolete zlib workaround rather than hiding a stale link edge.
    - [x] Add a blocking production-closure check over the parser import graph, exact compiler command, shipped ELF, and Nix store references. Curiosity poke: dynamic-section inspection alone misses static or debug-path Nix references.
    - [x] Preserve the published capability matrix and bounded PEF scorecard, changing only the now-proven closure status and evidence.
    - [x] Publish exact rawz repin evidence after canonical tests, build, exact Nix targets, and terminal Mechatron success for `01dcfea52ccf32f6d532ee18f0f6771101842992` in 80 seconds (2026-08-05 01:43 EDT).
  - [x] Passed canonical local, exact Nix, pushed-commit, and terminal Mechatron gates for `4940ab487bc9fb9930f026e9349d44ec056d5a7a`; Mechatron reported success in 3 seconds (2026-08-05 00:29 EDT).

## Next

- [ ] **M5 — corpus.** `raw.pixls.us` (CC0, purpose-built for RAW software testing) is the primary source — **verify license terms at fetch time**. Cover the axes that matter: compression variant, bit depth, CFA vs X-Trans. darktable **cannot generate** RAW, only read it.
- [ ] **M6 — differential oracle.** darktable 5.6.0 is installed (79 makers / 1,389 models via rawspeed). Mutate known-good RAW; compare rawz's verdict to rawspeed's decode. *rawspeed rejects + we pass* = a gap worth closing. Both pass = genuinely undetectable, and Mecha RotShield parity is the honest answer. **Run it, never read it** — cleanroom.
- [ ] CR3 support (ISO BMFF container, not TIFF).
