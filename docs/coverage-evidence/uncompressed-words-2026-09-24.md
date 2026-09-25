# Uncompressed 12/14-bit word evidence, 2026-09-24

`uncompressed_sensor.validate16BitWords` checks an exact one-sample-per-word
payload in either byte order. It accepts 12- and 14-bit samples, rejects nonzero
unused high bits, and optionally enforces metadata-supplied black and white
levels. Missing levels produce the named structural reason
`metadata_levels_unavailable` after the complete headroom pass.

The real-file control is raw.pixls.us sample
`Nikon - D300 - 14bit 14bit uncompressed (3:2).NEF`, SHA-256
`0261523d0ab4694df0219404eb08af5db04697a05e85718e7f7bd42d283205f4`.
The repository API identified it as CC0 on 2026-09-24, and the downloaded file
matched the declared hash. Its sensor SubIFD contains 4352 by 2868 big-endian
14-bit samples across 410 contiguous uncompressed strips. The combined range
starts at file offset `704832`, is `24963072` bytes long, and ends exactly at
EOF.

`nef_sensor.locateSensorPayload` discovers and combines that range from the
TIFF SubIFD arrays; the caller does not hard-code the offsets. The same locator
classifies the 12-bit lossless-compressed D300 control, SHA-256
`7e6d38ddebe82784dc8c84cdf02dce7bcfe74b71b0dec91b28551936102c39b9`,
as `nikon_huffman` at file offset `700192` with byte count `10855480`.

The baseline completes the headroom pass and returns
`structural(metadata_levels_unavailable)`. Nikon does not expose usable
black/white bounds for this variant, so rawz does not promote it to full.
Seeded mutation measurements used xorshift64 seed 42:

| Damage | Detected | Trials | Method |
|---|---:|---:|---|
| Single-bit flip | 140 | 1000 | One uniformly selected payload bit flipped |
| Different-byte replacement | 348 | 1000 | One uniformly selected payload byte replaced by a uniformly generated different byte |
| EOF truncation | 100 | 100 | Remove 1 through 100 bytes from the combined sensor range |

The bit and byte misses are expected. Without level bounds, only the unused two
high bits of each 16-bit word carry an integrity signal; all 14-bit sample
values are syntactically valid. This scorecard does not cover packed samples,
row padding, compressed Nikon Huffman, or noncontiguous strips.
