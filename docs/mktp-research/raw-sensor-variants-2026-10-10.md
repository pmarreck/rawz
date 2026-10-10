# Delivered RAW sensor variants: MKTP evidence inventory

## Scope and assessment identity

This record inventories the sensor paths delivered before 2026-10-10. It applies Validate's six Maximum Known Technically Possible (MKTP) criteria to exact variants, without promoting any family by extension. The inspected source is rawz `e05636dfe2e54dbbfc8324261bcd9f25b0c1412a`. The implementation commits are named per variant below. No current-binary measurement is inferred from the source checkout; historical binaries and measurements retain their recorded identities.

## Six-criterion inventory

The criterion columns correspond to Validate `TERMINOLOGY.md` B4: (1) exact end and bounds, (2) every known objective invariant, (3) no deferred applicable check, (4) documented format-level residual, (5) analytical ceiling plus pristine-controlled measurement, and (6) independent replay or external oracle with complete identities.

| Exact variant | Delivered source | Implemented checks | 1 | 2 | 3 | 4 | 5 | 6 | Current assessment |
|---|---|---|---|---|---|---|---|---|---|
| Pentax PEF, compression 65535, 12-bit private Huffman, supported AOC MakerNote table | `ef74184d1a330b4aedd5a01ae37c4bfb3527c544` | Bounded table lookup; canonical lookup-table construction; invalid-code, truncation, predictor-range, zero tail-padding and exact byte-end checks | yes | partial | no | no | partial | partial | `structural`; the implementation currently returns `full`, which the B4 evidence does not support |
| Pentax PEF, compression 32773 PackBits decoded by TIFFZ, packed 12-bit rows | `ef74184d1a330b4aedd5a01ae37c4bfb3527c544` | Compression-stage dispatch and packed-row extent | yes after TIFFZ decode | partial | no | partial | partial | partial | `structural(sample_values_have_no_integrity_signal)` |
| Nikon NEF, compression 34713, table version 0x46, 12-bit lossless Huffman | `137d69e8f72380fb7ffce1536b95db000e3093ce` | Bounded CFA strip and MakerNote-table location; fixed codebook; exact sample count; truncation, predictor-range and trailing-byte checks | partial | partial | no | no | partial | partial | `structural`; the implementation currently returns `full`, which the B4 evidence does not support |
| Nikon NEF, compression 34713, table version 0x46, 14-bit lossless Huffman | `137d69e8f72380fb7ffce1536b95db000e3093ce` | Same synthetic syntax checks as the 12-bit path | partial | partial | no | no | no real-file ceiling | synthetic only | `structural`; no real-file scorecard or independent exact-variant replay |
| Nikon NEF, uncompressed 12- or 14-bit samples stored one per 16-bit word, either byte order | `82128c66617035abcd9b02174ee61afdd4b43bc2`, policy correction `35523bde0506b2d1e6621fb6fd62168c35b6aaa7` | Exact extent; unused-high-bit headroom; optional black/white bounds | yes for this layout | partial | no when levels are unavailable | partial | partial | partial | `structural(metadata_levels_unavailable)` or `structural(sample_values_have_no_integrity_signal)` |
| Canon CR2, classic TIFF, one compression-6 or compression-7 strip named by the CR2 raw-IFD pointer | `f13e325b5e49248dbbd58f1f6503564dc6a85546` | CR2 signature and raw-IFD pointer; compression dispatch; one-strip count and file bounds | no sensor decode | no | no | no | no | pristine locator only | `structural`; this is a bounded locator, not a lossless-JPEG validator |

No row presently satisfies all six criteria. This inventory is evidence for follow-up work, not an MKTP ledger claim.

## Fixture and measurement index

