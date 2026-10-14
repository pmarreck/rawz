# JPEG-independent RAW launch subset, 2026-10-14

## Recommended subset

The strongest current JPEG-independent launch subset is deliberately narrow:

1. Nikon D300 NEF, compression 34713, lossless table version `0x46`, at 12 or
   14 bits per sample.
2. Pentax K10D PEF, private compression `65535`, 12 bits per sample, with the
   supported AOC MakerNote Huffman table.

Both paths locate the exact sensor range, check the entropy stream through the
declared final sample, return typed failures with region-relative byte offsets,
and classify successful syntax as
`structural(analytical_ceiling_unestablished)`. Neither is an MKTP claim.

## Nikon version 0x46

The 12-bit control is raw.pixls.us CC0 sample `Nikon/D300/MMC_2824.NEF`, SHA-256
`7e6d38ddebe82784dc8c84cdf02dce7bcfe74b71b0dec91b28551936102c39b9`.
The recorded different-byte campaign detected 69 of 100 payload mutations and
all 100 EOF cuts. darktable 5.6.0/rawspeed accepted the pristine file and all
100 identically scheduled byte mutations; rawz rejected 69 streams that the
decoder concealed or tolerated. The 31 shared passes remain unexplained.

The 14-bit control is raw.pixls.us CC0 sample `Nikon/D300/MMC_2821.NEF`,
SHA-256
`8b989f53c96995f7014ddd16124530cf6d8f3341ea9570d6312d9da1eb0a117a`.
The current test pins the hash, accepts the pristine syntax through the final
sample, and rejects a one-byte EOF cut at the exact payload-relative offset.
This row has no mutation scorecard.

The classification correction shipped in rawz `c82afeed764defdea11bc69fef1733f99cbeb87c`.
Other Nikon metadata versions, lossy tables, split-row tables, and packed data
remain outside this subset.

## Pentax compression 65535

The control is raw.pixls.us CC0 sample
`Pentax - K10D - 12bit 12bit compressed (3:2).PEF`, SHA-256
`e35ae4154a468be3154f5f462e884ba5941f010d3e8f23d347fbec14809f44d3`.
The recorded different-byte campaign detected 97 of 100 payload mutations and
all 100 EOF cuts. Validate's independent single-bit campaign detected 84.5% of
sniper changes across the whole file with previews included; 31 survivors were
in the PEF strip. The byte-replacement and single-bit rates describe different
damage models and should remain separately labeled.

The supported path checks the bounded AOC MakerNote table, assigned Huffman
codes, predictor bounds, declared sample count, exact whole-byte end, and the
work ceiling. A missing table and a work ceiling are named reach. Other Pentax
MakerNote layouts and TIFF PackBits compression 32773 remain separate paths.

## Consumer reach

Validate's committed `yolo` branch currently pins rawz
`e05636dfe2e54dbbfc8324261bcd9f25b0c1412a`, dated 2026-10-08. That pin
predates the Nikon classification correction and the current Pentax
classification correction. Validate must consume the published rawz candidate
from this work before either exact subset has the result semantics described
above. Its current committed pin is evidence of integration reach, not
acceptance of this launch subset.

## Sony status

Sony ILCE-7M3 ARW 2.3.3 14-bit Compression 32767 now has packet validation and
exact single-strip CFA SubIFD discovery in the current rawz candidate. The
exact CC0 pristine file and one-byte EOF peer are exercised by the optional
fixture test. Successful syntax remains structural. This path was incomplete
before the locator landed, so it is reported separately from the two established
launch controls above until Validate consumes the published candidate.
