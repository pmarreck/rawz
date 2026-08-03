# M2 Code Review

Reviewed 2026-08-01 after the first reviewer fan-out was OOM-killed. Peter
requested that the missing reviews be rerun; all 13 dimensions then ran
sequentially. The review covered the uncommitted M2 classifier and tiffz
adapter, including functionality, tests, test quality, performance,
duplication, clarity, complexity, file organization, Zig usage, memory, C FFI,
error handling, and database concerns.

## Result

The review reported 1 critical finding, 12 warnings, and 7 advisories. The
production findings were resolved before the M2 commit. Two dependency defects
remain assigned to tiffz and one real-corpus test remains in M5.

| Finding | Severity | Disposition |
|---|---:|---|
| Exif IFDs were skipped, hiding normal MakerNotes | Critical | Fixed with a failing ORF/Exif regression test and metadata-only Exif traversal |
| Reduced preview plus full RGB child could be called RAW | Warning | Fixed with a failing specificity case; rendered photometric children no longer satisfy the fallback layout |
| Classification had no C ABI | Warning | Fixed with append-only C status/format enums, pointer/error tests, and a compiled C integration test |
| Adapter error and allocation paths lacked tests | Warning | Added truncated offsets, malformed semantic tags, overflow, and a focused rawz allocator-failure test; broad dependency sweeping is blocked by the tiffz crash below |
| Big-endian and BigTIFF paths lacked coverage | Warning | Added classic big-endian and BigTIFF tests, including repeated out-of-line `LONG8` SubIFDs |
| Linked, nested, repeated, and cyclic IFD traversal lacked coverage | Warning | Added byte-level fixtures for each topology |
| Model fallback and vendor aliases lacked coverage | Warning | Added model-only, OM Digital, AOC, and Ricoh cases |
| Space-padding test was vacuous | Warning | Added reachable leading/trailing space padding without an earlier NUL |
| Offset discovery was O(N²) and pending storage could exceed the limit | Warning | Replaced linear scans and retained queues with one hash-indexed discovery set, purpose deduplication, an aggregate unique-offset limit, and a popped worklist |
| `LONG` Photometric narrowing could trap or truncate by build mode | Warning | Reproduced under ReleaseSafe, then removed the narrowing path; TIFF requires `SHORT` and other types now return a stable semantic-tag error |
| Malformed classification tags were treated as absent/present | Warning | Scalar, ASCII, MakerNote, DNGVersion, and Exif pointer shapes are now validated in every visited directory |
| Make/Model values over 128 bytes disappeared | Warning | Preserve a bounded 128-byte prefix from tiffz's parsed value cache; vendor classification needs only that prefix |
| Public errors were inferred from tiffz | Warning | Added the named `tiff_adapter.Error` set and an exhaustive dependency-to-rawz mapping |
| Real `pc260001.tif` did not pass through the byte adapter | Advisory | Deferred to M5, where a legally redistributable real or stripped corpus fixture will be acquired and license-checked |
| Linked/SubIFD location distinction was unused | Advisory | Collapsed both to semantic location `child` |
| Image and metadata traversal duplicated parse/cleanup logic | Advisory | Unified both as purpose-tagged pending work |
| Directory collection had 16 parameters | Advisory | Replaced the mutable argument bundle with `EvidenceAccumulator` |
| Hex fixtures are costly to maintain | Advisory | Accepted for M2; each fixture is small and byte-exact. A builder becomes worthwhile when the real corpus adds more synthetic shapes |
| ASCII trimming duplicated standard primitives | Advisory | Replaced with `std.mem.sliceTo` plus `std.mem.trim` |
| `rawz_version` ownership was undocumented | Advisory | Header now states that the borrowed string lasts for the process lifetime and must not be freed |

Dimensions 4 (speed/determinism), 8 (file organization), and 10 (memory) found
no additional issue. Dimension 13 found no database layer and was not
applicable.

The C integration test then exposed a Zig 0.16 cold-link problem: imported
system zlib metadata caused `libz.so` to be inserted into `librawz.a`. The build
now removes zlib from static-archive inputs and attaches `-lz` only to final
executables and named Zig modules. A direct archive listing confirms that
`librawz.a` contains only the relocatable rawz object.

