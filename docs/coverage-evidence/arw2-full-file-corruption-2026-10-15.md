# Sony ARW2 full-file corruption measurement, 2026-10-15

The control is raw.pixls.us sample 2414, redistributed byte-for-byte as
`Sony-a7III.ARW` by the CC0
[`revelraw-sample-raw-files`](https://github.com/tellodaniel/revelraw-sample-raw-files)
set. Its SHA-256 is
`250784580ea527442c09004417bb0eead484f2bf3ee8f9121a776ac65bb50d0f`
and its size is 25,639,680 bytes. The pristine file reached Sony ARW2 packet
validation and returned
`structural(analytical_ceiling_unestablished)`.

`./corruption-coverage --json --master 42` ran 385 applied cases for each
corruption-reader 0.7.0 profile. The rawz candidate used corruption-reader
commit `21ee639537644c81ada3e780c19608817dda92ca`. Every interval below is a
two-sided 95% Wilson score interval.

| Profile | Detected | Applied | Rate | 95% interval |
|---|---:|---:|---:|---:|
| `sniper` | 7 | 385 | 1.82% | 0.88%–3.70% |
| `bolter` | 31 | 385 | 8.05% | 5.73%–11.20% |
| `shotgun` | 119 | 385 | 30.91% | 26.50%–35.69% |
| `nuke` | 364 | 385 | 94.55% | 91.81%–96.41% |

The complete JSON Lines receipt, including every survivor round, is
[`data/arw2-corruption-coverage-2026-10-15.jsonl`](data/arw2-corruption-coverage-2026-10-15.jsonl).
Each case is replayable from profile, master 42 and round. An explicit replay
confirmed that sniper round 0 remained accepted and round 5 failed with
`invalid_packet_header` at payload-relative byte 19,173,920. Their recorded
case seeds were respectively
`75ae3fd5d076b7bcb0736c973b1c2af6443f6c0e6e8ab55b8ac18a0b358e47a3`
and
`2f0ae3cceade3ed35a799dcaa54dc011740b6651e9b691f475e85304004959ad`.

This is an end-to-end, whole-file rejection measurement for one exact file.
It is not a sensor-payload-only rate, a false-negative rate against an
independent decoder, or an analytical detection ceiling. A survivor can be a
legal alternate byte stream, an unchecked corruption, or damage outside the
currently checked regions. The pristine gate establishes specificity only for
this supplied control. The independent corruption scheduler prevents rawz from
choosing favorable mutation positions; it does not decide whether a surviving
file remains semantically or visually valid.
