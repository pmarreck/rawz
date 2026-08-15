# RAW coverage, the TIFF boundary, and a shared nomenclature

**Owner:** rawz (companion to `PROJECT_OVERVIEW.md`, `docs/validate_integration.md`,
and tiffz's `docs/tiff_raw_boundary.md`).
**Author:** validate (Mecha Validate coordinator), 2026-08-05.
**Status:** proposal for Peter's ratification. The container/payload model and
the capability ladder ratify what the fleet already converged on; the naming
scheme and the per-format gap matrix are new and are the parts to review.

This answers three questions Peter raised:

1. Is RAW a child of TIFF, or TIFF a child of RAW, or should TIFF cover all RAWs?
2. What does rawz need to reach structural and (where possible) deep validation
   of every known RAW format — and what is blocked by proprietary/licensing walls?
3. What nomenclature do we use across the fleet to describe these formats and how
   we address them (first-party vs. third-party, with licensing in view)?

The organizing spine is the gap between **what is hypothetically possible**,
**what our own fleet delivers today**, and **what third-party libraries add on
top** that we cannot ship.

---

## 1. The central question: RAW is not a child of TIFF (and TIFF is not a child of RAW)

Neither containment holds, because "RAW" and "TIFF" name things on two different
axes. A RAW file has two independent layers:

- **Container layer** — how the bytes are framed: byte order, directory/box
  structure, where each sub-image and metadata block lives.
- **Sensor-payload layer** — the "RAW" essence: the undemosaiced sensor samples
  and the vendor-specific compression/encoding over them.

Measured against our own fixtures and rawz's `CAPABILITIES.json`:

- The **container** is TIFF for the large majority (CR2, NEF/NRW, ARW, ORF, PEF,
  RW2, 3FR, IIQ, SRW, RWL, ERF, MOS, MEF), and DNG is TIFF/EP outright. A
  meaningful minority are **not** TIFF: CR3 is ISO BMFF (MP4-style boxes), CRW is
  Canon CIFF, RAF is a Fujifilm container, X3F is a Sigma/Foveon container, MRW
  is a Minolta container.
- The **payload** is almost always vendor-proprietary and is **not** something
  the TIFF standard defines. TIFF says "here is a strip/tile of bytes with
  Compression = N"; it does not define Canon's lossless-JPEG tiling, Nikon's
  Huffman, Sony's compression, Panasonic RAW, or Canon CRX.

So:

> **TIFF cannot "cover all RAWs."** It is not the container for CR3/RAF/X3F/CRW/MRW,
> and even where it is the container it does not define the sensor codec. And RAW
> is not a superset of TIFF either — a plain baseline TIFF has no sensor payload.

The correct relationship is **composition, not inheritance**:

```
            ┌─────────────── container layer ───────────────┐   ┌── payload layer ──┐
CR2   =   TIFF/EP container (tiffz)                              + Canon lossless JPEG
DNG   =   TIFF/EP container (tiffz)                              + {uncompressed | lossless JPEG | JXL}
NEF   =   TIFF container   (tiffz)                              + Nikon Huffman / uncompressed
CR3   =   ISO BMFF container (bmff parser — NOT tiffz)          + Canon CRX
RAF   =   Fujifilm container (rawz)                             + X-Trans stream
X3F   =   Sigma container   (rawz)                              + Foveon stream
```

This is exactly the boundary rawz already states: **standardized, publicly
specified container profiles → tiffz; proprietary, reverse-engineered vendor
semantics → rawz; rawz depends on tiffz for container parsing, never the
reverse.** DNG stays in tiffz because it is a public Adobe/TIFF-EP standard.
This document does not change that boundary; it names it and measures the gap
against it.

The dependency graph is acyclic and already fixed (`docs/validate_integration.md`):

```
Validate ──> rawz ──> tiffz-parser        (rawz reads container facts)
         ──> tiffz                          (full TIFF/DNG validator)
         ──> jpegz                          (JPEG-family payloads, incl. lossless JPEG)
```

Validate is the coordinator. tiffz never imports rawz. For non-TIFF containers,
the container parser (BMFF for CR3, CIFF/Fuji/Sigma/Minolta) lives **in rawz**,
beside the vendor-semantics code, because those containers exist only to carry a
proprietary payload — there is no standards body to hand them to.

---

## 2. Nomenclature

Four orthogonal descriptors plus one capability ladder. Every format is fully
described by picking one value on each axis. These harmonize the terms already in
use (rawz's `classification_state`/`validation_state`, validate's v1
`strict/partial/structural/unsupported/blocked`) into one vocabulary.

### 2.1 Container class — *who frames the bytes*

| Tag | Meaning | Parser owner |
|---|---|---|
| `tiff` | TIFF 6.0 / TIFF-EP / DNG and vendor TIFF variants (incl. non-0x2A magic like ORF `IIRO`, RW2) | **tiffz** |
| `bmff` | ISO Base Media File Format (MP4-style boxes) — CR3 | **rawz** (new BMFF parser) |
| `ciff` | Canon Camera Image File Format — CRW | **rawz** |
| `vendor` | Wholly proprietary framing — RAF, X3F, MRW | **rawz** |

### 2.2 Payload codec class — *the sensor essence*

| Tag | Meaning | Openness |
|---|---|---|
| `open-raw` | Uncompressed sensor samples, publicly specified layout | open |
| `open-ljpeg` | Lossless JPEG (ITU-T T.81 process 14) — CR2, most compressed DNG | open (patents expired) |
| `open-jxl` | JPEG XL — DNG 1.7+ | open standard |
| `re-entropy` | Reverse-engineered vendor entropy coding (Huffman/arithmetic) — NEF, ORF, ARW, RW2, IIQ, CRX, X-Trans, Foveon | RE required |
| `re-packed` | Reverse-engineered packed/PackBits variants — PEF, some NEF | RE required |

### 2.3 Validation depth — *how deep the check goes* (the ladder)

Ordered weakest → strongest. This is the single ladder; drop the old
`classification_state` vs `validation_state` split into it.

| Rung | Name | What it proves | MFIC character |
|---|---|---|---|
| 0 | `blocked` | nothing — no container parser exists, cannot even attempt | — |
| 1 | `unsupported` | format recognized, but **no corruption verdict produced** | — |
| 2 | `structural` | container/IFD/box walk, tag sanity, offset+extent bounds; payload **not** decoded | offset/extent bounds are exact and falsifiable |
| 3 | `partial` | structural **plus** some payload checks, with **named** gaps | mixed |
| 4 | `deep` | sensor bitstream decoded far enough to desync on corruption (entropy validity, bit-depth headroom, black/white-level range) | decode-desync + headroom are exact, oracle-free |
| 5 | `strict` | full supported structure **and** full sensor payload verified | strongest |

`strict` and `deep` differ only in completeness: `deep` catches payload
corruption but may leave a named structural or variant gap; `strict` has none.

### 2.4 Source / shippability — *who provides it and can we ship it*

| Tag | Meaning |
|---|---|
| `first-party` | tiffz / rawz / jpegz — pure-Zig, shippable in the production closure |
| `oracle-only` | libraw / rawspeed / exiftool — **dev/test only**, excluded from the shipped binary by the first-party-closure gate |
| `unattainable` | no path today from any source (missing samples, or a hard legal wall) |

### 2.5 Writing a format's status

`<container>/<payload>/<depth>@<source>`. Examples:

- CR2 ceiling: `tiff/open-ljpeg/deep@first-party` (achievable with zero RE).
- CR2 today: `tiff/open-ljpeg/unsupported@first-party` (payload not yet wired).
- CR3 ceiling: `bmff/re-entropy/deep@first-party` (needs BMFF + CRX RE).
- CR3 today: `bmff/re-entropy/blocked@first-party` (no BMFF parser yet).
- Any of them, right now via oracle: `.../deep@oracle-only` (libraw decodes it —
  but we can't ship libraw).

### 2.6 Per-file validation-ID (Peter, 2026-08-06)

A concrete file gets a **validation-ID**, extending the type descriptor with a
leading filetype token and the path:

```
<filetype>/<container>/<payload(s)>/<depth>@<path>
```

- `docx/zip/xml/full@some/word.docx`
- `epub/zip/xhtml+css/full@book.epub`
- `pdf/pdf/flate+dct/structural-due-to-encryption@scan.pdf`
- `nef/tiff/nikon-huffman+jpeg/structural@DSC_1234.NEF`

(When a format is its own container — PDF — `filetype == container`.)

**What is and isn't identity.** Only `filetype` is 1:1 with the header/magic
fingerprint — it is what a byte-sniff resolves to. `container` is almost always
implied by `filetype` (nef⇒tiff, docx⇒zip, cr3⇒bmff). But `payload(s)` and
`depth` are **per-file observations, not derivable from the header**: a DNG's
payload may be uncompressed, lossless-JPEG, or JXL; a NEF's may be Huffman or
uncompressed; a PDF's is whatever stream filters it actually contains. So the
pre-`@` prefix as a whole describes *this file*, not the type. If we ever key a
cache or a marketing claim off "the type," the stable key is `filetype`
(± `container`), never the full prefix.

**Multi-payload files take the weakest link.** One file can carry several
payloads that reach different depths: a NEF's embedded preview JPEG can be `deep`
(jpegz) while its sensor stream is only `structural`. List the payloads
(`nikon-huffman+jpeg`); the file-level `depth` is the **minimum** across them.
Per-payload depths live in the findings, not the ID.

### 2.7 Depth has three dimensions

The §2.3 ladder is measured at three points, and they are not the same number:

| Dim | Question | Lives in |
|---|---|---|
| **D1 ceiling** | strongest depth *hypothetically* possible for this format | the matrix (§4), per format |
| **D2 current-code** | strongest depth *our shipped code* reaches for this format | `CAPABILITIES.json`, per format |
| **D3 attained** | depth *actually reached on THIS file* | the validation-ID `depth` token |

`D3 ≤ D2 ≤ D1`. D3 drops below D2 only for a **file-specific** reason
(encryption, truncation, an unsupported variant of an otherwise-supported
family), and the token then names the reason: `structural-due-to-encryption`,
`partial-due-to-truncation`. When `D3 == D2` there is no suffix.

**Encryption is not automatically a ceiling — the reason must be real.**
- A PDF with **blank-password encryption** (empty user password) is decryptable
  with the empty key, so its streams *are* validatable → it still reaches `full`,
  **not** `structural-due-to-encryption`. Only a genuinely locked file (non-empty
  user password, no key available) forces the drop.
- Same principle for any "protected" wrapper that is openable by construction.

The gap model in §3 is exactly **D1 − D2** (the roadmap) and **D2 − D3** (per-file
honesty).

---

## 3. The gap model

For every format, three positions on the ladder:

- **Ceiling** — the strongest depth **hypothetically** attainable, and by whom.
  "Hypothetical" folds in reverse-engineering effort as *possible* (RE for
  interoperability is legal — see §5), so the ceiling is limited only by physics
  (is the information present and decodable?) and by hard legal walls, not by how
  much work it is.
- **First-party now** — what tiffz + rawz + jpegz deliver today
  (from `CAPABILITIES.json`, dated to this commit).
- **Third-party delta** — what libraw/rawspeed give **over and above** first-party
  now. For nearly every format this is *full decode → `deep`*, available today —
  but `oracle-only`, so it defines the ceiling and serves as the differential
  test oracle, and cannot ship.

The gap that matters for the roadmap is **ceiling − first-party-now**. The
third-party delta measures **how much of that gap someone has already climbed**,
which is why libraw/rawspeed are the differential oracles: mutate a known-good
RAW, and where the oracle rejects but we pass, that is precisely our open gap.

---

## 4. Master matrix

Container/payload from rawz `CAPABILITIES.json` + empirical exiftool on our
fixtures. "Now" = first-party today. "3P" = third-party (libraw/rawspeed) delta,
all `oracle-only`. Legality flags in §5.

| Format | Container | Payload | Structural ceiling | Deep ceiling | First-party **now** | 3P delta (oracle) | Flag |
|---|---|---|---|---|---|---|---|
| **DNG** | `tiff` | `open-raw`/`open-ljpeg`/`open-jxl` | `structural` first-party (tiffz) | **`deep` first-party, no RE** (jpegz ljpeg + libjxlz JXL) | `partial` (tiffz structure; payload not fully checked) | full decode | **open** — flagship |
| **CR2** | `tiff` | `open-ljpeg` | `structural` first-party | **`deep` first-party, no RE** (jpegz lossless JPEG) | `unsupported` (structure via tiffz; payload not wired) | full decode | **open** |
| **PEF** | `tiff` | `re-packed`/`re-entropy` | `structural` first-party | `deep` first-party (RE; in progress) | `partial` (bounded packed-12 + sparse Huffman slice) | full decode | RE |
| **NEF / NRW** | `tiff` | `re-entropy`/`open-raw` | `structural` first-party | `deep` first-party (RE) | `unsupported` (semantic classification only) | full decode | RE + Nikon WB-encryption caveat |
| **ARW / SR2 / SRF** | `tiff` | `re-entropy` | `structural` first-party | `deep` first-party (RE) | `unsupported` | full decode | RE |
| **ORF / ORI** | `tiff` | `re-entropy` | `structural` first-party | `deep` first-party (RE) | `unsupported` | full decode | RE + "uncompressed" tag lies (Olympus Huffman) |
| **RW2 / RAW** | `tiff` | `re-entropy` | `structural` first-party | `deep` first-party (RE) | `unsupported` | full decode | RE |
| **3FR / FFF** | `tiff` | `re-entropy` | `structural` first-party | `deep` first-party (RE) | `unsupported` | full decode | RE |
| **IIQ** | `tiff` | `re-entropy` | `structural` first-party | `deep` first-party (RE) | `unsupported` | full decode | RE |
| **SRW** | `tiff` | `re-entropy` | `structural` first-party | `deep` first-party (RE) | `unsupported` | full decode | RE |
| **RWL** | `tiff` | `open-raw`/`re-entropy` | `structural` first-party | `deep` first-party (mostly DNG-like) | `unsupported` | full decode | mostly open (Leica ≈ DNG) |
| **ERF / MOS / MEF** | `tiff` | `re-entropy` | `structural` first-party | `deep` first-party (RE) | `unsupported` | full decode | RE |
| **CR3** | `bmff` | `re-entropy` (CRX) | `structural` first-party **once BMFF parser exists** | `deep` first-party (BMFF + CRX RE) | `blocked` (no BMFF parser) | full decode | RE (container + codec) |
| **RAF** | `vendor` | `re-entropy` (X-Trans) | `structural` first-party (RAF parser) | `deep` first-party (RE) | `blocked` | full decode | RE (container + codec) |
| **CRW** | `ciff` | `re-entropy` | `structural` first-party (CIFF parser) | `deep` first-party (RE) | `blocked` | full decode | RE (legacy) |
| **X3F** | `vendor` | `re-entropy` (Foveon) | `structural` first-party (X3F parser) | `deep` first-party (RE, hard) | `blocked` | full decode | RE (container + Foveon) |
| **MRW** | `vendor` | `re-entropy` | `structural` first-party (MRW parser) | `deep` first-party (RE) | `blocked` | full decode | RE (legacy) |

Long tail not in the v1 matrix (GPR, DCR/KDC, BAY, CAP/EIP, NKSC sidecars, etc.)
are almost all DNG- or TIFF-derived and fold into the `tiff` container row; GPR is
DNG outright (`tiff/open-*`, first-party ceiling `deep`, no RE).

**Reading the matrix:** the structural ceiling is `first-party` for *every* format
— for `tiff`-container ones it is reachable **now** (only dispatch wiring is
missing), and for the five non-TIFF ones it needs a container parser first. The
deep ceiling is `first-party` for every format too; for `open-*` payloads (DNG,
CR2, GPR, Leica) it needs **no reverse-engineering at all**, and for the rest it
needs clean-room RE whose only cost is effort and sample availability.

---

## 5. Licensing and legal analysis

### 5.1 Third-party libraries (why they are oracle-only, not shippable)

| Library | License | Posture |
|---|---|---|
| **libraw** | LGPL-2.1 **OR** CDDL-1.0 (dual) | Shipping either carries obligations (LGPL: dynamic-link + relink freedom; CDDL: weak file-level copyleft). The v1 first-party-closure gate deliberately keeps it **out of the shipped binary**. Superb decode oracle for dev/test. |
| **rawspeed** (darktable) | LGPL-2.1 | Same posture. 79 makers / 1,389 models — the broadest differential oracle we have. |
| **dcraw** | effectively public domain (Dave Coffin), frozen | The original RE reference; historical. libraw is its maintained successor. |
| **exiftool** | Perl (Artistic/GPL) | Metadata/container **identification** oracle only; not a decoder. |

None of these are legally unusable — they are **chosen out** of production to keep
the closure first-party (Einstein v1 item 6). They remain in `CAPABILITIES.json`
under `dev_test_oracles_only` and are the backbone of differential MFIC testing.

### 5.2 Are any RAW formats legally off-limits to reimplement?

**No — with two narrow caveats.**

- **File formats are not copyrightable** (US), and **reverse-engineering for
  interoperability is settled law** (Sega v. Accolade; Sony v. Connectix). A
  clean-room rawz decoder for any vendor codec is legally sound. "Proprietary /
  undocumented" means *we must RE it from samples*, **not** *we may not*.
- **Caveat 1 — Nikon white-balance encryption (NEF).** Some NEFs encrypt the
  **white-balance metadata** (the 2005 dcraw/Nikon episode raised DMCA §1201).
  This does **not** block us: the **sensor payload is not encrypted**, and WB is
  color science (explicitly out of rawz's scope). We validate the sensor stream
  and never touch the encrypted WB block, so no circumvention occurs.
- **Caveat 2 — patents.** Lossless JPEG (T.81) is long expired → CR2/DNG safe.
  JPEG XL is royalty-free by design → DNG-JXL safe. No patents are known to be
  asserted against clean-room decoders of vendor RAW entropy codecs; flag as a
  watch item, not a current blocker.

**Genuinely `unattainable` today** reduces to: (a) formats for which we have **no
sample corpus** to RE against, and (b) any future format that ships real payload
encryption (none of the professional set does for the sensor data). Nothing in
the v1 matrix is legally blocked.

---

## 6. What rawz needs, ordered by leverage

Ranked by (gap closed × corpus prevalence) ÷ effort. Each rung is TDD-first with
the libraw/rawspeed differential oracle.

### Tier 0 — free deep coverage, zero reverse-engineering (do first)
- **DNG + CR2 deep via jpegz.** Both payloads are lossless JPEG (our DNG fixture
  decodes as JPEG, CR2 as old-style/lossless JPEG). jpegz already decodes lossless
  JPEG. Wiring the tiffz strip/tile view → jpegz turns **DNG `partial`→`deep`** and
  **CR2 `unsupported`→`deep`** with no RE and no licensing risk. This is the single
  highest-value move and makes DNG the fully-first-party flagship.
- **DNG 1.7 JXL payloads via libjxlz-through-jpegz** (same seam), once libjxlz's
  strict verdict is sound (currently unsound — see its coverage gameplan).

### Tier 1 — cheap, format-independent, exact
- **Bit-depth-headroom + level-range check.** For any uncompressed or decoded
  sensor array: assert the high `(16 − bit_depth)` bits are zero across all samples
  and every sample lies in `[black_level, white_level]` from metadata. One pass,
  no checksum, oracle-free, machine-independent. Turns several `unsupported`
  uncompressed variants (NEF-uncompressed, NRW, some ORF) into `partial`
  immediately. Guard on **real** bit depth and **real** layout (the ORF
  "uncompressed"-tag lie).

### Tier 2 — vendor entropy deep (clean-room RE, ordered by prevalence)
Nikon NEF Huffman → Sony ARW → Olympus ORF Huffman → Panasonic RW2 → Pentax PEF
(finish) → Phase One IIQ → Samsung SRW → Hasselblad 3FR. Each is a clean-room
entropy decoder giving decode-desync corruption detection; each promotes its
family `unsupported`→`deep`.

### Tier 3 — non-TIFF containers (unblock structural first, then deep)
- **BMFF parser for CR3** (highest value — modern Canon), then CRX RE for deep.
- **RAF** (Fuji) container + X-Trans, **CRW** (CIFF), **X3F** (Foveon, hard),
  **MRW** (Minolta). Each moves its family `blocked`→`structural`, then `deep`
  with codec RE.

### Cross-cutting invariants (apply at every rung)
- Findings carry a stable machine code, severity, and **both** payload-relative and
  host-relative byte offsets with an exact/inexact flag (validate localizes on the
  code; the English string is fallback). Do not collapse distinct failures.
- Reads clamp to the declared sub-range (`tiffz Source.fromSubrange`); never touch
  adjacent host bytes.
- Every promotion ships with a differential-oracle scorecard (known-good,
  known-bad, sniper/bolter/shotgun) and a specificity corpus, per MFIC.

---

## 7. Recommendation and open decisions for Peter

**Ratify:** the container/payload two-layer model and the boundary as stated —
tiffz owns `tiff` containers (incl. DNG), rawz owns non-TIFF containers + all
vendor payload semantics, jpegz owns the lossless-JPEG/JXL sensor payloads that
DNG and CR2 happen to use. This is the acyclic graph already in place; nothing
moves.

**The one strategic decision the matrix surfaces:** the fastest, lowest-risk RAW
coverage is not more reverse-engineering — it is **wiring the open payloads (DNG,
CR2) to jpegz** (Tier 0) and the **bit-depth-headroom check** (Tier 1). Those two
alone convert the biggest, most professionally common families from
`unsupported`/`partial` to `deep`/`partial` with zero licensing exposure, before
any vendor RE.

**Decisions (Peter, 2026-08-06):**

1. **Launch RAW posture — ship honest partial, promise the rest.** DNG/CR2 →
   `deep` after Tier 0; other TIFF-RAW → `structural` (tiffz) + headroom
   `partial`; CR3/RAF/CRW/X3F/MRW → `structural` once their container parsers
   land, else `unsupported`. Labels stay honest; missing depth is advertised as
   "coming," never hidden. Partial-but-honest RAW support is still useful.
2. **Wire DNG + CR2 to jpegz (Tier 0) — approved, do it.**
3. **libraw is oracle-only until v1, then CUT — enforced by physics, not
   memory.** A v1.0 release declaration that *will not compile* if any
   oracle-only decoder is linked (see §8). The forbidden set is deliberately
   extensible.
4. **CR3 / BMFF parser is a v1 must-have** (pro-photographer clientele; CR3 is
   Canon's current RAW). Rationale + cost-reducer in §7.1.

### 7.1 Why CR3 is a v1 must-have (business)

Canon is the #1 camera brand, and every current Canon mirrorless (R-series) and
recent DSLR writes **CR3, not CR2** — CR2 is the pre-2018 legacy format.
Advertising "RAW validation for photographers" while silently excluding current
Canon bodies is a credibility hole precisely with the audience being courted. The
marquee pro brands are Canon (CR3), Nikon (NEF), Sony (ARW); the pitch is deep
pro-format coverage, and CR3 is load-bearing for it. So yes — maximal RAW
coverage is the bootstrap lever, and CR3 is non-negotiable for it.

**Cover BOTH CR2 and CR3 (Peter, 2026-08-11).** CR2 (pre-2018 Canon, legacy
archives) stays a first-class Tier-0 deep target via jpegz lossless JPEG; CR3
(current Canon) is the new must-have. Legacy-data validation is a selling point,
so CR2 is not dropped in favor of CR3 — both ship.

**Cost-reducer:** the ISO BMFF box parser is **not** net-new to the fleet —
validate already parses BMFF (`src/core/mp4_box_parser.zig`,
`heif_container_parser.zig` for MP4/MOV/HEIF/AVIF). rawz cannot depend on validate
(validate is the top of the graph), so the economical path is to extract a shared
**`bmffz`** core that both consume, leaving only **CRX codec RE** as genuinely new
work. Ship **CR3 `structural`** at v1 (BMFF walk + CRX stream extent), **CRX
`deep`** as an honest fast-follow — which fits the §7.1 posture exactly.

**`bmffz` coordination (proposed, Peter to confirm):** the validate session drives
the extraction — the source lives in validate and validate's MP4/MOV/HEIF/AVIF
suite is the behavior-preservation oracle (extract, tests stay green byte-for-byte;
the `mini_blar`-from-BLIP precedent). Standard fleet shape: pure-Zig box core → C
FFI → C CLI. validate rewires to consume it first; then rawz consumes it for CR3
and jpegz for the JXL/HEIF ISOBMFF container. BMFF underlies MP4/MOV, HEIF/HEIC/
AVIF, CR3, and the JXL container, so the extraction pays for itself fleet-wide.

---

## 8. The v1.0 production-closure hard-gate (physics over policy)

Peter's rule: a v1.0 declaration that **will not compile** if a forbidden
production dependency is present — the constraint enforced by the compiler and the
package graph, not by an agent remembering a policy that dies at context
compaction.

**Layer 1 — comptime `@compileError` (physics in the compiler).** A release
module gated on build options:

```zig
// src/core/v1_closure.zig
const forbidden = @import("build_options").production_forbidden; // set by build.zig
comptime {
    if (forbidden.libraw)        @compileError("v1.0 forbids libraw in the production closure (oracle-only). Build the -Doracle profile for dev/test.");
    if (forbidden.openjpeg)      @compileError("v1.0 forbids openjpeg — route JPEG2000 through jpegz strict.");
    if (forbidden.libjpeg_turbo) @compileError("v1.0 forbids libjpeg-turbo — jpegz is pure-Zig at -Dwith-libjpeg-oracle=false.");
    if (forbidden.rawspeed)      @compileError("v1.0 forbids rawspeed (LGPL) in production.");
}
```

`build.zig` sets each flag from whether the corresponding artifact is actually in
the production module graph, so a *future* re-addition flips the flag and the
build fails with a message that names the fix. The default `./build` target is the
production profile; a separate explicit `-Doracle=true` dev/test profile is the
only way to pull the oracle libraries in, and it is not shippable.

**Layer 2 — Nix runtime-closure audit (physics in the package graph).** The
release check greps the shipped ELF/Mach-O load metadata and the complete Nix
runtime closure for any forbidden store path (libraw, openjpeg, libjpeg, jxl,
rawspeed, and any C decoder the fleet has replaced) and fails if one appears. rawz
and jpegz already run this class of gate; validate adopts the same for its final
binary.

**The forbidden set is a control file** (MFIC): a small, explicitly-named list in
one place, blessed-hashed so any edit is a conspicuous two-file diff Peter
eyeballs. It starts as the `dev_test_oracles_only` set (libraw, rawspeed) plus the
C image libs being retired (openjpeg, libjpeg-turbo) and **grows** as more
first-party replacements land — every addition is a decoder we made unnecessary.
That growth is the point Peter flagged: the list getting longer is the launch
getting cleaner.

---

*Cross-references: rawz `PROJECT_OVERVIEW.md` (boundary doctrine, terminology),
rawz `docs/validate_integration.md` (acyclic graph, offset contract), tiffz
`docs/tiff_raw_boundary.md` (authoritative boundary), rawz `src/CAPABILITIES.json`
(machine-readable current state), validate v1 capability contract.*