## tiffz follow-ups

The pinned tiffz dependency is commit `d03c9d2`.

- `std.testing.FailingAllocator` index 3 crashes in
  `Decoder.openWithLimits` near `decoder.zig:80` while freeing invalid storage.
  This prevents a complete allocation-failure sweep through rawz. The focused
  rawz worklist failure test remains enabled.
- `Ifd.arrayElementU64` returns `UnsupportedTagType` for BigTIFF `IFD8` arrays.
  rawz tests the supported out-of-line `LONG8` representation, but standard
  `IFD8` SubIFDs need the decoding fix in tiffz to preserve the agreed
  container boundary.

## Independent controls

The classifier's sensitivity and specificity cases live in one set. Adapter
tests independently exercise raw TIFF bytes through tiffz, and the C test
compiles against the published header. Real-file sensitivity and differential
comparison against darktable/rawspeed remain the M5 and M6 controls; synthetic
fixtures do not substitute for those corpus results.

# M3 Code Review

Reviewed 2026-08-03 across the same 13 dimensions. Reviewers ran sequentially
to keep peak memory bounded. One reviewer exceeded its time bound without a
report; its bounded retry completed before the review moved on.

## Result

The rawz-side PEF migration is green after resolving every functional,
coverage, complexity, clarity, and error-domain finding. The remaining
ownership advisory is the planned validate-side cutover, so M3 stays open until
validate pins the exact rawz commit and removes its duplicate module.

| Finding | Severity | Disposition |
|---|---:|---|
| Packed size ignored per-row byte alignment for odd widths | Warning | Fixed with a 1×2 regression: three bytes truncate, four pass |
| Fixed-width lookup rejected a valid byte-padded final short code | Warning | Added non-consuming zero-padded peeks while retaining strict code and payload consumption |
| Misaligned Huffman ranges could cross prefixes or wrap | Warning | Require aligned, non-wrapping ranges and reject overlap |
| Successful Huffman coverage exercised only one zero-difference pixel | High | Added multi-row positive/negative differences, both predictor lanes, and pixel overflow |
| Code and difference-payload truncation were uncovered | Medium | Added final-bit cases for each distinct truncation path |
| Malformed table bounds had partial coverage | Medium | Added truncated layout, excessive code length, and out-of-domain code tests |
| Padded bit-reader boundaries were partial | Advisory | Added partial-position, exhaustion, zero-count, 32-bit, and exact-skip cases |
| Surplus packed bytes were an implicit contract | Advisory | Locked in acceptance of caller-owned trailing bytes |
| Public smoke test repeated decoder unit cases | Advisory | Reduced it to one export-reachability call |
| Huffman table representation hid invariants in a packed integer and reserved slot | Medium | Replaced it with named layout constants and `HuffmanEntry` fields |
| Module text called packed samples unpacked | Advisory | Corrected the module contract |
| Untrusted dimensions could authorize billions of decode iterations | Warning | Added `PefDecodeLimits`, a bounded default, and a caller-adjustable `max_pixels` gate |
| An unassigned compressed code was blamed on valid table metadata | Medium | Added append-only `InvalidHuffmanCode` distinct from `InvalidHuffmanTable` |
| Zero dimensions share `DimensionsTooLarge` with arithmetic overflow | Advisory | Retained for validate source/behavior compatibility; documented validation precedence |
| Lookup table uses about 8 KiB of stack | Advisory | Accepted: fixed-size, allocation-free, and safe on supported CLI targets; revisit for constrained-thread consumers |
| validate still compiles its local PEF decoder | High | Pending M3 cutover after rawz publishes an exact green SHA |

Tests are deterministic and allocation-free. Two timed ReleaseSafe runs in the
speed review completed in 0.409 and 0.423 seconds. Zig 0.16 formatting, casts,
shifts, wrapping predictor arithmetic, lookup bounds, and borrowed lifetimes
were clean. The stable C header and exported C symbols are unchanged. Database
and transaction concerns do not apply to these pure in-memory modules.
