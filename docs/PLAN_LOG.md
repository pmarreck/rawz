# PLAN log

Completed PLAN.md items retired by plan-retire, oldest retirement first.

## Retired 2026-09-24

- [x] [In Progress] **September 23 dependency convergence.** Move rawz to the current, intended tiffz parser pin so Validate sees one coherent tiffz/jpegz/libjxlz graph without weakening its duplicate-package or seed freshness controls.
  - [x] Confirm the current intended tiffz, jpegz, and libjxlz revisions with tiffz and Validate; treat the September 20 `0004f747` work order as a snapshot until verified. Live `yolo` heads and Validate's current work order agree on tiffz `0004f747`, jpegz `3f6066c9`, and libjxlz `93b29e86` (2026-09-23 10:18 EDT).
  - [x] Repin only the existing `rawz -> tiffz-parser` edge and regenerate the Zig package hash and Nix fixed-output hash (2026-09-23 10:18 EDT).
  - [x] Prove the resolved graph contains one jpegz/libjxlz generation and that the production-closure gate stays strict (2026-09-23 10:18 EDT).
  - [x] Pass the canonical suite, direct manifest targets, push verification, and exact-commit Mechatron CI. Commit `67d92c9e5cdd` passed in 6 seconds (2026-09-23 10:28 EDT).
  - [x] Report exact rawz/tiffz/jpegz/libjxlz revisions and results to tiffz, Validate, and Einstein through durable inbox handoffs (2026-09-23 10:28 EDT).
  - Curiosity poke: a newer tiffz tip may carry unrelated API or closure changes; pin the narrowest current revision that all three projects intend.
- [x] [In Progress › **M3 — migrate `pef_decoder.zig` out of validate** (Pentax…] Sequencing constraint lifted by Peter via Einstein (2026-07-31 13:58 EDT): validate is not mid-release, so the migration may proceed after M2.
- [x] [In Progress › **M3 — migrate `pef_decoder.zig` out of validate** (Pentax…] Repin tiffz from vulnerable `d03c9d2` to at least `b3b8871a`, which includes the `Ifd.parse` allocation-failure double-free fix (`2a431856`) and BigTIFF `IFD8` support. Regenerate dependency hashes and pass the full rawz gates before validate pins M3.
  - Curiosity poke: the intervening commits add bounded subranges and a distinct embedded-JPEG error, so verify rawz's adapter error mapping and offset semantics rather than treating this as a hash-only repin.
- [x] [In Progress › **M3 — migrate `pef_decoder.zig` out of validate** (Pentax…] Reproduce validate's packed-12 behavior in rawz before moving code, and add the missing maximum-dimension overflow case.
- [x] [In Progress › **M3 — migrate `pef_decoder.zig` out of validate** (Pentax…] Give rawz a focused in-memory MSB bit reader for the PEF Huffman path; validate's shared media reader stays with its other consumers.
- [x] [In Progress › **M3 — migrate `pef_decoder.zig` out of validate** (Pentax…] Curiosity poke: malformed Huffman tables and unsupported bit depths must return typed errors without a trap or an unbounded decode loop.
- [x] [In Progress › **M3 — migrate `pef_decoder.zig` out of validate** (Pentax…] Rerun all 13 deep-review dimensions sequentially after the prior OOM; fix every functional, coverage, complexity, clarity, and error-domain finding before publishing the rawz migration commit.
- [x] [In Progress › **M3 — migrate `pef_decoder.zig` out of validate** (Pentax…] Pass direct sandboxed build/test checks and canonical `./test` for the rawz-side migration.
- [x] [Completed] **M1 — added tiffz as a dependency** (2026-07-31 13:47 EDT).
  - [x] Pinned tiffz `d03c9d2` and raised the package minimum to Zig 0.16.0.
  - [x] Proved the import contract red before wiring the module, then green.
  - [x] Added zlib to native and sandbox environments and forwarded explicit paths for Darwin builds.
  - [x] Regenerated the non-empty dependency FOD hash and proved its offline cache with both canonical `./test` checks.
- [x] [Completed] **M0 — scaffold verified green** (2026-07-31 13:42 EDT).
  - [x] Confirmed `.fingerprint = 0x79c9610f3a3708b0` was already committed in the untouched scaffold (`038340c`).
  - [x] `./test` passed both the sandboxed ReleaseSafe test check and the ReleaseFast package build before any project-code change.
- [x] [Completed] **M2 — format classification, as a set classifier** (2026-08-03 11:19 EDT). Answers "is this a photographic TIFF or camera RAW, and which vendor?" from tiffz-reported semantic evidence.
  - [x] Separated the allocation-free `Evidence` policy from TIFF byte/tag decoding in the tiffz adapter.
  - [x] Classified CR2/NEF/ARW/ORF/PEF/DNG/3FR/RW2 sensitivity and photographic TIFF specificity cases in one table, including the `pc260001.tif` ORF trap.
  - [x] Normalized vendor ASCII without allocating and kept bounded prefixes of long Make/Model values.
  - [x] Traversed linked, Exif, nested, repeated, and cyclic IFD references with one deduplicated, aggregate-limited offset set.
  - [x] Reran all 13 OOM-interrupted review dimensions sequentially and recorded every disposition in `CODE_REVIEW.md`.
  - [x] Published stable append-only C format/status enums and `rawz_classify_buffer`, tested through Zig and a compiled C consumer.
  - [x] Passed direct sandboxed build/test checks and canonical `./test`.
- [x] [Completed] **Mechatron Prime CI activated** (2026-08-03 11:22 EDT).
  - [x] Published M2 as `c79d729668668aa66e405a3e88bf1523794b220e` and independently verified `origin/yolo` matched.
  - [x] Mechatron built the manifest-selected package and test targets for that exact commit and reported terminal `success` in 20 seconds.
- [x] [In Progress › **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT…] Proved the old pin rejected a valid BigTIFF IFD8 SubIFD, then made the same 28-case suite pass on the new pin (2026-08-05 00:18 EDT).
- [x] [In Progress › **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT…] Repinned tiffz to `b3b8871ab17defa209f8ce368900a43eb6540a50` and regenerated both Zig and Nix dependency hashes (2026-08-05 00:21 EDT).
- [x] [In Progress › **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT…] Added a checked, bounded embedded-source classifier and pinned the new dependency error mapping inside rawz's stable error domain (2026-08-05 00:23 EDT).
- [x] [In Progress › **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT…] Published and machine-checked the professional-family matrix in `src/CAPABILITIES.json`, including honest unsupported states (2026-08-05 00:23 EDT).
- [x] [In Progress › **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT…] Added deterministic PEF Huffman known-good/known-bad and sniper/bolter/shotgun measurements whose declared JSON values are checked against the executable measurement (2026-08-05 00:24 EDT).

## Retired 2026-09-25

- [x] [In Progress › **Mecha Validate v1 RAW gate** (started 2026-08-05 00:08 EDT…] Documented the higher-level Validate coordinator and rejected a direct `tiffz <-> rawz` dependency cycle (2026-08-05 00:25 EDT).
