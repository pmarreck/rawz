# PLAN

Completed work is retained in [`docs/PLAN_LOG.md`](docs/PLAN_LOG.md).

## In Progress


- [x] Refresh every direct, transitive, and toolchain dependency pin to its upstream head, including tiffz `4e6d9c31`, nixpkgs `39ad350a`, flake-utils `11707dc2`, nix-systems `d36eeed1`, and Zig 0.16.0; regenerated hashes and the full local gate set pass (done 2026-10-08 21:33 EDT).
- [ ] Audit active mutation labels and migrate legacy dense `shotgun` usage to `nuke` without rewriting historical evidence.

- [ ] **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT).
  - [ ] Deliver sensor-data checks Validate needs for full-depth RAW promotion, reporting each family by exact SHA and measured coverage (context: `docs/plan_context/sensor_data_checks.md`).
	- [x] Inventory exact delivered RAW variants against MKTP's six criteria, then close one justified bounded sensor-path gap red-first or document the research/control boundary; preserve hashes, commands, controls, residuals, exact CI, and coordinator receipts (done 2026-10-10 00:49 EDT; `ba929f8`, Mechatron Prime PASS in 45s; context: `docs/mktp-research/raw-sensor-variants-2026-10-10.md`).
	- [x] Correct the PEF sample-work budget from a corruption failure to named structural reach with malformed, at-limit, and same-input over-budget controls; preserve the low-level append-only error ABI and exact delivery evidence (done 2026-10-10 01:08 EDT; `711b1fa`, Mechatron Prime PASS in 43s; context: `docs/mktp-research/raw-sensor-variants-2026-10-10.md`).
	- [ ] Correct Nikon CFA-IFD traversal budgets to named structural reach with a valid inclusive-cap traversal, the same fixture under a lower budget, and a malformed offset that remains a file defect; preserve exact local evidence under the publication hold (context: `docs/mktp-research/raw-sensor-variants-2026-10-10.md`).
    - [x] Ratify and deliver `Maximum Known Technically Possible` (`MKTP`) as the variant-scoped depth label for complete best-effort parsing whose remaining corruption blind spots are fundamental to the format (done 2026-09-26 15:15 EDT; durable Validate policy note delivered).
    - [x] Update Validate's coverage notes with each newly measured RAW corruption-detection gain, preserving independent-control provenance and structural/full caveats (done 2026-09-25 15:37 EDT; Validate `3dc478a2d`).
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

## Next

- [ ] **M5 — corpus.** `raw.pixls.us` (CC0, purpose-built for RAW software testing) is the primary source — **verify license terms at fetch time**. Cover the axes that matter: compression variant, bit depth, CFA vs X-Trans. darktable **cannot generate** RAW, only read it.
- [ ] **M6 — differential oracle.** darktable 5.6.0 is installed (79 makers / 1,389 models via rawspeed). Mutate known-good RAW; compare rawz's verdict to rawspeed's decode. *rawspeed rejects + we pass* = a gap worth closing. Both pass = an unexplained survivor until legal ambiguity is established. **Run it, never read it** — cleanroom.
- [ ] CR3 support (ISO BMFF container, not TIFF).