| Variant | Pristine fixture SHA-256 | Recorded profile and source identity | Outcome retained |
|---|---|---|---|
| PEF private Huffman | `e35ae4154a468be3154f5f462e884ba5941f010d3e8f23d347fbec14809f44d3` | rawz `ef74184`, seed 42, 100 different-byte replacements and 100 EOF cuts; Validate `3dc478a2d`, 1,000 whole-file rounds | 97/100 byte replacements and 100/100 EOF cuts detected by rawz; Validate reported 84.5% sniper and 99.0% shotgun over the whole file |
| PEF PackBits | `86ec2383dbfda3eda38ca913b02874a70248efba6107aa304781c8d3779de8c9` | Historical structural control | Extent checked after TIFFZ decompression; no sensor-value integrity claim |
| Nikon 0x46, 12-bit | `7e6d38ddebe82784dc8c84cdf02dce7bcfe74b71b0dec91b28551936102c39b9` | rawz `137d69e`, xorshift64 seed 42, 100 different-byte replacements and 100 EOF cuts; Validate `3dc478a2d`, binary SHA-256 `597c837b732091ff50b673a16189838ac7e393b792ff3d40850004137b980108`, seed `1790365110` | 69/100 byte replacements and 100/100 EOF cuts detected by rawz; Validate reported 31.0% sniper and 98.8% shotgun |
| Nikon uncompressed 14-bit words | `0261523d0ab4694df0219404eb08af5db04697a05e85718e7f7bd42d283205f4` | rawz `82128c6` plus `35523bde`, xorshift64 seed 42; Validate `3dc478a2d`, binary SHA-256 `597c837b732091ff50b673a16189838ac7e393b792ff3d40850004137b980108`, seed `1790365088` | rawz detected 140/1000 single-bit flips, 348/1000 different-byte replacements and 100/100 EOF cuts; Validate reported 12.8% sniper and 99.2% shotgun |
| CR2 one-strip locator | `db78660d48589130d99e0bc621424851eb0f84df052634fb5bc89c7a02fe7033` | rawz `f13e325`; no sensor-payload mutation profile | Exact range located; lossless-JPEG path remained unsupported at the recorded TIFFZ/JPEGZ pin |

The fixture hashes and historical commands are indexed from `docs/coverage-evidence/`. A new experiment must record its own source revision, built binary hash, command, seed, profile version, pristine result and artifact path. It must not borrow the identities above.

## Research trail and rejected hypotheses

- The PEF and Nikon entropy algorithms were independently implemented from the public-domain dcraw descriptions identified in the source comments. LibRaw and rawspeed source were not read. Rawspeed and darktable were used only as black-box decoders in the historical experiments.
- TIFF container extent checks follow the TIFF tag model through TIFFZ. Canon CR2 header semantics, Pentax MakerNote layout and Nikon MakerNote layout are proprietary. Their checks are explicitly inferred from bounded fixtures and the cited public-domain implementation lineage, not represented here as normative vendor requirements.
- A decoder accepting a mutation proves only that the mutation survived that decoder. Shared acceptance by rawz and an external decoder does not establish a legal alternate stream. The prior PEF and Nikon reports' stronger interpretation is superseded by this record.
- Nikon 0x46 ends after a declared sample count. The current validator rejects trailing whole bytes but leaves unused low bits in the final byte uninterpreted. No retrieved rule establishes that those bits must be zero, so a zero-padding corruption rule is rejected pending primary evidence or a stronger independent control.
- A work or memory budget is a property of the validator, not evidence that the file is corrupt. Before this milestone, Nikon 0x46 mapped its sample-work ceiling to `FAIL work_limit_exceeded`; the bounded implementation milestone corrects that verdict/reach boundary with malformed, at-limit and over-budget controls.

## Experiment log

### 2026-10-10 00:33 EDT: invalid red run exposed a test-root omission

- Purpose: run the new three-case Nikon budget classifier before implementation.
- Command: `build-budget --project rawz -- nix develop -c zig build test`.
- Build-budget unit: `build-rawz-c0c998cd-9d0b-4e6c-bad2-5f76cf45481d.scope`; receipt exit code 0.
- Outcome: the expected compile failure did not occur because `src/lib.zig` did not reference the public `nikon_huffman` module in its module-availability test. Zig's lazy analysis therefore excluded that module's tests from the test artifact.
- Disposition: this run is not behavioral evidence. The test root now references `nikon_huffman` and `sensor_validation`; the red run must be repeated through `build-budget` before implementation.

