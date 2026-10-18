# PLAN

Completed work is retained in [`docs/PLAN_LOG.md`](docs/PLAN_LOG.md).

## In Progress

- [x] Adopt published TIFFZ `35536193` carrying JPEGZ `85455eb` through one parser instance; complete local gates and exact Mechatron Prime CI passed, and producer/consumer replies were delivered (done 2026-10-17 22:19 EDT; `43d6dd1`; context: `docs/plan_context/provider-hold-raw-replay.md`).

- [x] Add `./corruption-coverage` using corruption-reader's consumer CLI for reproducible `sniper`, `bolter`, `shotgun`, and `nuke` measurements with pristine gates, survivor replay, and 95% Wilson intervals; run 385 cases/profile against the exact Sony ARW2 control (done 2026-10-15 13:09 EDT; `a52be01`; evidence: `docs/coverage-evidence/arw2-full-file-corruption-2026-10-15.md`).

- [x] Reconcile every direct, transitive, and toolchain dependency pin to current upstream heads through JP2Z `91264891`, JPEGZ `f1a255a`, TIFFZ `e9564e4`, Nixpkgs `8edc0c72`, flake-utils `11707dc2`, nix-systems `d36eeed1`, LIBJXLZ `93b29e86`, and Zig 0.16.0; complete local gates passed and Mechatron Prime passed `65255d5` in 44 seconds (done 2026-10-10 20:34 EDT).

- [ ] Deliver the highest-value JPEG-independent launch-priority RAW checks red-first with exact revision, fixture, profile, false-positive, and residual identities.
	- [x] Preserve the held rawz/TIFFZ/JPEGZ/JP2Z producer receipts and send Validate an exact replay matrix for RAW-only fixes that work with its permitted pins (done 2026-10-10 21:37 EDT; context: `docs/plan_context/provider-hold-raw-replay.md`).
	- [x] Publish the exact launch-subset handoff for compressed Nikon version 0x46 and Pentax compression 65535, including consumer reach, current fixtures/profiles, specificity, residuals, and the actual ARW2 locator state (done 2026-10-14 15:34 EDT; evidence: `docs/coverage-evidence/raw-launch-subset-2026-10-14.md`).
	- [ ] After the Sony lane, define and deliver the first independently testable Panasonic residual/precision rule with paired pristine and malformed controls.
	- [ ] Reconcile rawz sensor-result vocabulary with Validate's published typed-finding and reach contract after Validate identifies the candidate carrying the 2026-10-14 verdict terminology; do not introduce unpublished statuses.

- [x] Reconcile the exact-variant RAW plan against published Canon/DNG/Nikon evidence, then correct the Nikon D300 14-bit lossless-compressed version-0x46 claim red-first with the exact CC0 original, a truncated malformed control, and independently attributable corpus evidence (done 2026-10-10 13:36 EDT).

- [ ] Audit active mutation labels and migrate legacy dense `shotgun` usage to `nuke` without rewriting historical evidence.

- [ ] **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT).
  - [ ] Deliver sensor-data checks Validate needs for full-depth RAW promotion, reporting each family by exact SHA and measured coverage (context: `docs/plan_context/sensor_data_checks.md`).
	- [x] Repin the next-candidate graph from TIFFZ `4e6d9c31` to published `618d38d`, regenerate only mechanically required dependency hashes, and run complete local gates while preserving the Nikon packet (done 2026-10-10 02:44 EDT; `0f982f5`, Mechatron Prime PASS in 42s).
	- [x] Forward-pin TIFFZ separately from accepted `618d38d` evidence to published `abc2beb2`, regenerate its dependency hash, and run complete local gates before publication (done 2026-10-10 02:49 EDT; `49d35c9`, Mechatron Prime PASS in 43s).
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
