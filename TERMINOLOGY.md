# rawz terminology

- **CFA:** Colour Filter Array, the sensor mosaic such as Bayer or X-Trans.
  TIFF `PhotometricInterpretation = 32803` identifies CFA data.
- **IFD:** Image File Directory, TIFF's tag and metadata block.
- **MakerNote:** Vendor-private metadata inside EXIF, commonly specific to a
  camera vendor or model.
- **Bit depth:** The number of meaningful sample bits. A 12- or 14-bit sensor
  sample may occupy a 16-bit storage word, leaving guaranteed-zero high bits.
- **Black and white levels:** Per-file declared bounds for meaningful sensor
  samples.
- **Compression variant:** A payload encoding within a RAW family. One filename
  extension may cover compressed and uncompressed variants with different
  corruption-detection properties.
- **Container:** The byte framing, directory, box, offset, and extent structure.
- **Sensor payload:** The undemosaiced samples and their vendor-specific
  compression or packing. Container and payload are orthogonal layers.

The canonical coverage-status expression and its depth ladder are defined in
[`docs/RAW_COVERAGE_AND_NOMENCLATURE.md`](docs/RAW_COVERAGE_AND_NOMENCLATURE.md).