### 2026-10-10 00:44 EDT: valid red and focused green

- Red command: `build-budget --project rawz -- nix develop -c zig build test`.
- Red build-budget unit: `build-rawz-62e29659-4ed2-4a6b-ab8d-4a48dd6adea9.scope`; exit code 1.
- Red result: compilation failed because `sensor_validation.ReachReason` had no `work_limit_exceeded` member. The failing expectation was the legal one-sample stream with `max_samples = 0`; malformed dimensions and the same stream at `max_samples = 1` are controls in the same set.
- Minimal implementation: append reach code 7 and route Nikon's `sample_count > max_samples` branch to `structural(work_limit_exceeded)`. The failure code remains append-only for existing consumers.
- Green command: `build-budget --project rawz -- nix develop -c zig build test`.
- Green build-budget unit: `build-rawz-e8a9b600-d993-4255-a952-5b4363f205e1.scope`; exit code 0.
- Scope: deterministic synthetic controls only. No real fixture, external decoder or mutation score was rerun for this classification-only change.

### 2026-10-10 00:47 EDT: complete local gates

- Source base: rawz `e05636dfe2e54dbbfc8324261bcd9f25b0c1412a`; staged code diff SHA-256 `2e07136f731c00b8a86eb502f51ac1335b45935b869ab600bb388b8aa7ae2e1b`.
- Complete test command: `build-budget --project rawz -- nix develop -c ./test`.
- Test build-budget unit: `build-rawz-48ac69b1-48fc-4e8d-b09e-dc8fa915981a.scope`; exit code 0.
- Complete build command: `build-budget --project rawz -- nix develop -c ./build`.
- Build build-budget unit: `build-rawz-c07e639e-e9f9-47b3-a948-ec77ab4eaacb.scope`; exit code 0.
- Package output: `/nix/store/dr3s1ixmv3qswcrisa70r0wq5kc8w248-rawz-0.1.0`; executable SHA-256 `0c009730f50bb39060b2f1d9331d224d032d4f8baad767912f41b03b0d4d3649`; static-library SHA-256 `460589eb4a50969a96f0dc2eb467be7de3521245b6b1e10e7106b71030aa12da`.
- These gates prove delivery of the classifier correction and current capability declaration. They do not constitute a new mutation campaign, an analytical ceiling, or Validate adoption.

### 2026-10-10 00:56 EDT: PEF sample-work reach red and focused green

- Source base: rawz `9956f587a69313741723518de63fdd717907077c`.
- Red command: `build-budget --project rawz -- nix develop -c zig build test`.
- Red build-budget unit: `build-rawz-9b60799b-9218-4d20-b419-0657157e6ca7.scope`; exit code 1, with 60/61 tests passing.
- Red result: the same valid one-pixel PEF stream returned `fail(work_limit_exceeded)` under `max_pixels = 0`; malformed dimensions and the stream at `max_pixels = 1` were successful controls.
- Minimal implementation: the evidence-classification result layer maps the PEF pixel-work ceiling to `structural(work_limit_exceeded)`. The low-level `validatePefHuffmanWithLimits` API retains `PefDecodeError.WorkLimitExceeded` for append-only compatibility.
- Green command: `build-budget --project rawz -- nix develop -c zig build test`.
- Green build-budget unit: `build-rawz-23cd736d-dc48-4c26-bde6-5851402bf0d9.scope`; exit code 0, with 61/61 tests passing.
- Complete test command: `build-budget --project rawz -- nix develop -c ./test`.
- Complete test build-budget unit: `build-rawz-a2ada3e7-f40e-4846-a41c-c5c3764c008a.scope`; exit code 0. The staged `src/pef_decoder.zig` diff SHA-256 was `b19410ff51a67e5ee7673f49cb2a151d0b7d850e3e5f2d6a0b636bf237e0edc4`.
- Complete build command: `build-budget --project rawz -- nix develop -c ./build`.
- Complete build build-budget unit: `build-rawz-2b842065-0c42-417c-8b40-93cbee461ce9.scope`; exit code 0.
- Package output: `/nix/store/nnbs0d2hz85d42saw2mpq1w9qi5xjkfv-rawz-0.1.0`; executable SHA-256 `0c009730f50bb39060b2f1d9331d224d032d4f8baad767912f41b03b0d4d3649`; static-library SHA-256 `460589eb4a50969a96f0dc2eb467be7de3521245b6b1e10e7106b71030aa12da`. Both packaged hashes are unchanged from M1; this source/test API correction does not produce a different current C artifact.
- A read-only consumer check found that Validate already maps PEF `work_limit_exceeded` reach to a structural result. No adapter or dependency-pin change is required.
- Scope: deterministic synthetic controls only. No real fixture, external decoder or mutation score was rerun.

