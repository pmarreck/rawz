# Nikon lossless-Huffman evidence, 2026-09-24

`nef_sensor.locateHuffmanMetadata` finds Nikon's `0x0096`
`NEFLinearizationTable` through the main Exif IFD and embedded MakerNote TIFF.
`nikon_huffman.validate` checks version-`0x46` 12- and 14-bit lossless streams
through the final declared sample. It rejects predictor escape, truncation,
trailing bytes, malformed metadata, and inputs above an explicit sample limit.

The real control is raw.pixls.us sample `Nikon/D300/MMC_2824.NEF`, SHA-256
`7e6d38ddebe82784dc8c84cdf02dce7bcfe74b71b0dec91b28551936102c39b9`.
raw.pixls.us declared the file CC0 when fetched on 2026-09-24. The file matched
the repository hash. Its sensor payload is 4352 by 2868 at 12 bits, starts at
file offset `700192`, and occupies `10855480` bytes. The 46-byte table starts at
file offset `7920`; its predictor values use the parent TIFF's big-endian order.
The unmodified stream returns `full`.

ReleaseFast measurements used xorshift64 seed 42:

| Damage | Detected | Trials | Method |
|---|---:|---:|---|
| Different-byte replacement | 69 | 100 | One uniformly selected payload byte replaced by a generated different byte |
| EOF truncation | 100 | 100 | Remove 1 through 100 bytes from the sensor range |

darktable 5.6.0/rawspeed was executed as a black-box oracle in an isolated RAM
configuration. It decoded the baseline and all 100 identically scheduled byte
mutations. There were zero `rawspeed rejects + rawz passes` gaps. Rawz rejected
69 mutations that the production decoder concealed or tolerated. The 31 rawz
passes are valid alternate entropy streams under both validators; the format
has no checksum that could distinguish them from camera output.

This evidence qualifies the 12-bit version-`0x46` lossless variant. The 14-bit
table has deterministic synthetic coverage but no real-file scorecard yet.
Lossy tables, split-row tables, packed data, and other Nikon metadata versions
remain structural.
