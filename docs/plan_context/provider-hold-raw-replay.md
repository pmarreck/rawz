# RAW replay boundary under the JPEG provider hold

## Current adoption order

The JPEG provider hold was released for dependency adoption on 2026-10-15.
Freshness checks remain required. TIFFZ publishes the single JPEGZ dependency;
rawz and Validate consume that TIFFZ instance without adding a direct JPEGZ
pin. JPEGZ's separate non-luma sampling research remains held.

### 2026-10-23 adoption

The current published TIFFZ candidate is
`d3b993c7a6566352d1ea7bbbdb9b6975946b9dd7`, package
`tiffz-0.1.0-qutJAQft0QHvRb-45d024sZUeu8dHG5o8CYOYRvMCXAO`.
It carries JPEGZ `860654d19f43e76c70ca084ee96df481fcaf959e`, package
`jpegz-0.1.0-staw4GpwEwC4WKF47FL1ts63Dv0jgyHzI5qabwLRdQlp`,
JP2Z `a7cc185ca16a0c06a08a2d995295814d6347fb6d`, and LERCZ
`39703ee5aeb3829899d63a15888f715dad054832`.
The rawz Nix dependency cache is
`sha256-If26PkmQmqn0yOlghrbGLcnN8uEpcXphH87hOHiyO3M=`, measured from
a real mismatch against the prior cache hash.

This candidate contains TIFFZ's NRW complete-strip padding fix `be1e8cbc`.
That fix runs in the full TIFFZ strip validator used by the consumer; rawz's
codec-free classifier does not decode those strips. JPEGZ adds valid multi-scan
sequential decoding and typed entropy findings, including code 62. rawz adds
no direct JPEGZ import or finding-code translation.

TIFFZ confirmed on 2026-10-23 that this candidate should be adopted while its
next JPEGZ update is prepared. JPEGZ's published `ca500f9` recovery change and
the in-progress all-zero-padding warning code 63 will travel through a later
tested TIFFZ release. They are not part of this adoption. No stale-pin override
is introduced, and consumers still own their freshness acceptance.

### 2026-10-17 adoption receipt

The 2026-10-17 reconciliation selects published TIFFZ
`35536193d75fbc4ab1ff18bafffe72753c16f9b7`, Zig package
`tiffz-0.1.0-qutJAaHe0QFf7-gwH8YIUfkiUYuKvV1S2qUXP34r6-pA`.
It carries JPEGZ `85455ebc1fa284d65581c6501cb641b3ac965997`, package
`jpegz-0.1.0-staw4HATEwC0XcJnIkmt6EbZ1qkGp4rbLrT2QLOMznWT`.
rawz continues to import only TIFFZ's parser module. No new sensor validation
or coverage promotion is implied by this dependency update.

The regenerated Nix dependency cache is
`sha256-vzhZ1hTUQGSYecbVbesSCPCYIWfQx53xB2M74QA1p10=`. It was measured by
rebuilding the changed fixed-output derivation against its previous real hash.
The builder verified one JPEGZ package and one LIBJXLZ package, with LIBJXLZ
still at `93b29e86281ea4ba9c681f4879318c87e8a800a4`.
The resulting rawz Zig package identity is
`rawz-0.1.0-sAg3OmgVAwAsjRqkxIoSML08yZaNOSIKCGbRwfhPDz84`.

The complete `./test && ./build` gate passed under the bounded local build
runner. Mechatron Prime CI, the project's continuous-integration service,
passed published rawz `43d6dd16612a971ec9b8a93f848ca74309888954` in 1m58s.
The exact published URL independently reproduced the rawz package identity.
JPEGZ and Validate received the revisions, hashes, passing gates, and unchanged
coverage qualifications on 2026-10-17.

Validate acknowledged the four-profile Sony ARW2 scorecard on 2026-10-15 and
recorded its exact fixture, counts, Wilson intervals, and limitations as
producer-measured evidence. Successful ARW2 syntax remains structural.

## Historical hold boundary