### 2026-10-10 01:14 EDT: Nikon CFA traversal reach red and focused green

- Source base: rawz `5f60b18a12a2918b519bc1ff4da1b5086c70f7d1`.
- Fixture: a 156-byte synthetic big-endian TIFF with two SubIFDs, the first valid non-CFA and the second a valid 2-by-2 uncompressed Nikon CFA payload at host offset 148.
- Red command: `build-budget --project rawz -- nix develop -c zig build test`.
- Red build-budget unit: `build-rawz-63d08c60-9ab6-458c-b055-6a62c705666b.scope`; exit code 1 because the injected-limit locator did not exist.
- Minimal implementation: add rawz-owned `LocateLimits` and `locateSensorPayloadWithLimits`; admit child visits through the inclusive cap and return `structural(work_limit_exceeded)` only before the next visit.
- Controls: cap 2 locates the second-child CFA payload; cap 1 returns reach for the same bytes after validating the first child; corrupting the admitted first offset from 34 to 255 returns `fail(malformed_metadata)` at source-relative offset 255 under cap 1.
- Green command: `build-budget --project rawz -- nix develop -c zig build test`.
- Green build-budget unit: `build-rawz-75e26b76-b91b-4092-aa02-e8f5591da11d.scope`; exit code 0.
- Complete test command: `build-budget --project rawz -- nix develop -c ./test`.
- Complete test build-budget unit: `build-rawz-cf8a978b-8b7d-4099-a7b5-e5174fd080b3.scope`; exit code 0. The staged `src/nef_sensor.zig` diff SHA-256 was `dfa66848ffc1ce867e40143fc1ea2ea310a0e6429a389fbc7028596a48035819`.
- Complete build command: `build-budget --project rawz -- nix develop -c ./build`.
- Complete build build-budget unit: `build-rawz-b456af16-8807-4694-ae44-3096ba011969.scope`; exit code 0.
- Package output: `/nix/store/gyj9icxvpld53hxl7rvjk4zf8g24wmyn-rawz-0.1.0`; executable SHA-256 `0c009730f50bb39060b2f1d9331d224d032d4f8baad767912f41b03b0d4d3649`; static-library SHA-256 `460589eb4a50969a96f0dc2eb467be7de3521245b6b1e10e7106b71030aa12da`. Both packaged hashes are unchanged from M1 and the PEF packet; this source/test API correction does not produce a different current C artifact.
- A read-only consumer check found that Validate already maps NEF `work_limit_exceeded` reach to a structural result. No adapter or dependency-pin change is required.
- Scope: deterministic synthetic controls only. No large fixture, cycle walk, real corpus, external decoder or mutation score was used.

### 2026-10-10 02:00 EDT: local TIFFZ next-candidate pin

