# RAW replay boundary under the JPEG provider hold

The dependency-convergence graph published on 2026-10-10 is producer evidence only until the consumer's JPEG provider hold is explicitly lifted. The hold forbids consumer repins, builds, fetches, and alternate JPEG routes. It does not block rawz-owned validation that uses only the already permitted `tiffz-parser` surface.

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
