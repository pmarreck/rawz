# rawz intent

## Purpose and users

rawz is a clean-room camera RAW parsing and validation library in Zig. It
serves Mecha Validate and other consumers that need specific, machine-readable
evidence that a RAW container or sensor payload is malformed or corrupt. It
ships a C FFI and a C CLI that exercises that FFI; sibling Zig consumers may
import the Zig module directly.

## Desired outcomes

- Identify supported RAW formats and distinguish camera RAW from ordinary
  photographic TIFF using semantic evidence.
- Parse container structure, interpret vendor RAW semantics, and report
  actionable failures through stable codes and bounded offsets.
- Improve corruption detection beyond container-only checks, especially for
  entropy-coded payloads and samples whose declared bit depth leaves guaranteed
  zero headroom.
- Give Validate a first-party production path while keeping LibRaw, rawspeed,
  and similar implementations as differential oracles only.

## Scope and boundaries

Version 1 covers parsing and error reporting. Demosaicing, colour science,
rendering, and conversion are excluded. A later conversion product would be a
separate effort.

Standardized TIFF profiles belong to tiffz. Proprietary vendor RAW semantics
belong to rawz. rawz depends on tiffz's parser-only module for TIFF container
facts; tiffz never imports rawz. DNG remains in tiffz because it is a public
TIFF/EP standard. CR3 is ISO BMFF and requires a separate container parser in
rawz.

The concrete Validate dependency and embedded-offset contract lives in
[`docs/validate_integration.md`](docs/validate_integration.md). Shared RAW
coverage labels and the per-format gap matrix live in
[`docs/RAW_COVERAGE_AND_NOMENCLATURE.md`](docs/RAW_COVERAGE_AND_NOMENCLATURE.md).

## Constraints

- Keep the Zig core pure and in-memory; the C CLI owns I/O.
- Preserve an acyclic `Validate -> rawz -> tiffz-parser` graph.
- Keep production dependencies first-party and exclude oracle implementations
  from shipped closures.
- Do not read or port LibRaw or rawspeed source. Exercise them only as external
  differential oracles.
- Clamp embedded reads to declared subranges and preserve payload-relative and
  host-relative offsets where findings cross container boundaries.

## Success evidence

The canonical `./test` command must pass ReleaseSafe tests and the ReleaseFast
package build in Nix. The production-closure gate must prove the shipped graph
contains only the intended parser dependency and no duplicate or forbidden
codec packages. Published commits must pass the exact targets in
`.mechatron-prime/targets`.

Format-specific validation claims require deterministic known-good and
known-bad controls. Corruption-detection claims require mutation results against
an independent decoder such as rawspeed, with false positives measured against
a specificity corpus.

Execution status and open work remain in [`PLAN.md`](PLAN.md). Project terms are
defined in [`TERMINOLOGY.md`](TERMINOLOGY.md).
