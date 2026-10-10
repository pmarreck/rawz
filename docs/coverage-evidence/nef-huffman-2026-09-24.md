# Nikon lossless-Huffman evidence, 2026-09-24

`nef_sensor.locateHuffmanMetadata` finds Nikon's `0x0096`
`NEFLinearizationTable` through the main Exif IFD and embedded MakerNote TIFF.
`nikon_huffman.validate` checks version-`0x46` 12- and 14-bit lossless streams
through the final declared sample. It rejects predictor escape, truncation,
trailing bytes, and malformed metadata. Inputs above the explicit sample-work
limit return structural reach.

The real control is raw.pixls.us sample `Nikon/D300/MMC_2824.NEF`, SHA-256
`7e6d38ddebe82784dc8c84cdf02dce7bcfe74b71b0dec91b28551936102c39b9`.
raw.pixls.us declared the file CC0 when fetched on 2026-09-24. The file matched
the repository hash. Its sensor payload is 4352 by 2868 at 12 bits, starts at
file offset `700192`, and occupies `10855480` bytes. The 46-byte table starts at
file offset `7920`; its predictor values use the parent TIFF's big-endian order.
At the recorded source revision, the unmodified stream returned `full`. The
2026-10-10 classification correction below supersedes that verdict without
changing the historical measurement.

ReleaseFast measurements used xorshift64 seed 42:

| Damage | Detected | Trials | Method |
|---|---:|---:|---|
| Different-byte replacement | 69 | 100 | One uniformly selected payload byte replaced by a generated different byte |
| EOF truncation | 100 | 100 | Remove 1 through 100 bytes from the sensor range |

darktable 5.6.0/rawspeed was executed as a black-box oracle in an isolated RAM
configuration. It decoded the baseline and all 100 identically scheduled byte
mutations. There were zero `rawspeed rejects + rawz passes` gaps. Rawz rejected
69 mutations that the production decoder concealed or tolerated. The 31 shared
passes remain unexplained survivors until a format rule or independent control
establishes that each is a legal alternate stream. The absence of a checksum
does not prove that no further objective syntax or metadata check applies.

This evidence qualifies the 12-bit version-`0x46` lossless variant. The 14-bit
table has deterministic synthetic coverage but no real-file scorecard yet.
Lossy tables, split-row tables, packed data, and other Nikon metadata versions
remain structural.

Validate independently repeated its whole-file D300 runs at source commit
`3dc478a2d` on 2026-09-25 with test-trust binary SHA-256
`597c837b732091ff50b673a16189838ac7e393b792ff3d40850004137b980108`.
The compressed control used seed `1790365110` and rejected 158/510 sniper
mutations (31.0%, 95% CI [27.1, 35.1]) plus 484/490 shotgun mutations (98.8%).
The uncompressed control used seed `1790365088` and rejected 64/501 sniper
mutations (12.8%, 95% CI [10.1, 16.0]) plus 495/499 shotgun mutations (99.2%).
Both seeds replayed exactly. These rates agree with rawz's seed-42 measurements
within their confidence intervals.

## 2026-10-10 classification correction and 14-bit control

Successful version-`0x46` 12- and 14-bit syntax passes now return
`structural(analytical_ceiling_unestablished)`. The validator still checks the
declared sample count, Huffman codes, predictor bounds, exact whole-byte end,
metadata bounds, and explicit work limit. The structural result states that
these checks have no established analytical ceiling or demonstrated
format-level residual class; it does not weaken any malformed-input verdict.

The added exact 14-bit control is raw.pixls.us sample
`Nikon/D300/MMC_2821.NEF`, SHA-256
`8b989f53c96995f7014ddd16124530cf6d8f3341ea9570d6312d9da1eb0a117a`.
The current raw.pixls.us record identified it as CC0 when retrieved on
2026-10-10. It is a 4352-by-2868 Nikon-compressed 14-bit D300 file. darktable
5.6.0/rawspeed accepted the pristine file as a black-box decoder. The
`darktable-cli` binary SHA-256 was
`763c9b14ab75e4e326098b8fd8cfef5e648b614d2fc1ee302dcdee1498c4883f`.
The no-seed command requested a 64-by-64 PPM, disabled custom presets, used an
isolated configuration and an in-memory library. Its output SHA-256 was
`5a6c415614c02fdcc347c4c8ad4493fe56aa0a9b1e06aa8ba82b820095311e61`.
Rawz accepts its syntax through the declared final sample with the structural
reach above. Removing the final sensor-payload byte returns
`fail(truncated)` in the payload region. This is one pristine row plus one
deterministic malformed control, not a mutation score or MKTP claim.
