# PLAN

Completed work is retained in [`docs/PLAN_LOG.md`](docs/PLAN_LOG.md).

## In Progress

- [ ] Reconcile every direct, transitive, and toolchain dependency pin to its current upstream head, regenerate only required hashes, pass the complete local and exact CI gates, and reply durably to Validate.

- [ ] Inventory launch-priority RAW exact variants against recovered evidence, then deliver the highest-value JPEG-independent sensor-payload objective check red-first with exact revision, fixture, profile, false-positive, and residual identities (coordination window ends 2026-10-11 02:30 EDT).
	- [ ] Correct PEF compression-65535 successful syntax passes from `full` to structural without relabeling historical mutation evidence as new coverage.
	- [ ] Deliver Sony ILCE-7M3 ARW 2.3.3 14-bit Compression-32767 packet validation with exact CC0 original, truncated peers, legal counterexamples, bounded measurement, and a grammar-only detectability bound.

- [x] Reconcile the exact-variant RAW plan against published Canon/DNG/Nikon evidence, then correct the Nikon D300 14-bit lossless-compressed version-0x46 claim red-first with the exact CC0 original, a truncated malformed control, and independently attributable corpus evidence (done 2026-10-10 13:36 EDT).

- [x] Refresh every direct, transitive, and toolchain dependency pin to its upstream head, including tiffz `4e6d9c31`, nixpkgs `39ad350a`, flake-utils `11707dc2`, nix-systems `d36eeed1`, and Zig 0.16.0; regenerated hashes and the full local gate set pass (done 2026-10-08 21:33 EDT).
- [ ] Audit active mutation labels and migrate legacy dense `shotgun` usage to `nuke` without rewriting historical evidence.

- [ ] **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT).
  - [ ] Deliver sensor-data checks Validate needs for full-depth RAW promotion, reporting each family by exact SHA and measured coverage (context: `docs/plan_context/sensor_data_checks.md`).
	- [x] Inventory exact delivered RAW variants against MKTP's six criteria, then close one justified bounded sensor-path gap red-first or document the research/control boundary; preserve hashes, commands, controls, residuals, exact CI, and coordinator receipts (done 2026-10-10 00:49 EDT; `ba929f8`, Mechatron Prime PASS in 45s; context: `docs/mktp-research/raw-sensor-variants-2026-10-10.md`).
	- [x] Correct the PEF sample-work budget from a corruption failure to named structural reach with malformed, at-limit, and same-input over-budget controls; preserve the low-level append-only error ABI and exact delivery evidence (done 2026-10-10 01:08 EDT; `711b1fa`, Mechatron Prime PASS in 43s; context: `docs/mktp-research/raw-sensor-variants-2026-10-10.md`).
	- [x] Correct Nikon CFA-IFD traversal budgets to named structural reach with a valid inclusive-cap traversal, the same fixture under a lower budget, and a malformed offset that remains a file defect (done 2026-10-10 02:44 EDT; `e463c07` in `0f982f5`, exact Mechatron Prime PASS in 42s; context: `docs/mktp-research/raw-sensor-variants-2026-10-10.md`).
	- [x] Repin the next-candidate graph from TIFFZ `4e6d9c31` to published `618d38d`, regenerate only mechanically required dependency hashes, and run complete local gates while preserving the Nikon packet (done 2026-10-10 02:44 EDT; `0f982f5`, Mechatron Prime PASS in 42s).
	- [x] Forward-pin TIFFZ separately from accepted `618d38d` evidence to published `abc2beb2`, regenerate its dependency hash, and run complete local gates before publication (done 2026-10-10 02:49 EDT; `49d35c9`, Mechatron Prime PASS in 43s).
    - [x] Ratify and deliver `Maximum Known Technically Possible` (`MKTP`) as the variant-scoped depth label for complete best-effort parsing whose remaining corruption blind spots are fundamental to the format (done 2026-09-26 15:15 EDT; durable Validate policy note delivered).
    - [ ] Ship DNG/CR2/compressed-NEF sensor syntax validation and independent per-variant coverage.
      - [x] Keep DNG CFA Compression 7 in TIFFZ: the synthetic single-component JPEGZ path shipped in TIFFZ `b38c2f47` and is present in the full TIFFZ `abc2beb2` commit that also supplies rawz's parser-only pin; a real camera-DNG scorecard remains consumer evidence, not a rawz implementation (reconciled 2026-10-10 13:05 EDT).
      - [x] Recover the Canon provider seam without bypassing the provider hold: JPEGZ `6ef766c` validates the EOS 20D two-component 12-bit SOF3 stream through EOI, both components use 1x1 sampling, and TIFFZ `abc2beb2` contains the repin; rawz's exact-range locator was already delivered (reconciled 2026-10-10 13:05 EDT).
        - [ ] Have Validate wire the located EOS 20D range through its existing single JPEGZ instance, preserve host offsets, and record the current real-file scorecard.
      - [ ] Complete Nikon Huffman evidence and result classification by exact compressed-NEF variant; this is proprietary entropy coding, separate from the DNG/CR2 lossless-JPEG seam.
        - [x] Correct successful version-0x46 syntax passes to structural until their analytical ceiling is established; qualify the real CC0 D300 14-bit lossless-compressed control separately from the delivered 12-bit row (done 2026-10-10 13:36 EDT).
    - [ ] Ship Sony ARW, Fuji RAF, Olympus ORF, and Panasonic RW2 entropy syntax checks with per-variant coverage.
    - [ ] Add the ISO BMFF container before Canon CR3 CRX syntax validation and coverage.

## Next

- [ ] **M5 — corpus.** `raw.pixls.us` (CC0, purpose-built for RAW software testing) is the primary source — **verify license terms at fetch time**. Cover the axes that matter: compression variant, bit depth, CFA vs X-Trans. darktable **cannot generate** RAW, only read it.
- [ ] **M6 — differential oracle.** darktable 5.6.0 is installed (79 makers / 1,389 models via rawspeed). Mutate known-good RAW; compare rawz's verdict to rawspeed's decode. *rawspeed rejects + we pass* = a gap worth closing. Both pass = an unexplained survivor until legal ambiguity is established. **Run it, never read it** — cleanroom.
- [ ] CR3 support (ISO BMFF container, not TIFF).
