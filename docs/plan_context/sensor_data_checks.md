# Sensor-data checks for Validate full-depth promotion

Validate classifies DNG, CR2, CR3, NEF, ARW, RAF, ORF, RW2, and PEF as structural until every sensor-payload byte is interpreted by a check that can fail. Work proceeds per compression variant, never per extension.

## Required result

- Entropy-coded payloads receive a syntax pass through the declared end of stream. Desynchronization, overrun, or trailing mismatch returns `fail` with a stable error code and byte offset.
- Uncompressed 12- and 14-bit samples are checked for zero high bits and metadata-derived black/white bounds. A family is `full` only when every byte is covered; otherwise return `structural` with a reach reason.
- Every family and variant gets random-byte and end-of-file damage measurements from rawz. Validate independently remeasures before promotion.
- Sensor checks stop at syntax and sample-domain validity. Demosaicing and picture reconstruction remain excluded by `INTENT.md`.

## Delivery order

1. PEF, including removal of Validate's duplicate decoder and correction of PackBits compression 32773 versus Pentax Huffman compression 65535.
2. DNG, CR2, and compressed NEF lossless JPEG.
3. Uncompressed variants.
4. Sony ARW, Fuji RAF, Olympus ORF, and Panasonic RW2 compression syntax.
5. Canon CR3 after adding its ISO BMFF container, then CRX syntax.

After each family ships, send Validate the exact rawz commit, import path, stable result mapping, and measured coverage.
