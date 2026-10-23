# rawz terminology

- **CFA:** Color Filter Array, the sensor mosaic such as Bayer or X-Trans.
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

## Results, reach, and measured detection

The consumer contract is reconciled against Validate's committed terminology
at revision `c4f0a9e61953f9ab63e6c7dd5f684b035c1169d1`. File findings and
validator reach are separate evidence. The integration mapping is in
[`docs/validate_integration.md`](docs/validate_integration.md).

- **Finding:** A typed claim about bytes in the file, with a code, region, and
  offset. A malformed payload yields `sensor_validation.Result.fail`.
- **Reach:** Which applicable checks ran and what stopped further validation.
  Unsupported codecs, unavailable metadata, and explicit work limits do not
  establish corruption. They carry named structural reasons.
- **Structural:** Applicable validation or required evidence remains incomplete.
  This can include successful sensor syntax checks whose analytical ceiling
  has not been established.
- **Maximum Known Technically Possible (MKTP, or Max):** The exact variant is
  parsed to its declared end, every known objective invariant is checked, no
  applicable check is deferred, and the residual ambiguity is documented.
  Admission additionally requires ceiling analysis and mutation measurements,
  independent replay, a hashed specificity corpus, exhaustive checks, and a
  committed consumer ledger entry. rawz does not grant this label itself.
- **Full:** A consumer depth supported by its integrity-mechanism or measured
  detection evidence gates. A local payload API's `full` tag alone cannot
  establish whole-file depth.
- **Measured detection:** Detected mutations divided by applied trials for an
  exact corpus and mutation model. It remains separate from the verdict and
  depth; survivor counts and intervals do not prove an analytical ceiling.

The older `partial`, `deep`, and `strict` labels in the RAW inventory document
remain historical engineering categories, not additional consumer wire depths.
rawz preserves its published numeric error/reach codes and leaves display
labels, known-defect policy, ledger admission, and whole-file depth to Validate.