The dependency-convergence graph published on 2026-10-10 was producer evidence
while the consumer's JPEG provider hold remained active. That hold forbade
consumer repins, builds, fetches, and alternate JPEG routes. It permitted
rawz-owned validation using the already available `tiffz-parser` surface. The
receipts and replay matrix below preserve that historical state.

## Preserved producer receipts

| Package | Published head | Zig package identity | Local gates | Exact Mechatron Prime target |
|---|---|---|---|---|
| JP2Z | `91264891cdce2180dd65e211029098dac80ff067` | `jp2z-0.0.1-yLLHxdW_bgAiJm0mWuSYiGMXHrhnVOJ8iowwbhbrlg98` | Exercised through JPEGZ's complete gates | No new JP2Z commit was produced in this convergence |
| JPEGZ | `f1a255a5b132680da1a2ac670e84a2bda7eec2ee` | `jpegz-0.1.0-staw4DnTEgAkHRUJvJtUx6xpS1KAMDI5HBVsW17BQ8xC` | `./test` and `./build` passed | `f1a255a` passed in 7m26s; package commit `8d325c6` passed in 14s |
| TIFFZ | `e9564e4f11c597f858beb4d113761ea478e98d77` | `tiffz-0.1.0-qutJAY8I0QEam3UpJX18mPmas8JBh-6bYWogcqRBaENX` | `./test` and `./build` passed | `e9564e4` passed in 8m54s |
| rawz | `33c10b97a8d209050ff9d70646a158ddc7217673` | `rawz-0.1.0-sAg3OleRAgD9DL-NnVx7mDT1QeTrnjL53eBvjVJFpwmA` | `./test` and `./build` passed | `33c10b9` passed in 46s; package commit `65255d5` passed in 44s |

The converged graph also pins LIBJXLZ `93b29e86281ea4ba9c681f4879318c87e8a800a4`, Nixpkgs `8edc0c72e3a38faf5434e40d1f19431125fe4b30`, flake-utils `11707dc2f618dd54ca8739b309ec4fc024de578b`, nix-systems `d36eeed142f88b5a636f2e3856a53c61654cf29b`, and Zig 0.16.0. LERCZ remains at its published Zig-package branch head `a88c39b7697e3a579c8a84445a5ca0145bbe59fa`; the repository default-branch head has no Zig package.

## Consumer replay matrix

| RAW work | Works with permitted providers? | Consumer action while the hold remains |
|---|---|---|
| Nikon version-`0x46` successful syntax classification at rawz `c82afeed764defdea11bc69fef1733f99cbeb87c` | Yes; it uses rawz-owned Nikon parsing and the already injected TIFF parser | Review or replay at the current permitted graph; no JPEG dependency change is needed |
| Sony ARW2 Compression-32767 fixed-packet validation | Yes; the selected lane uses rawz-owned packet checks and TIFF facts available through `tiffz-parser` | Review the rawz-only diff or replay its synthetic and exact-fixture controls without changing TIFFZ, JPEGZ, or JP2Z pins |
| Panasonic legacy residual/precision validation | Partly; a pure payload validator can be reviewed independently, but the current parser does not admit the selected `IIU\0` container | Review payload-only evidence when available; treat full-file location as blocked until an admitted parser route exists |
| DNG Compression 7 and CR2 SOF3 composition | No | Keep held; both require the consumer's single injected JPEG provider route |
| ARW4+ lossless JPEG | No | Keep held; do not substitute the ARW2 cRAW validator |

The Sony ILCE-7M3 ARW 2.3.3 14-bit Compression-32767 packet validator and
exact CFA SubIFD locator are now delivered. Its success result remains
`structural(analytical_ceiling_unestablished)`. The grammar checks leave all
fourteen seven-bit deltas representable, so 98 of 128 packet bits form a lower
bound on grammar-surviving in-place bit changes under the declared assumptions;
this is not a format-wide corruption miss-rate proof. The next unblocked lane
is a separately testable Panasonic residual/precision rule; the legacy
container parser boundary remains unchanged.
