# Cross-platform build conformance

The queued migration adopts the shared cross-platform build convention read on
2026-10-23. This document records acceptance criteria; conformance remains open.

## Current gaps

- `./build` always builds the default Nix package. Its parsed `--debug` and
  `--test` modes are not passed to the native graph.
- Direct builds and coverage tests share `zig-out/bin` across targets and
  profiles. There is no platform-specific command publication.
- The flake declares three native Nix systems. Windows cross-build outputs and
  an explicit five-platform command contract are absent.
- `build.zig` already owns the Zig library and C CLI graph and remains the
  build authority. rawz has one executable implementation, so no artificial
  implementation-selection file is needed.

## Required behavior

- Use PF names `macos-arm64`, `linux-amd64`, `linux-arm64`, `mswin-amd64`, and
  `mswin-arm64`; translate them explicitly into compiler triples and Nix system
  identifiers at their tool boundaries.
- Keep complete direct products under
  `zig-out/<PF>/[<VARIANT>/]<profile>/`, with `gnu` or `musl` only where
  applicable. Keep retained Nix outputs under `.nix-out/<PF>/<profile>`.
- Publish compatible compiled commands through `bin/<PF>/` after a successful
  build and header/runtime-dependency check. Use relative links for direct
  products. Preserve the selected command when a build or publication fails.
- Keep generic `bin/` portable. Cross-building another PF or profile must not
  replace the host's selected command or write through a Nix store link.
- Make `./build` default to the optimized host Nix build. Provide an explicit
  direct backend, working debug/test modes, documented native equivalents,
  `--all-plats`/`--all-platforms`, and `--all` over declared supported targets.
- Make `./run` ensure and execute the exact current host product. Keep
  `./test` complete, bind every suite to its own product, and retain the
  ReleaseSafe test floor and ReleaseFast shipped build.
- Preserve generated-product ignore rules, dependency isolation, Windows
  executable/resource adjacency, and every existing unknown product until its
  role and recovery path are established.

## Acceptance controls

Exercise platform aliases as supported/rejected sets; assert actual compiler
arguments with recording adapters. Test paths with spaces, coexistence of host
and foreign/profile products, failed builds, competing publications, and stale
PATH installations. Independently inspect ELF, Mach-O, and PE headers. Record
native runtime evidence separately from cross-compile evidence. Changes to
global shell PATH discovery belong to its owner and are outside this migration.