- Source base: unpublished rawz `e463c07788595be2f9a7c7a8ba6f323b91cf55a8`; published rawz remained `5f60b18a12a2918b519bc1ff4da1b5086c70f7d1` under the candidate hold.
- Dependency: TIFFZ moved from `4e6d9c31332b69bdcd6773da8fd1f315b5b6ac26` to published `618d38d403764fbe29692ec211d2d4b45e748e6d`.
- Zig package identity: `tiffz-0.1.0-qutJAa7v0AHlPX8VKWKTtuHr1K94vuRg0QpggS9ER7W3`.
- Imported-parser control: `src/parser.zig`, `src/limits.zig`, `src/ifd.zig` and `src/errors.zig` have no diff between those TIFFZ commits. The upstream delta is decoder/CLI/Nix evidence work outside rawz's parser-only import graph, so no new rawz corruption classifier was introduced.
- Fixed-output discovery command: `build-budget --project rawz -- nix build .#default` with `pkgs.lib.fakeHash`.
- Discovery build-budget unit: `build-rawz-fba5d234-e456-4955-87d8-493f1a445f89.scope`; expected exit code 1; reported `zigDepsHash` `sha256-1m7yJq4Ae+cHT7leenXx1HOjS1jZS4gEvfJKfpCkKL0=`.
- Exact-hash package command: `build-budget --project rawz -- nix build .#default`.
- Exact-hash build-budget unit: `build-rawz-9d38b6ad-8675-4d04-8827-52078d89ca3a.scope`; exit code 0.
- Complete test command: `build-budget --project rawz -- nix develop -c ./test`.
- Complete test build-budget unit: `build-rawz-a59ff144-292a-4dad-88fc-59f43a3998c7.scope`; exit code 0.
- Complete optimized build command: `build-budget --project rawz -- nix develop -c ./build`.
- Complete optimized build-budget unit: `build-rawz-586c8e5f-291e-4388-b11c-b0d2de43d14a.scope`; exit code 0.
- Pin/configuration diff SHA-256 across `build.zig.zon`, `flake.nix`, `src/CAPABILITIES.json`, `src/capabilities.zig` and `docs/validate_integration.md`: `d2d2f3cefe627df5841bcb175e246df4edb74bf42f979f1ab8b1dbd9931cf1b8`.
- Package output: `/nix/store/am55mfxw1pn7fwvlrxwqb5mra8dbfivx-rawz-0.1.0`; executable SHA-256 `0c009730f50bb39060b2f1d9331d224d032d4f8baad767912f41b03b0d4d3649`; static-library SHA-256 `460589eb4a50969a96f0dc2eb467be7de3521245b6b1e10e7106b71030aa12da`. The packaged hashes remain unchanged, consistent with the identical imported parser sources.
- Scope: dependency identity and package-cache closure only. No JPEG pin, vendor decoder, corpus, toolchain or MKTP assessment changed.

## Residuals and known gaps

- PEF and Nikon entropy survivors remain unexplained until each is classified against a demonstrated format rule. The measured survivors are not an analytical any-value census.
- PEF private Huffman has no analytical ceiling, no current-binary replay and no input for metadata black/white bounds. Its result API now classifies the sample-work limit as reach; its intentionally retained low-level error value is not a corruption verdict.
- Nikon 0x46 has no validated rule for final-byte padding, no analytical ceiling, and no real 14-bit scorecard. Lossy tables, split-row tables, packed data and other metadata versions remain unsupported.
- Nikon's CFA-IFD locator now classifies traversal-budget exhaustion as reach after validating the admitted prefix. Malformed admitted offsets remain failures; recursive IFD-cycle handling is outside this nonrecursive SubIFD-array locator.
- Uncompressed-word measurements cover one 14-bit Nikon layout. Packed samples, row padding, noncontiguous strips and variants with usable level metadata require separate rows.
- CR2 payload validation still depends on an exact JPEGZ/TIFFZ path that accepts Canon's two-component subsampled SOF3 layout. Locator success says nothing about entropy-stream integrity.
- Historical measurements used the mutation definitions recorded at their dates. They are not silently relabeled under later sniper, bolter, shotgun or nuke profiles.

## Bounded next action

Reassess the exact-variant inventory after the bounded budget corrections without promoting any row. Remaining work is format evidence: objective invariants, demonstrated residual classes, analytical ceilings and independent current-binary replay.

After the focused change, run the complete local test/build entry point through `build-budget`, record the exact source and binary hashes, publish the commit, obtain exact Mechatron evidence, and send the coordinator a delivery receipt. Validate adoption remains a separate consumer action.
