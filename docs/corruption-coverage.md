# Corrupt-input coverage measurement

`./corruption-coverage` measures whether rawz rejects deterministic corruptions
of one or more known-good RAW files. It calls corruption-reader's consumer CLI
at the pinned upstream revision and runs exactly four built-in profiles:

| Profile | Mutation |
|---|---|
| `sniper` | Flip one random bit anywhere in the file. |
| `bolter` | Flip every bit in one random byte. |
| `shotgun` | Flip 16 distinct random bits in one random 32-byte window. |
| `nuke` | Replace one random 4096-byte window with seeded random bytes; the built-in profile fits the window to smaller inputs. |

The pristine file must first produce an accepted rawz verdict. A rejected
control aborts the campaign, so a false positive cannot become a detected
corruption. Each applied mutation is streamed from corruption-reader into the
rawz probe. The script never creates a batch of mutated RAW files.

```sh
./corruption-coverage camera.ARW
./corruption-coverage --json --master 42 camera.ARW camera.NEF > coverage.jsonl
./corruption-coverage --count 100 --round-start 385 camera.ARW
```

The default is 385 trials per profile and fixture. Every result reports the
observed rejection rate and a two-sided 95% Wilson score interval. At 385
trials, the interval's worst-case half-width is below 0.05. Smaller requested
campaigns remain valid exploratory measurements but report
`precision_target_met: false`. This is interval estimation, not a hypothesis
test. The interval model treats distinct seeded rounds as independent draws
from the named profile's location and mutation distribution.

The master seed, profile and round reproduce each corruption. JSON output
records every surviving round, the pristine SHA-256, file size, exact pristine
verdict, counts, interval and precision flag. A survivor means rawz accepted
that mutated byte stream. It does not prove that the resulting RAW is
semantically valid or visually unchanged.

The score is specific to the exact file, rawz revision, corruption-reader
revision, profile, seed and round range. The four profiles choose locations
across the complete file, so their rates include headers, metadata, previews,
padding and sensor data in proportion to the chosen mutation model. They do
not estimate payload-only coverage.

The full-file probe currently routes Sony ARW2 and Nikon NEF through their
first-party payload checks when the required metadata is available. Other
recognized TIFF-family RAW formats receive rawz's current container and
classification checks and return a named structural reach. Their measured
rates must not be presented as entropy-decoder coverage. The campaign also
does not compare rawz with rawspeed or another decoder; differential validity
evidence remains a separate requirement.

Operational failures never count as detections. corruption-reader errors,
no-op reports, malformed probe output and probe failures abort the campaign.
Parser work limits return the existing `RAWZ_STATUS_LIMIT_EXCEEDED` call
status without writing a verdict; the probe exits 2 and the campaign produces
no score for that profile.
The internal probe is a C consumer of `rawz_validate_buffer`, so the
measurement exercises the same public ABI available to external consumers.

`./test` runs the probe and campaign regressions through the sandboxed Nix
`checks.<system>.coverage-cli` target. Mechatron Prime CI runs this target too.
Each check builds its own ReleaseSafe probe rather than reusing a shared
`zig-out` product or a command found on PATH.
