# rcicrdiagnostics: user's guide

## 1. What this package is

Reverse correlation (RC) experiments let you visualise a participant’s
mental representation — for example, what their mental image of
“trustworthy” looks like — by averaging the noise patterns the
participant chose across many trials. The end product is a
**classification image (CI)**, and a common summary of the CI’s quality
is the **information value (infoVal)**: roughly, how much real signal is
in the CI versus chance (Brinkman et al., 2017, 2019).

These pipelines can fail quietly. A response column coded `{0, 1}`
instead of `{-1, 1}`, a stimulus-number column that is off by one, a
noise-matrix file whose dimensions don’t match the response data — any
of these produces a CI that *looks* plausible but is wrong. R doesn’t
catch these problems and neither does the `rcicr` package, because the
errors live in the *match* between your response data and the files that
generated the stimuli.

`rcicrdiagnostics` is a toolkit of data-quality checks you run on your
data **before** computing any CI or infoVal. If a check fails, fix the
data; if it warns, investigate; if everything passes, you can compute
CIs knowing the basic data mechanics are in order.

The package supports two pipelines through a single `method` argument:

- **`"2ifc"`** — the standard two-image forced-choice pipeline, as
  implemented by the [`rcicr`](https://github.com/rdotsch/rcicr) package
  (Dotsch, 2016, 2023). On each trial the participant picks one of two
  noisy faces.
- **`"briefrc"`** — the Brief Reverse Correlation pipeline (Schmitz et
  al., 2024). On each trial the participant picks one noisy face out of
  6, 12, or more. CIs are computed by direct noise-matrix multiplication
  rather than by reconstructing sinusoids from a generating `.RData`
  file.

You only need to know *your* pipeline to use this package. The checks
use the right logic automatically once you set `method`.

## 2. Installation and requirements

### R version

R 4.1 or newer.

### Packages installed automatically

`rcicrdiagnostics` has only two hard dependencies, both on CRAN:

- [`data.table`](https://rdatatable.gitlab.io/data.table/) — a fast
  alternative to base R’s `data.frame`, used internally for counting and
  grouping. You don’t need to learn its syntax to use this package.
- [`cli`](https://cli.r-lib.org/) — used to format console messages with
  colour.

### Optional packages (needed only for the 2IFC infoVal-based checks)

Sections 6.9–6.11 (infoVal, inversion detection, RT × infoVal) delegate
the 2IFC path to the original `rcicr` package (Dotsch, 2016, 2023).
**They return a `"skip"` result for Brief-RC** — see Section 6.9 for
why. If you want the 2IFC infoVal checks, install `rcicr`. From Dotsch’s
own install instructions:

``` r
# Latest stable version (from CRAN if still hosted):
install.packages("rcicr")

# Latest dev version from GitHub:
install.packages("devtools")
devtools::install_github("rdotsch/rcicr")
```

At the time of writing, the original `rcicr` is version 1.0.1 (2023),
maintained by Ron Dotsch on
[github.com/rdotsch/rcicr](https://github.com/rdotsch/rcicr).

- `foreach`, `tibble`, and `dplyr` — `rcicr` uses operators and helpers
  from these packages at runtime (`%dopar%`, `tribble`, `%>%`). The
  package will attach them for you on the first infoVal-dependent call,
  but they need to be installed:

  ``` r
  install.packages(c("foreach", "tibble", "dplyr"))
  ```

All the other checks (Sections 6.1–6.8) work without `rcicr`.

### Installing the package

`rcicrdiagnostics` is distributed from GitHub (not CRAN):

``` r
# install.packages("remotes")
remotes::install_github("olivethree/rcicrdiagnostics")
```

Or with `pak`:

``` r
# install.packages("pak")
pak::pak("olivethree/rcicrdiagnostics")
```

Confirm it loaded:

``` r
library(rcicrdiagnostics)
packageVersion("rcicrdiagnostics")
#> [1] '0.2.0'
```

## 3. What data the package expects

This section is the data-preparation reference. Get the inputs right and
the rest of the package just works; get them wrong and the diagnostics
will tell you, but only after you have already collected the data.

### 3.1. Response data (both pipelines)

The package expects a trial-level data object (one row per trial). It
can be a `data.frame`, a `data.table`, a `tibble`, or any object that
behaves like a data frame in R. The original source can be a CSV, an
RData file, a Parquet file, a database query, or constructed
programmatically. Whatever the source, by the time it reaches the
diagnostic functions it is a tabular object with the columns described
below.

| Column           | Purpose                                                                                                                                                                                                                                               |
|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `participant_id` | Identifier for each participant. Character or integer.                                                                                                                                                                                                |
| `stimulus`       | Stimulus number. Must match the numbering used when stimuli were generated (see §3.4 and §3.5).                                                                                                                                                       |
| `response`       | Participant’s response on that trial. Coding depends on method (see §3.2).                                                                                                                                                                            |
| `rt` (optional)  | Response time in milliseconds. Used by [`check_rt()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_rt.md) and [`cross_validate_rt_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/cross_validate_rt_infoval.md). |

If your column names differ, every function accepts overrides via
`col_participant`, `col_stimulus`, `col_response`, and `col_rt`.

### 3.2. Response coding by method

**`"2ifc"`**: `response` must be numeric `{-1, +1}`. The sign matters
because the CI is a weighted sum of per-trial noise patterns. A `+1`
means the noise on that trial is added to the CI; a `-1` means it is
subtracted. If responses are coded `{0, 1}` instead, the “subtract”
information is lost and the CI comes out close to blank. This is one of
the most common silent failures in RC data; Section 6.1 detects it.

**`"briefrc"`**: Following Schmitz et al. (2024), each trial is one row.
`stimulus` is the pool id of the chosen noise pattern, and `response` is
`+1` if the participant picked the oriented version (`base + noise`) or
`-1` if the inverted version (`base − noise`). The unchosen alternatives
are not recorded (see §3.4).

### 3.3. Example response datasets

A 2IFC dataset with three participants and four trials each. On every
trial the participant saw two stimuli (one oriented and one inverted
noise pattern superimposed on the same base face) and chose one:

``` r
responses_2ifc <- data.frame(
  participant_id = rep(c("P01", "P02", "P03"), each = 4),
  stimulus       = rep(1:4, times = 3),
  response       = c( 1, -1,  1,  1,
                     -1,  1,  1, -1,
                      1,  1, -1,  1),
  rt             = c(820, 910, 750, 880,
                     680, 1040, 720, 950,
                     900, 770, 990, 810)
)
responses_2ifc
#>    participant_id stimulus response   rt
#> 1             P01        1        1  820
#> 2             P01        2       -1  910
#> 3             P01        3        1  750
#> 4             P01        4        1  880
#> 5             P02        1       -1  680
#> 6             P02        2        1 1040
#> 7             P02        3        1  720
#> 8             P02        4       -1  950
#> 9             P03        1        1  900
#> 10            P03        2        1  770
#> 11            P03        3       -1  990
#> 12            P03        4        1  810
```

A Brief-RC 12 dataset with the same three participants and four trials
each. On every trial the participant saw 12 noisy faces (six
oriented-inverted pairs drawn from the noise pool) and picked one. The
row records the chosen stimulus’s pool id and whether the oriented (+1)
or inverted (−1) version was selected:

``` r
responses_briefrc <- data.frame(
  participant_id = rep(c("P01", "P02", "P03"), each = 4),
  stimulus       = c( 47, 112,  8, 263,
                      91,  17, 204,  55,
                     188, 142, 261,  73),
  response       = c( 1, -1,  1,  1,
                     -1,  1, -1,  1,
                      1,  1, -1, -1),
  rt             = c(1100, 1340, 980, 1210,
                      890, 1450, 1020, 1130,
                     1280, 1190, 1360, 1080)
)
responses_briefrc
#>    participant_id stimulus response   rt
#> 1             P01       47        1 1100
#> 2             P01      112       -1 1340
#> 3             P01        8        1  980
#> 4             P01      263        1 1210
#> 5             P02       91       -1  890
#> 6             P02       17        1 1450
#> 7             P02      204       -1 1020
#> 8             P02       55        1 1130
#> 9             P03      188        1 1280
#> 10            P03      142        1 1190
#> 11            P03      261       -1 1360
#> 12            P03       73       -1 1080
```

The structural difference between the two datasets is what `stimulus`
indexes:

| Aspect                           | 2IFC                             | Brief-RC 12                                                |
|----------------------------------|----------------------------------|------------------------------------------------------------|
| Alternatives shown per trial     | 2 (one oriented + one inverted)  | 12 (six oriented + six inverted, six noise pairs)          |
| Rows recorded per trial          | 1                                | 1                                                          |
| What `stimulus` indexes          | The trial’s stimulus pair        | The chosen pool item only                                  |
| Range of `stimulus`              | 1 to `n_trials`                  | 1 to `pool_size`                                           |
| Same id can repeat across trials | No (each trial has its own pair) | Depends on the experimenter’s sampling design (see §3.4.1) |
| Unchosen alternatives recorded   | Not applicable (only two shown)  | No (see below)                                             |

### 3.4. Brief-RC 12: how unselected stimuli are handled

In a Brief-RC 12 trial, 12 noisy faces are shown and the participant
picks one. The 11 unselected faces are **not recorded as separate rows**
and are **not assigned a zero response**. They are simply absent from
the dataset.

This is the convention Schmitz et al. (2024) use and the one this
package expects. Mathematically, the per-producer mask is built from the
chosen stimuli only:

    mask = (noise_matrix[, chosen_stimuli] %*% chosen_responses) /
             number_of_unique_chosen_stimuli

The unselected faces contribute nothing to the mask because their noise
patterns never enter the matrix multiplication. They are implicitly
weighted at zero, but no zero row is needed in the data: their absence
is the zero. Recording them as rows with `response = 0` would inflate
the divisor and shrink the resulting mask.

A common pitfall is the “expanded” format with 12 rows per trial,
weighting the chosen face `+1` and the unchosen `−1/11`. Do not use that
format. It is not what Schmitz et al. describe and not what this
package’s Brief-RC path consumes.

#### 3.4.1. Sampling design: how pool items are distributed across trials

Whether a given pool item appears on more than one Brief-RC trial is a
**design decision the experimenter makes**, not a property of the
paradigm itself. Three regimes are common.

1.  **Without replacement at the presentation level (the only path open
    when `n_trials × stim_per_trial == pool_size`).** Each pool item is
    shown exactly once across the whole task. Any given producer
    therefore cannot choose the same pool item twice. After the task,
    the producer’s recorded `stimulus` column has at most `n_trials`
    distinct values and no duplicates. Schmitz et al.

    2024. Experiment 1 used this regime: 60 trials × 12 alternatives =
          720 presentations, exactly matching their pool size of 720.

2.  **With replacement at the presentation level (the necessary path
    when `n_trials × stim_per_trial > pool_size`).** Pool items are
    drawn at random, possibly with repetition, when the task requires
    more presentations than the pool can supply uniquely. A producer can
    therefore choose the same pool item on two different trials,
    possibly with the same response sign or the opposite. Schmitz et
    al. (2024) Experiment 2 was in this regime: Brief-RC 12 had 250
    trials × 12 = 3000 presentations against a 2000-item pool.

3.  **Hybrid designs** (e.g., partial blocks, Latin squares,
    counterbalanced subsets per condition). Treat these as
    with-replacement at the analysis level unless your design guarantees
    no repetition.

**What this package assumes.** The Brief-RC analysis path is
intentionally agnostic to which regime you ran. Internally, before
computing the per-producer mask, it collapses any duplicated `stimulus`
ids in a producer’s data using `mean(response)`, exactly as Schmitz et
al.’s `genMask()` formulation does. So:

- If the same pool item was chosen twice with the **same** response
  sign, it contributes once with full weight.
- If chosen twice with **opposite** response signs, the two cancel and
  it contributes zero.
- The `genMask()` divisor is then `length(unique(chosen_stimuli))`, not
  `n_trials`.

**Downstream effects of the sampling regime.** The two practical
consequences for analysis are:

| Sampling regime                   | Producer’s data                          | `length(unique(chosen_stimuli))` vs. `n_trials` | InfoVal reference distribution                                       |
|-----------------------------------|------------------------------------------|-------------------------------------------------|----------------------------------------------------------------------|
| Without replacement (Exp 1 style) | No duplicate `stimulus` ids per producer | Equal                                           | Sample stim ids without replacement when simulating random producers |
| With replacement (Exp 2 style)    | Duplicates possible                      | Less than or equal                              | Sample stim ids with replacement when simulating random producers    |

[`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md)
picks the right reference-distribution sampling regime automatically: it
samples without replacement when the producer’s trial count is at most
the pool size, and with replacement otherwise. This is the calibration
fix the function was originally written to address (described in
§6.9.1). Users who designed their task with a custom regime should still
pass their actual trial count via the `trial_counts` argument; the
function does the rest.

**InfoVal reference distributions outside this package.** Canonical
[`rcicr::computeInfoVal2IFC()`](https://rdrr.io/pkg/rcicr/man/computeInfoVal2IFC.html)
builds its reference at the pool size regardless of the producer’s
actual trial count, which is correct for 2IFC (where they coincide) but
biases Brief-RC infoVal downward. If you are using stock `rcicr` rather
than this package’s
[`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md),
expect Brief-RC z-scores that systematically underestimate signal,
particularly when `n_trials` is much smaller than `pool_size`.

### 3.5. Auxiliary inputs

Both pipelines need stimulus-side inputs in addition to the responses:
2IFC needs the rcicr `.RData` and the base image; Brief-RC needs a noise
matrix and the base image.

#### 3.5.1. The rcicr `.RData` object (2IFC)

[`rcicr::generateStimuli2IFC()`](https://rdrr.io/pkg/rcicr/man/generateStimuli2IFC.html)
saves a single `.RData` file alongside the stimulus PNGs. When you
[`load()`](https://rdrr.io/r/base/load.html) it into R, several objects
appear in the environment. The names are short and not self-explanatory;
the table below spells out what each is and what you would use it for.

| Object                | What it is (plain language)                                                                                                                                                                                                                                                                                                                                                                                                                           |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `base_face_files`     | Named list of file paths to the original face images you supplied. The names you used (e.g. `"base"`) are the labels you later pass as `baseimage = "..."` when computing CIs.                                                                                                                                                                                                                                                                        |
| `base_faces`          | The base images themselves, loaded into R as numeric matrices of grayscale pixel values in `[0, 1]`. One matrix per label, e.g. `base_faces$base`. Shape is `img_size` x `img_size`.                                                                                                                                                                                                                                                                  |
| `img_size`            | Side length of the (square) images in pixels.                                                                                                                                                                                                                                                                                                                                                                                                         |
| `n_trials`            | Number of stimulus pairs (i.e. unique noise patterns) generated.                                                                                                                                                                                                                                                                                                                                                                                      |
| `noise_type`          | Type of noise basis used. The rcicr default and only well-tested option is `"sinusoid"`.                                                                                                                                                                                                                                                                                                                                                              |
| `p`                   | The **noise basis**. A list, the active fields are `p$patches` (a stack of standard sinusoidal patterns at multiple scales, orientations, and phases) and `p$patchIdx` (an index that maps positions in a parameter vector to entries in `p$patches`). Think of `p$patches` as a dictionary of basic sinusoidal “ingredients”; the actual noise pattern shown on any given trial is a weighted mix of these ingredients.                              |
| `stimuli_params`      | The **per-trial recipe** for combining `p`’s ingredients. A named list of matrices, one matrix per base face. Each row is one trial; each entry on that row is the contrast weight (how much of one ingredient to use). To reconstruct the noise pattern shown on, say, trial 42 with the base face labelled `"base"`, you call `rcicr::generateNoiseImage(stimuli_params[["base"]][42, ], p)` (output: a 2D matrix the same size as the base image). |
| `seed`                | Random seed passed at generation, for reproducibility.                                                                                                                                                                                                                                                                                                                                                                                                |
| `label`               | Label string passed to `generateStimuli2IFC()` (appears in saved filenames; not load-bearing for analysis).                                                                                                                                                                                                                                                                                                                                           |
| `stimulus_path`       | Output directory where the stimuli were written at generation time.                                                                                                                                                                                                                                                                                                                                                                                   |
| `trial`               | Internal bookkeeping object; not consumed by downstream functions.                                                                                                                                                                                                                                                                                                                                                                                    |
| `use_same_parameters` | If `TRUE`, the same noise was reused across multiple base faces (e.g. for a controlled cross-condition comparison). If `FALSE`, each base face got an independent draw of `stimuli_params`.                                                                                                                                                                                                                                                           |
| `generator_version`   | The rcicr version that produced the file.                                                                                                                                                                                                                                                                                                                                                                                                             |
| `reference_norms`     | A vector of random-responder Frobenius norms. **Not present at first**. It is created and inserted into the `.RData` file the first time you call [`rcicr::computeInfoVal2IFC()`](https://rdrr.io/pkg/rcicr/man/computeInfoVal2IFC.html) on this file (rcicr caches the simulation in place). If you need the original `.RData` untouched, copy it before running infoVal.                                                                            |

For computing CIs the load-bearing objects are `base_faces`,
`stimuli_params`, `p`, and `img_size`. rcicr reconstructs each trial’s
noise pattern from `stimuli_params` and `p`, then averages those
patterns across the trials a given participant selected to produce that
participant’s CI. The full set of trial-level noise images is not stored
in the `.RData`; it is recomputed on demand.

Filename note: on macOS the file is saved with a lowercase `.Rdata`
extension. Searches with `pattern = "\\.RData$"` will miss it; use
`ignore.case = TRUE`.

#### 3.5.2. Brief-RC noise matrix

The Brief-RC pipeline expects a noise matrix supplied as either:

1.  a path to a plain-text file readable by
    [`read_noise_matrix()`](https://olivethree.github.io/rcicrdiagnostics/reference/read_noise_matrix.md)
    (space-, tab-, or comma-delimited), or

2.  an already-loaded numeric matrix.

Shape: `n_pixels` rows by `pool_size` columns. Each column is one noise
pattern flattened in column-major order. For a 128 x 128 image and a
pool of 300 patterns, that is 16,384 rows by 300 columns.

The pool size and the maximum value in your `stimulus` column must
agree.
[`check_stimulus_alignment()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_stimulus_alignment.md)
reports any mismatch.

If you generated your Brief-RC pool with
[`rcicr::generateStimuli2IFC()`](https://rdrr.io/pkg/rcicr/man/generateStimuli2IFC.html)
(the path Schmitz et al. used), the matrix can be reconstructed from
`stimuli_params` and `p` as described above. If you generated it
elsewhere, save the columns directly with
`data.table::fwrite(mat, sep = " ", col.names = FALSE)`.

#### 3.5.3. Base image

Both pipelines depend on a base image. Requirements:

- **Square**, e.g. 256x256 or 512x512 pixels.
- **Grayscale** (one channel). RGB images error out with
  non-conformable-array messages from `rcicr`.
- **Pixel range `[0, 1]`**, which is what
  [`png::readPNG()`](https://rdrr.io/pkg/png/man/readPNG.html) and
  [`jpeg::readJPEG()`](https://rdrr.io/pkg/jpeg/man/readJPEG.html)
  produce.
- **Centred face** with the eye, nose, and mouth regions roughly at the
  geometry assumed by
  [`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md)
  (eyes near the upper third, mouth near the lower third). The default
  [`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md)
  geometry follows Schmitz, Rougier, & Yzerbyt (2024).

The conventional base face is a morph of several individual faces, which
removes idiosyncratic features and centres the geometry. The
[webmorphR](https://github.com/debruine/webmorphR) package by Lisa
DeBruine is the current best-in-class tool for producing such base
images reproducibly. A typical pipeline:

``` r
# install.packages("webmorphR")  # CRAN
library(webmorphR)

stim <- read_stim("path/to/raw_face_images/") |>
  auto_delin() |>                       # automatic landmark delineation
  align(procrustes = TRUE) |>           # Procrustes alignment across faces
  crop(width = 0.85, height = 0.85) |>  # tight crop around the aligned face
  to_size(c(256, 256)) |>               # force the rcicr-friendly size
  greyscale() |>                        # one channel, in [0, 1]
  avg()                                 # morph into a single average face

write_stim(stim, dir = "stimuli/", names = "base", format = "png")
```

That writes `stimuli/base.png`, which is then suitable as input to
`rcicr::generateStimuli2IFC(base_face_files = list(base = "stimuli/base.png"))`.
For non-square crop, oval mask, and feature-aligned operations, see
`?webmorphR::mask_oval` and `?webmorphR::crop_tem`. Cite webmorphR as
DeBruine (2022).

If you cannot use webmorphR (e.g. the input is already a single face
photo and not a stack to morph), preparing the base image by hand is
acceptable. In any image editor, convert to grayscale, crop to a square
that fits the face roughly within the central 70%, and resize to the
target dimensions. Both GIMP (free) and the open-source krita or even
PowerPoint export will do this.

#### 3.5.4. Face-region masks

Section 6.9.2
([`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md))
accepts an optional logical mask that restricts the infoVal computation
to a subset of pixels (for example, the face region). Three ways to
obtain one:

1.  **Programmatic, parametric.**
    [`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md)
    produces an oval (or eyes / nose / mouth / upper / lower face) mask
    sized to the image, matching Schmitz 2024 geometry by default:

    ``` r
    m <- face_mask(c(256L, 256L))                     # full oval
    m_eyes  <- face_mask(c(256L, 256L), region = "eyes")
    m_mouth <- face_mask(c(256L, 256L), region = "mouth")
    ```

2.  **Programmatic, image-based.** webmorphR’s `mask_oval()` (and
    related `mask()` helpers) produces a feature-aligned mask from a
    landmark template. Save as PNG and load with
    [`load_face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/load_face_mask.md).

3.  **Manual.** Open the base image in GIMP, PowerPoint, or any other
    editor. Paint the face region white (255) and the rest black (0),
    keeping the same dimensions as the base image, and export as PNG or
    JPEG. Load with
    `load_face_mask("path/to/mask.png", threshold = 0.5)`. For a
    less-than-rigorous oval, PowerPoint’s ellipse shape filled white
    over a black background works in under a minute.

## 4. A first diagnostic run

Here is a small synthetic 2IFC dataset — three participants, one hundred
trials each, responses drawn uniformly from `{-1, 1}`:

``` r
responses <- data.frame(
  participant_id = rep(1:3, each = 100),
  stimulus       = rep(1:100, 3),
  response       = sample(c(-1, 1), 300, replace = TRUE)
)
head(responses)
#>   participant_id stimulus response
#> 1              1        1       -1
#> 2              1        2        1
#> 3              1        3       -1
#> 4              1        4       -1
#> 5              1        5        1
#> 6              1        6       -1
```

Run the full set of checks:

``` r
report <- run_diagnostics(responses, method = "2ifc")
report
#> == Data-quality report (2ifc) ==
#> 
#> [PASS] Response coding
#>   All 300 responses coded as {-1, 1}.
#> [PASS] Trial counts
#>   3 participants total.
#>   Trial counts observed: 100 trials (3 participants).
#> [PASS] Duplicates
#>   0 of 300 rows are fully duplicated.
#>   0 rows share a (participant, stimulus) pair with differing response or RT.
#> [PASS] Response bias
#>   0 of 3 participants gave the same response on every trial.
#>   0 participants have |mean response| > 0.6 (extreme bias).
#>   Group mean response: 0.027.
#> 
#> Summary: pass=4, warn=0, fail=0, skip=0
#> 
#> Skipped checks:
#>   - check_rt (no col_rt)
#>   - check_stimulus_alignment (no rdata / noise_matrix)
#>   - check_version_compat (no rdata)
#>   - diagnose_infoval (need infoval_iter)
#>   - compute_infoval_summary (need rdata + infoval_iter)
#>   - check_response_inversion (needs infoval)
#>   - cross_validate_rt_infoval (needs infoval)
```

That printout is what the package produces for you: one line per check,
a coloured tag (green `[PASS]`, yellow `[WARN]`, red `[FAIL]`, grey
`[SKIP]` on colour-capable consoles), and a short explanation.

The **`Skipped checks`** block underneath is equally informative. Each
line names a check that *could have* run but didn’t, together with the
exact input that’s missing. So when you see

    Skipped checks:
      - check_rt (no col_rt)
      - check_stimulus_alignment (no rdata / noise_matrix)
      - check_version_compat (no rdata)
      - diagnose_infoval (need infoval_iter)
      - compute_infoval_summary (need rdata + infoval_iter)
      - check_response_inversion (needs infoval)
      - cross_validate_rt_infoval (needs infoval)

nothing has failed — you just haven’t handed
[`run_diagnostics()`](https://olivethree.github.io/rcicrdiagnostics/reference/run_diagnostics.md)
the extra inputs those checks need. Section 7.1 walks through exactly
what to pass for each one so you can progressively unlock them.

## 5. Result object

Every single check returns a small list with a fixed shape. The package
gives this shape a class name — `rcdiag_result` — so that printing and
other helpers know how to handle it:

``` r
r <- check_response_coding(responses, method = "2ifc")
str(r, max.level = 1)
#> List of 4
#>  $ status: chr "pass"
#>  $ label : chr "Response coding"
#>  $ detail: chr "All 300 responses coded as {-1, 1}."
#>  $ data  : list()
#>  - attr(*, "class")= chr "rcdiag_result"
```

Four fields you can read directly:

- `status` — one of `"pass"`, `"warn"`, `"fail"`, `"skip"`. Interpret
  as: move on, investigate, stop and fix, not run.
- `label` — short description of the check.
- `detail` — the lines printed under the status tag.
- `data` — optional supporting data: flagged participants, count tables,
  group statistics. Useful when you want to programmatically exclude
  problem participants from the dataset you eventually feed to the CI
  generator.

[`run_diagnostics()`](https://olivethree.github.io/rcicrdiagnostics/reference/run_diagnostics.md)
returns a collection of these, wrapped in an `rcdiag_report`.
[`summary()`](https://rdrr.io/r/base/summary.html) flattens the
collection into a tidy data frame — handy if you want to filter or log
statuses:

``` r
summary(report)
#>             check status           label
#> 1 response_coding   pass Response coding
#> 2    trial_counts   pass    Trial counts
#> 3      duplicates   pass      Duplicates
#> 4   response_bias   pass   Response bias
```

## 6. Checks one by one

Every example below uses synthetic data built inline, so the checks from
Sections 6.1–6.8 run without any external files. The three infoVal-
based checks in Sections 6.9–6.11 need `rcicr` and a real `.RData` file,
so their examples are shown but not executed in this vignette.

### 6.1. `check_response_coding()`

Verifies the response column is coded as `method` expects. For 2IFC it
detects the two most common miscodings and suggests the one-line fix.

``` r
ok <- data.frame(
  participant_id = 1:10,
  stimulus       = 1:10,
  response       = sample(c(-1, 1), 10, replace = TRUE)
)
check_response_coding(ok, method = "2ifc")
#> [PASS] Response coding
#>   All 10 responses coded as {-1, 1}.
```

``` r
miscoded <- data.frame(
  participant_id = 1:10,
  stimulus       = 1:10,
  response       = sample(c(0, 1), 10, replace = TRUE)
)
check_response_coding(miscoded, method = "2ifc")
#> [WARN] Response coding
#>   Detected {0, 1} coding. Recode with responses$response <- responses$response * 2 - 1.
```

The `{0, 1}` miscoding returns **warn** with the recoding formula
(`responses$response <- responses$response * 2 - 1`). The `{1, 2}`
miscoding returns the analogous fix. For `method = "briefrc"`, any
finite numeric passes; `NA` responses produce a warning so you can
decide whether to drop or impute them.

### 6.2. `check_trial_counts()`

Counts trials per participant. If you pass `expected_n`, it flags
participants whose count doesn’t match. `expected_n` can be a single
number (everyone should have the same number of trials) or a vector of
allowed counts (for designs with multiple trial-count conditions, e.g.
`c(300, 500, 1000)`).

``` r
three_hundred_each <- data.frame(
  participant_id = rep(1:3, each = 300),
  stimulus       = rep(1:300, 3),
  response       = 1L
)
check_trial_counts(three_hundred_each, expected_n = 300)
#> [PASS] Trial counts
#>   All 3 participant{?s} have trial counts in {300}.
```

``` r
with_a_short_participant <- data.frame(
  participant_id = rep(1:5, times = c(300, 300, 300, 300, 250)),
  stimulus       = 1,
  response       = 1L
)
check_trial_counts(with_a_short_participant, expected_n = 300)
#> [FAIL] Trial counts
#>   1 of 5 participant{?s} have unexpected trial counts.
#>   Expected: {300}.
#>   Flagged counts: 5 (n=250).
```

A single off-count participant is **warn**; more than 10% of
participants off-count is **fail** (the logic: one odd participant may
be excludable, but a systemic mismatch means your merge or filter logic
is probably wrong). Leave `expected_n = NULL` (the default) to get a
count distribution without flagging anything.

### 6.3. `check_duplicates()`

Duplicate rows almost always indicate a merge bug (for example, two
partial exports of the same participant concatenated together). Two
cases are flagged separately:

1.  **Fully duplicated rows** — every column identical. Unambiguously
    bad.
2.  **`(participant, stimulus)` pair duplicates** — same participant,
    same stimulus, but different response or RT. Could be legitimate if
    your design deliberately repeats stimuli, or could be a merge error.

``` r
with_a_dup <- data.frame(
  participant_id = c(1, 1, 1, 2, 2),
  stimulus       = c(1, 2, 2, 1, 2),
  response       = c(1, -1, -1, 1, -1)
)
check_duplicates(with_a_dup)
#> [WARN] Duplicates
#>   1 of 5 rows are fully duplicated.
#>   1 rows share a (participant, stimulus) pair with differing response or RT.
```

### 6.4. `check_response_bias()`

Two kinds of bias are reported:

- **Constant responders** — a participant who gave the same response on
  every trial. These are almost always bad data (disengaged participant
  or a coding bug) because their “signal” contribution is constant and
  does nothing except scale the base image. Status: **fail**.
- **Extremely biased participants** — those whose mean response is far
  enough from zero that you probably can’t trust the CI. The threshold
  is `|mean| > bias_threshold`, default `0.6`. For binary `{-1, 1}`
  coding this corresponds to roughly an 80/20 split. Status: **warn**.

``` r
with_a_constant_responder <- data.frame(
  participant_id = rep(1:4, each = 100),
  stimulus       = rep(1:100, 4),
  response       = c(
    sample(c(-1, 1), 100, replace = TRUE),
    sample(c(-1, 1), 100, replace = TRUE),
    rep(1, 100),
    sample(c(-1, 1), 100, replace = TRUE)
  )
)
check_response_bias(with_a_constant_responder)
#> [FAIL] Response bias
#>   1 of 4 participants gave the same response on every trial.
#>   0 participants have |mean response| > 0.6 (extreme bias).
#>   Group mean response: 0.215.
```

The per-participant breakdown is stored on the result so you can filter
your dataset directly without re-computing:

``` r
r <- check_response_bias(with_a_constant_responder)
r$data$per_participant
#>    participant_id n_trials  mean constant is_biased
#>             <int>    <int> <num>   <lgcl>    <lgcl>
#> 1:              1      100 -0.06    FALSE     FALSE
#> 2:              2      100 -0.14    FALSE     FALSE
#> 3:              3      100  1.00     TRUE     FALSE
#> 4:              4      100  0.06    FALSE     FALSE
```

### 6.5. `check_rt()`

Scans response times for three kinds of pathology:

1.  **Implausibly fast responses** (`rt < fast_threshold`, default 200
    ms). These almost always mean the participant clicked before
    processing the stimulus.
2.  **Implausibly slow responses** (`rt > slow_threshold`, default 5000
    ms). Often a sign of distraction or a task pause.
3.  **Abnormally low within-participant RT variability** (coefficient of
    variation below `min_cv`, default 0.10). A nearly constant RT is a
    hint that the participant is responding mechanically.

The check requires an RT column; pass it via `col_rt`. Status logic:
more than 15% fast trials for any participant is **fail**; any lesser
flag is **warn**; otherwise **pass**.

``` r
set.seed(2)
df_rt <- data.frame(
  participant_id = rep(1:3, each = 100),
  stimulus       = rep(1:100, 3),
  response       = 1L,
  rt             = c(
    exp(rnorm(100, 6.7, 0.4)) + 200,   # normal responder
    c(rep(150, 30), exp(rnorm(70, 6.7, 0.4)) + 200),  # 30% fast
    rep(800, 100)                      # constant RT — no variability
  )
)
check_rt(df_rt, col_rt = "rt")
#> [FAIL] Response times
#>   1 of 3 participants exceed 5% fast trials (< 200 ms).
#>   0 of 3 participants exceed 5% slow trials (> 5000 ms).
#>   1 of 3 participants have RT coefficient of variation below 0.1.
#>   1 participants exceed 15% fast trials (severe).
```

`r$data$per_participant` gives you the per-participant breakdown
(`pct_fast`, `pct_slow`, `cv_rt`, and the three flag columns) so you can
exclude participants programmatically.

### 6.6. `check_stimulus_alignment()`

Verifies that every `stimulus` id in your response data refers to a
valid column/row of the stimulus pool. For 2IFC the pool size is read
from the `.RData` (`n_trials` field); for Brief-RC it is
[`ncol()`](https://rdrr.io/r/base/nrow.html) of the noise matrix.

``` r
mat <- matrix(rnorm(16384 * 5, sd = 0.05), nrow = 16384, ncol = 5)
stim_ok <- data.frame(
  participant_id = rep(1:2, each = 20),
  stimulus       = sample.int(5, 40, replace = TRUE),
  response       = sample(c(-1, 1), 40, replace = TRUE)
)
check_stimulus_alignment(stim_ok, method = "briefrc", noise_matrix = mat)
#> [PASS] Stimulus alignment
#>   5 of 5 pool stimuli are referenced in the response data.
```

``` r
stim_bad <- data.frame(
  participant_id = 1:3,
  stimulus       = c(2L, 10L, 42L),   # 10 and 42 exceed the 5-col pool
  response       = 1L
)
check_stimulus_alignment(stim_bad, method = "briefrc", noise_matrix = mat)
#> [FAIL] Stimulus alignment
#>   2 stimulus id(s) are outside the valid range [1, 5].
#>   Examples of out-of-range ids: 10, 42
```

Any id outside `[1, pool_size]` returns **fail**. If more than half the
pool is never referenced in the data, you get a **warn** — that’s often
a sign the stimulus file doesn’t match the experiment you ran.

### 6.7. `check_version_compat()`

Every `.RData` produced by
[`rcicr::generateStimuli2IFC()`](https://rdrr.io/pkg/rcicr/man/generateStimuli2IFC.html)
stores a `generator_version` field. When you reconstruct CIs later, the
installed `rcicr` version should match — subtle API or numerical changes
between versions can silently produce different CIs from the same data.

``` r
tmp <- tempfile(fileext = ".RData")
generator_version <- "0.4.0"
n_trials <- 100L
save(generator_version, n_trials, file = tmp)

check_version_compat(tmp)
#> [WARN] rcicr version compatibility
#>   rdata was produced by rcicr 0.4.0.
#>   Installed rcicr is version 1.0.1.
#>   Reconstructed CIs may differ from those produced at experiment time.
```

The status depends on whether the versions match: **pass** if equal,
**warn** if different, **warn** with a clear note if the `.RData`
doesn’t record a version at all or `rcicr` isn’t installed in the
current session.

### 6.8. `validate_noise_matrix()` (Brief-RC)

[`read_noise_matrix()`](https://olivethree.github.io/rcicrdiagnostics/reference/read_noise_matrix.md)
reads a space-delimited text file into a numeric matrix. For a
self-contained example we just build one in memory and validate it:

``` r
mat <- matrix(rnorm(16384 * 5, sd = 0.05), nrow = 16384, ncol = 5)
validate_noise_matrix(mat, expected_pixels = 16384, expected_stimuli = 5)
#> [PASS] Noise matrix
#>   16384 pixels x 5 stimuli, all finite. Range: [-0.21, 0.224].
```

The validator checks the dimensions (one row per pixel, one column per
stimulus) and that no cell is `NA`, `NaN`, or `Inf`. Supplying the wrong
expected dimensions returns **fail** with a specific message. A lot of
early-pipeline errors surface here — confusing pixel count with stimulus
count, saving the matrix with an unexpected delimiter, and so on.

### 6.9. `compute_infoval_summary()`

Computes the **information value** (infoVal; Brinkman et al., 2019) for
every participant. InfoVal is a z-like score describing how far a
participant’s CI is from a null-response reference distribution. Values
around or below `1.96` are effectively indistinguishable from noise;
higher values indicate meaningful signal.

The 2IFC path delegates the heavy lifting to the original `rcicr`
package (Dotsch, v1.0.1 at the time of writing): `batchGenerateCI2IFC()`
to build per-participant CIs and `computeInfoVal2IFC()` to score each
against a simulated reference distribution. On the first call `rcicr`
simulates a reference distribution (10 000 iterations by default — a few
minutes) and caches it *inside the `.RData` file* so subsequent calls
are fast. **Copy your `.RData` beforehand if you want the original
untouched.**

**Brief-RC is not currently supported.** Canonical `rcicr` does not
expose Brief-RC-specific CI or infoVal machinery, and a correct Brief-RC
infoVal needs a reference distribution matched to each participant’s
trial count rather than the pool size stored in the rdata. Calling
`compute_infoval_summary(method = "briefrc")` returns a `"skip"` result
with this explanation; proper Brief-RC infoVal is planned for the
companion `rcicrely` package.

``` r
iv <- compute_infoval_summary(
  responses,
  method    = "2ifc",
  rdata     = "data-raw/generated/rcicr_2ifc_stimuli.RData",
  baseimage = "base",
  iter      = 10000,
  threshold = 1.96
)
iv
# $data$per_participant has: participant_id, infoval, meaningful
head(iv$data$per_participant)
```

Returned as an `rcdiag_result`. Status:

- **pass** when the median per-participant `infoval` is positive;
- **warn** otherwise.

Use `$data$per_participant` to pull out individual scores and the
`above_threshold` flag for downstream exclusion.

[`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md)
deliberately does **not** return a **fail** status based on
per-participant z alone. The reason is the subject of §6.9.1 below:
per-producer z is structurally low even on healthy data, so a
per-participant headcount is a misleading proxy for data quality. Use
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
(§6.9.2) for the real verdict.

### 6.9.1. Why per-producer infoVal often looks “low”

A common moment of confusion in RC analysis is opening
[`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md)’s
output and seeing per-producer z below the 1.96 threshold, sometimes
negative, even though data collection went smoothly. Three things are
worth knowing before you conclude the data are broken.

**The published baseline is paradigm- and target-dependent.** Brinkman
et al. (2019, p. 12) report that on 2IFC for perceived gender — a
strong, consensual target — individual infoVals cluster in the 3–4
range, with 54–68% of participants clearing 1.96 (lab vs. online samples
respectively). By contrast, Schmitz et al. (2024) applied infoVal to
Brief-RC for a social-category target (“Chinese-looking face”), with an
oval face mask, and reported infoVals **below 1.96 in every condition of
both experiments**: Experiment 1 means were 1.54 (Traditional-RC), 1.93
(Brief-RC12), and 1.74 (Brief-RC20) (p. 7); Experiment 2 means across
comparison criteria ranged from 0.69 to 1.22. Their own interpretation
(p. 13): *“infoVal scores were relatively low, regardless of the
condition, signalling that increasing the number of trials may be
beneficial to improve both metrics.”* So “low individual infoVal” is the
normal empirical finding for Brief-RC in the only published
methodological evaluation of it.

**There is a known calibration bug for Brief-RC in the original rcicr.**
[`rcicr::computeInfoVal2IFC()`](https://rdrr.io/pkg/rcicr/man/computeInfoVal2IFC.html)
builds its random-responder reference distribution at the pool size
(number of columns in the noise matrix it reconstructs internally),
regardless of how many trials each producer actually completed. For
2IFC, where every producer responds to every pool item once, pool size
equals trial count, so the reference is correctly calibrated. For
Brief-RC, where a producer samples only a subset of the pool, the
reference sampling regime does not match the observed sampling regime,
and the resulting z is biased downward. This package ships an in-package
[`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md)
whose reference is keyed on each producer’s actual trial count, closing
the gap. How much that lifts any given dataset’s z is empirical and
depends on the `n_trials / pool_size` ratio.

**Why the simulator’s 50/50 ±1 sampling is correct under standard
Brief-RC.** A natural first worry on reading the simulator is that
[`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md)
draws random responses with `sample(c(-1, 1), n_trials, replace = TRUE)`
— a uniform 50/50 ±1 — when each Brief-RC trial actually involves
picking 1 of 12 alternatives. The 50/50 is exact under the standard
Brief-RC trial structure (Schmitz et al., 2024, p. 6): each trial shows
6 oriented and 6 inverted faces, so a random producer picks one of 12
with `P(response = +1) = 6/12 = 0.5`, and the chosen-stimulus-id
sequence is uniform over the pool. The simulator’s marginal joint
distribution of `(chosen_stim, response)` therefore matches a random
Brief-RC responder. Designs that depart from a balanced
oriented/inverted split per trial, or that have trials overlapping on
the pool in non-standard ways, will see a small calibration drift; for
the standard 6/6 design — and correspondingly for any other balanced
split such as 10/10 in Brief-RC 20 — the calibration is exact.

**Group-mean vs. individual z.** The group-mean CI is built from N × T
decisions across N producers, so its Frobenius norm is compared against
a correspondingly tighter reference distribution; intuitively, noise
averages down by √N. The Brinkman and Schmitz papers don’t compute a
group-mean z directly, but mathematically it will exceed the
individual-level median, and it is often the more defensible summary
statistic when individual-level z is noisy.

One additional interpretation, offered as *speculation*, not as an
established finding: negative individual z does not imply “anti-signal.”
InfoVal is direction-agnostic (a z-scored Frobenius norm has no sign in
pixel space), so a producer responding “opposite” to the target would
still score positive. Negative z is geometrically consistent with a
coherent low-rank mask that fills less of the noise basis than a
random-responder mask does — but neither Brinkman nor Schmitz report or
test this, so treat it as a hypothesis, not a fact.

What
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
automates:

- The per-trial-count reference (fixes the pool-size calibration bug for
  Brief-RC).
- A random-responder calibration check, so you can see whether a
  simulated random producer lands near z = 0 in your setup.
- Group-mean z alongside individual z.
- Optional face masking via
  [`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md),
  matching Schmitz’s geometry.

What it does **not** automate is the decision about whether your
individual-level infoVals are high enough to report. That depends on
your target, paradigm, and trial count, and the published baselines from
the two papers cited above are the honest yardsticks.

### 6.9.2. `diagnose_infoval()` — guided low/negative-z diagnostic

[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
is the recommended entry point when individual infoVal looks low and you
want to know whether the data is broken or merely structurally diluted.
It walks through six checks and produces interpretation bullets, plus
rich `$data` for plotting.

The six steps:

1.  Simulate the reference distribution at every unique trial count
    present in the data.
2.  Sanity-check the reference with a simulated random responder
    (expected `|z|` close to 0; `|z| > 2` is a red flag).
3.  Compute per-producer z **unmasked**.
4.  Compute per-producer z with a **face mask** (default: oval matching
    Schmitz 2024 geometry via
    [`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md)).
5.  Compute the **group-mean CI’s** z against a reference matched to the
    actual producer count and trial counts.
6.  Tally per-producer z into bands (`< -1.96`, `[-1.96, 0)`,
    `[0, 1.96)`, `>= 1.96`) and emit interpretation text.

``` r
report <- diagnose_infoval(
  responses,
  method       = "2ifc",
  rdata        = "data-raw/generated/rcicr_2ifc_stimuli.RData",
  iter         = 10000,
  face_mask    = "auto",  # NULL skips masking; or pass a logical / matrix / path
  seed         = 1L
)
print(report)
report$data$random_responder_z       # ≈ 0 if calibration is correct
report$data$group_mean_z_unmasked    # the publish-this number
report$data$tally                    # per-producer z distribution
```

Both paradigms are supported. For `method = "briefrc"`,
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
uses an in-package implementation of Schmitz’s `genMask()` algebra and
the per-trial-count reference distribution; no `rcicr` install is
required. Pass `noise_matrix = ...`. For `method = "2ifc"`, the function
calls `rcicr` to (a) compute per-producer CIs from `stimuli_params` and
`p` via
[`rcicr::batchGenerateCI2IFC()`](https://rdrr.io/pkg/rcicr/man/batchGenerateCI2IFC.html),
and (b) reconstruct each pool item’s noise pattern via
[`rcicr::generateNoiseImage()`](https://rdrr.io/pkg/rcicr/man/generateNoiseImage.html)
so the reference distribution can be simulated; `rcicr` therefore needs
to be installed for this path. The reconstruction adds a few seconds for
a typical `n_pool = 770` pool.

#### A reporting template

When you report infoVal, state exactly what reference distribution was
used and which metric you computed. A template that matches the
information the diagnostic returns:

> *“Per-producer informational value (Brinkman et al., 2019) was
> computed with a reference distribution matched to each producer’s
> trial count (rather than to the pool size), as implemented in
> [`rcicrdiagnostics::infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md).
> \[If masked:\] We applied an oval face-region mask following Schmitz,
> Rougier, and Yzerbyt (2024). A simulated random-responder check
> returned z = Z.ZZ, consistent with a correctly calibrated reference
> distribution. On the individual level, K of N producers exceeded z =
> 1.96 (median z = Y.YY). The group-mean classification image yielded z
> = X.XX.”*

Do not paste this verbatim; adjust to your pipeline and drop any
sentence that does not describe what you actually did.

### 6.10. `check_response_inversion()`

Occasionally a whole batch of response data has its `+1`/`-1` codes
systematically flipped — for example, the export script recorded *button
number* rather than *chosen face side*, and the mapping was reversed. An
inverted CI looks perfectly reasonable but represents the opposite
mental content from what you meant to measure.

This check computes infoVal twice — once with the original responses and
once with every response sign-flipped — and flags participants whose
flipped infoVal exceeds the original by at least `margin` (default
`1.96`). Any non-zero count is a strong signal.

``` r
check_response_inversion(
  responses,
  method    = "2ifc",
  rdata     = "data-raw/generated/rcicr_2ifc_stimuli.RData",
  baseimage = "base",
  margin    = 1.96,
  iter      = 10000
)
```

Runs two infoVal sweeps, so it takes roughly twice as long as a single
[`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md)
call. `$data$per_participant` includes `infoval_original`,
`infoval_flipped`, `delta`, and `likely_inverted`.

### 6.11. `cross_validate_rt_infoval()`

Correlates per-participant infoVal with per-participant median RT. The
check flags two patterns that are individually plausible but jointly
suspicious:

1.  **High infoVal paired with fast median RT.** A participant with a
    seemingly informative CI while responding faster than peers is more
    likely to have stumbled onto signal by chance than to be genuinely
    informative.
2.  **A negative correlation** between infoVal and RT *across*
    participants. If fast responders systematically score higher on
    infoVal, something about the measurement is off — possibly a
    click-pattern artefact.

``` r
cross_validate_rt_infoval(
  responses,
  method    = "2ifc",
  rdata     = "data-raw/generated/rcicr_2ifc_stimuli.RData",
  baseimage = "base",
  col_rt    = "rt",
  iter      = 10000
)
```

`$data$correlation` gives the Pearson correlation.
`$data$per_participant` adds a `fast_and_confident` flag (below-group-
median RT **and** above-group-median infoVal) for inspection. Status is
**warn** when the correlation drops to −0.30 or lower; the check does
not auto-exclude anyone, because the interpretation depends on the
experiment.

### 6.12. `load_responses()`

[`load_responses()`](https://olivethree.github.io/rcicrdiagnostics/reference/load_responses.md)
is a thin wrapper around
[`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html)
(a fast CSV reader) that checks the required columns are present. Use it
on your real data file:

``` r
responses <- load_responses("my_data.csv", method = "2ifc")
```

It returns a `data.table`, which behaves like a regular `data.frame` for
the check functions — you don’t need to learn a new syntax.

## 7. `run_diagnostics()`

[`run_diagnostics()`](https://olivethree.github.io/rcicrdiagnostics/reference/run_diagnostics.md)
runs every implemented check in one call and returns the collected
`rcdiag_report`. It works out the `method` automatically when exactly
one of `rdata` or `noise_matrix` is supplied, so you usually don’t need
to set `method` yourself:

``` r
# Auto-detected as "2ifc" because rdata is supplied:
run_diagnostics(responses, rdata = "stimuli.RData")

# Auto-detected as "briefrc":
run_diagnostics(responses, noise_matrix = "noise_matrix_128.txt")
```

Pass `method` explicitly when you have neither file on hand — for
example, to sanity-check the response CSV by itself:

``` r
run_diagnostics(responses, method = "2ifc")
#> == Data-quality report (2ifc) ==
#> 
#> [PASS] Response coding
#>   All 300 responses coded as {-1, 1}.
#> [PASS] Trial counts
#>   3 participants total.
#>   Trial counts observed: 100 trials (3 participants).
#> [PASS] Duplicates
#>   0 of 300 rows are fully duplicated.
#>   0 rows share a (participant, stimulus) pair with differing response or RT.
#> [PASS] Response bias
#>   0 of 3 participants gave the same response on every trial.
#>   0 participants have |mean response| > 0.6 (extreme bias).
#>   Group mean response: 0.027.
#> 
#> Summary: pass=4, warn=0, fail=0, skip=0
#> 
#> Skipped checks:
#>   - check_rt (no col_rt)
#>   - check_stimulus_alignment (no rdata / noise_matrix)
#>   - check_version_compat (no rdata)
#>   - diagnose_infoval (need infoval_iter)
#>   - compute_infoval_summary (need rdata + infoval_iter)
#>   - check_response_inversion (needs infoval)
#>   - cross_validate_rt_infoval (needs infoval)
```

Per-check options are passed through. Common ones:

- `expected_n` → forwarded to
  [`check_trial_counts()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_trial_counts.md).
- `col_rt` → when supplied (and the column exists),
  [`check_rt()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_rt.md)
  runs and, if combined with `rdata` and `infoval_iter`, so does
  [`cross_validate_rt_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/cross_validate_rt_infoval.md).
- `infoval_iter` → number of iterations for the reference-distribution
  simulation. **Default `NULL`**, which means the three infoVal-based
  checks are skipped. Set to e.g. `10000` to enable them — expect the
  first call to take a few minutes.

``` r
run_diagnostics(
  responses,
  method     = "2ifc",
  expected_n = 100
)
#> == Data-quality report (2ifc) ==
#> 
#> [PASS] Response coding
#>   All 300 responses coded as {-1, 1}.
#> [PASS] Trial counts
#>   All 3 participant{?s} have trial counts in {100}.
#> [PASS] Duplicates
#>   0 of 300 rows are fully duplicated.
#>   0 rows share a (participant, stimulus) pair with differing response or RT.
#> [PASS] Response bias
#>   0 of 3 participants gave the same response on every trial.
#>   0 participants have |mean response| > 0.6 (extreme bias).
#>   Group mean response: 0.027.
#> 
#> Summary: pass=4, warn=0, fail=0, skip=0
#> 
#> Skipped checks:
#>   - check_rt (no col_rt)
#>   - check_stimulus_alignment (no rdata / noise_matrix)
#>   - check_version_compat (no rdata)
#>   - diagnose_infoval (need infoval_iter)
#>   - compute_infoval_summary (need rdata + infoval_iter)
#>   - check_response_inversion (needs infoval)
#>   - cross_validate_rt_infoval (needs infoval)
```

For programmatic access, the individual results live under
`report$results`:

``` r
report <- run_diagnostics(responses, method = "2ifc")
vapply(report$results, `[[`, character(1), "status")
#> response_coding    trial_counts      duplicates   response_bias 
#>          "pass"          "pass"          "pass"          "pass"
```

### 7.1. Additional checks

With only `responses` and `method`, four checks run. Six more are listed
under `Skipped checks` and each requires a specific additional input:

| Check                                                                                                                 | Additional input required                                                                                                                                    |
|-----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [`check_rt()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_rt.md)                                   | `col_rt = "rt"` (the column must exist in `responses`)                                                                                                       |
| [`check_stimulus_alignment()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_stimulus_alignment.md)   | `rdata = "..."` (2IFC) or `noise_matrix = "..."` (Brief-RC)                                                                                                  |
| [`check_version_compat()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_version_compat.md)           | `rdata = "..."` (2IFC only)                                                                                                                                  |
| [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)                   | `infoval_iter` plus `rdata` (2IFC) or `noise_matrix` (Brief-RC); both paradigms supported                                                                    |
| [`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md)     | `rdata` and `infoval_iter` (2IFC only; for Brief-RC use [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)) |
| [`check_response_inversion()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_response_inversion.md)   | `rdata` and `infoval_iter` (runs infoVal twice, so it takes ~2x as long)                                                                                     |
| [`cross_validate_rt_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/cross_validate_rt_infoval.md) | `rdata`, `infoval_iter`, and `col_rt`                                                                                                                        |

`infoval_iter` defaults to `NULL` because the reference-distribution
simulation at `10000` iterations takes a few minutes on the first call.
`rcicr` caches the distribution inside the `.RData` file, so subsequent
calls on the same file are fast (you pay the cost once per rdata).

A full call with every input supplied looks like this:

``` r
full <- run_diagnostics(
  responses,
  method       = "2ifc",
  rdata        = "data-raw/generated/rcicr_2ifc_stimuli.RData",
  baseimage    = "base",
  col_rt       = "rt",
  expected_n   = c(300, 500, 1000),
  infoval_iter = 10000
)
full
# When every input is supplied, the "Skipped checks" block is empty
# and the report contains all 10 checks.
```

For Brief-RC, swap `rdata` for `noise_matrix` at the
`check_stimulus_alignment` step.
[`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md),
[`check_response_inversion()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_response_inversion.md),
and
[`cross_validate_rt_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/cross_validate_rt_infoval.md)
all return `"skip"` for Brief-RC because the original `rcicr` does not
ship Brief-RC infoVal machinery.
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
covers Brief-RC through an in-package implementation; see Section 6.9.2.

[`run_diagnostics()`](https://olivethree.github.io/rcicrdiagnostics/reference/run_diagnostics.md)
runs every check whose required inputs are available. The
`Skipped checks` list names what is missing; nothing errors silently and
nothing runs halfway.

## 8. Reading the report

Four statuses:

- **pass** (green) — the check saw nothing unusual. Continue.
- **warn** (yellow) — something worth investigating but not necessarily
  fatal (e.g. one duplicate row, a known miscoding with a suggested
  fix). Look at `$data` and decide.
- **fail** (red) — something that will corrupt downstream CIs or infoVal
  if you ignore it. Fix before proceeding.
- **skip** (grey) — the check didn’t run because its required inputs
  weren’t supplied. For example,
  [`check_rt()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_rt.md)
  is skipped when `col_rt` is `NULL`, and the infoVal-based checks are
  skipped when either `rdata` or `infoval_iter` is missing. The report’s
  “Skipped checks” list spells out the reason.

A practical workflow:

1.  Run
    [`run_diagnostics()`](https://olivethree.github.io/rcicrdiagnostics/reference/run_diagnostics.md)
    once on the raw data with only the response CSV.
2.  Resolve every **fail** first.
3.  Investigate every **warn**. Either fix it, or add a short note in
    your analysis script saying why the warning is acceptable for this
    dataset (so you or a collaborator don’t re-investigate later).
4.  Once the basic checks pass, rerun with `rdata = ...`,
    `col_rt = "rt"`, and `infoval_iter = 10000` to unlock the infoVal-
    dependent checks.
5.  Only when every check is **pass** — or a consciously accepted
    **warn** — move on to
    [`rcicr::generateCI2IFC()`](https://rdrr.io/pkg/rcicr/man/generateCI2IFC.html)
    (2IFC) or your Brief-RC CI code.

## 9. Choosing a CI scaling option

One of the first decisions researchers face after diagnostics pass is
what *scaling* to apply when generating CIs. The choice is often
under-documented in published work and is a source of persistent
confusion. This section explains what scaling is, what the five options
in `rcicr` do, and which option is appropriate for which downstream
analysis.

### 9.1. What scaling is, and why it exists

When
[`rcicr::batchGenerateCI2IFC()`](https://rdrr.io/pkg/rcicr/man/batchGenerateCI2IFC.html)
(or `generateCI2IFC()`) computes a CI, the underlying math produces a
two-dimensional pixel array whose values are typically centered near
zero and span a small range — often between roughly $- 0.01$ and
$+ 0.01$, depending on signal strength and number of trials. These
numbers are the real signal: they encode how much each pixel contributes
to the participant’s mental image.

They cannot, however, be displayed as-is. Monitors render pixel
intensities between 0 (black) and 1 (white); negative values have no
display meaning, and the absolute values would be too small to see.

*Scaling* solves this display problem by transforming the CI into a
range suitable for rendering. Every CI that `rcicr` returns therefore
contains two parallel fields:

- **`ci$ci`** — the *raw* CI, exactly as produced by the weighted sum of
  noise patterns. This is your data.
- **`ci$scaled`** — the *rescaled* CI, produced by applying one of the
  transformations below. This is what gets saved as a PNG or combined
  with the base image for display.

The raw field is **unchanged** regardless of which scaling option you
pass to the CI-generating function. Only the scaled field changes. This
distinction matters for every numerical analysis you perform on a CI.

### 9.2. Five scaling options in `rcicr`

| Option        | What it does                                                                                                                          | When to consider                                                                                                                   |
|---------------|---------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| `none`        | Leaves the CI unchanged in the `$scaled` field.                                                                                       | Numerical inspection; any computation you want in raw CI units.                                                                    |
| `constant`    | $(CI + c)/(2c)$ with $c$ fixed (default $c = 0.1$). The same $c$ gives identical mapping across CIs.                                  | Visual comparability across CIs when you want to preserve relative intensity and have within-study control over the display scale. |
| `independent` | Same formula, but $c = \max|CI|$ computed separately for each CI. Each CI is stretched to $\lbrack 0,1\rbrack$ using its own range.   | Maximum visual contrast for a single CI viewed alone. *Not* for comparisons across CIs.                                            |
| `matched`     | Linearly remaps the CI to match the base image’s pixel range.                                                                         | Overlaying the CI on the base image for visual presentation; rating-task stimuli that should blend with the base face.             |
| `autoscale`   | Batch-level variant of `independent`: computes one shared constant from the widest-range CI across all CIs produced in the same call. | Sets of CIs that will be viewed side by side — for example, group-level CIs per condition.                                         |

The defaults differ by function: `batchGenerateCI2IFC()` uses
`"autoscale"` by default; `generateCI2IFC()` uses `"independent"`. That
asymmetry means two pipelines that both rely on “`rcicr` defaults” can
produce visually different images from the same underlying raw CIs.

### 9.3. Which scaling for which analysis

The short version: **numerical analyses operate on `ci$ci`;
visualization choices operate on `ci$scaled`**. The `scaling` argument
affects only the second.

The table below expands this into typical use cases.

| Your goal                                                                                                | Correct choice                                                                                     | Reasoning                                                                                                                                                                                                  |
|----------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Computing infoVal**                                                                                    | Any scaling                                                                                        | [`rcicr::computeInfoVal2IFC()`](https://rdrr.io/pkg/rcicr/man/computeInfoVal2IFC.html) operates on `ci$ci` internally. The `scaling` argument has no effect on the returned *z*-score.                     |
| **Pixel-wise correlations between CIs** (similarity)                                                     | Use `ci$ci`                                                                                        | Pearson correlation is preserved only under *uniform* linear rescalings. `independent` and `matched` apply CI-specific rescalings, which distort correlations.                                             |
| **Euclidean distance between CIs** (e.g., the objective discriminability ratio in Brinkman et al., 2019) | Use `ci$ci`                                                                                        | Same reasoning — CI-dependent rescalings change distances non-uniformly.                                                                                                                                   |
| **Producing CIs for a trait-ratings task**                                                               | `autoscale` (group of CIs viewed together) or `constant` with fixed $c$ (across-study consistency) | Raters should perceive genuine signal differences across CIs. `independent` defeats this because every CI is stretched to the same display range; a weak-signal CI looks as intense as a strong-signal CI. |
| **Saving PNG figures for a paper**                                                                       | `matched` for base-image overlays; `autoscale` for grids of CIs                                    | Pick one and document it. Using different options across figures in the same paper makes them visually incomparable even when the underlying data are the same.                                            |
| **Pixel / cluster statistical tests** (Chauvin et al., 2005)                                             | [`rcicr::plotZmap()`](https://rdrr.io/pkg/rcicr/man/plotZmap.html) (handles the raw CI internally) | Do not hand-construct a *z*-map from `ci$scaled`.                                                                                                                                                          |
| **Reporting CI magnitude or effect size**                                                                | `ci$ci`                                                                                            | Scaled CIs have arbitrary units determined by the option chosen.                                                                                                                                           |

### 9.4. Common pitfalls

- **Correlating scaled CIs.** Calling
  [`cor()`](https://rdrr.io/r/stats/cor.html) on two
  `independent`-scaled CIs correlates images that have been stretched to
  the same $\lbrack 0,1\rbrack$ range by *different* constants. The
  result is no longer a clean pixel-wise agreement. Compute correlations
  on the raw CI.

- **Using `independent` for rating-task stimuli.** A participant who
  responded weakly produces a low-signal CI. Under `independent`, that
  CI is stretched to the same display range as a strong-signal CI.
  Raters perceive both as equally intense, and rating-based analyses
  systematically underestimate signal differences across participants.

- **Mixing scaling options across studies.** Two papers that both claim
  to use “`rcicr` defaults” are not necessarily comparable:
  `batchGenerateCI2IFC()` defaults to `autoscale`, `generateCI2IFC()`
  defaults to `independent`. Always document the scaling option used in
  your methods section.

- **Believing that scaling affects infoVal.** It does not.
  `computeInfoVal2IFC()` always reads the raw CI. If two analyses give
  different infoVal values, the cause is elsewhere — in the response
  data, in the reference-distribution cache, or in the trial count — not
  in scaling. See Section 6.9 for the details.

- **Applying [`norm()`](https://rdrr.io/r/base/norm.html) or
  `sqrt(sum(x^2))` to `ci$scaled`.** When reimplementing any CI-based
  statistic by hand, operate on `ci$ci`. The scaled field is for
  rendering, not for computation.

### 9.5. Recommended defaults

When in doubt:

- **Figures in a paper**: `autoscale` for grids of CIs; `matched` for
  base-image overlays. Document the choice in methods.
- **Rating-task stimuli**: `autoscale` within a single batch; otherwise
  `constant` with a fixed `c` documented in methods.
- **Any numerical analysis** (infoVal, correlations, distances, effect
  sizes, pixel tests): compute from `ci$ci`, regardless of the scaling
  argument passed.

A concrete workflow for a typical 2IFC study:

``` r
# 1. Generate CIs with autoscale for a visually-comparable set of
#    images (useful for rating-task stimuli or figure panels).
cis <- rcicr::batchGenerateCI2IFC(
  data        = responses,
  by          = "participant_id",
  stimuli     = "stimulus",
  responses   = "response",
  baseimage   = "base",
  rdata       = "stimuli.RData",
  save_as_png = TRUE,
  scaling     = "autoscale"
)

# 2. Compute infoVal per participant -- operates on ci$ci internally.
iv <- sapply(cis, function(ci) {
  rcicr::computeInfoVal2IFC(ci, rdata = "stimuli.RData")
})

# 3. Pixel-wise similarity between two CIs -- compute on the raw CI.
r <- cor(c(cis[[1]]$ci), c(cis[[2]]$ci))
```

The PNGs produced in step 1 are visually comparable because `autoscale`
applies one shared constant across the batch. The statistical results in
steps 2 and 3 are computed on the raw CI and are therefore independent
of the scaling argument.

## 10. References

Brinkman, L., Goffin, S., van de Schoot, R., van Haren, N. E., Dotsch,
R., & Aarts, H. (2019). Quantifying the informational value of
classification images. *Behavior Research Methods*, *51*(5), 2059–2073.
<https://doi.org/10.3758/s13428-019-01232-2>

Brinkman, L., Todorov, A., & Dotsch, R. (2017). Visualising mental
representations: A primer on noise-based reverse correlation in social
psychology. *European Review of Social Psychology*, *28*(1), 333–361.
<https://doi.org/10.1080/10463283.2017.1381469>

Chauvin, A., Worsley, K. J., Schyns, P. G., Arguin, M., & Gosselin, F.
(2005). Accurate statistical tests for smooth classification images.
*Journal of Vision*, *5*(9), 659–667. <https://doi.org/10.1167/5.9.1>

Dotsch, R. (2016). *rcicr: Reverse-correlation image-classification
toolbox* \[R package, development versions\].
<https://github.com/rdotsch/rcicr>

Dotsch, R. (2023). *rcicr: Reverse correlation image classification
toolbox* (Version 1.0.1) \[R package\].
<https://github.com/rdotsch/rcicr>

Mangini, M. C., & Biederman, I. (2004). Making the ineffable explicit:
Estimating the information employed for face classifications. *Cognitive
Science*, *28*(2), 209–226.
<https://doi.org/10.1016/j.cogsci.2003.11.004>

Schmitz, M., Rougier, M., & Yzerbyt, V. (2024). Introducing the brief
reverse correlation: An improved tool to assess visual representations.
*European Journal of Social Psychology*. Advance online publication.
<https://doi.org/10.1002/ejsp.3100>

## 11. Citation and credits

If you use `rcicrdiagnostics` in your research, please cite it as:

> Oliveira, M. (2026). *rcicrdiagnostics: Data quality diagnostics for
> reverse correlation experiments in social psychology using the rcicr
> package* (Version 0.1.0) \[R package\]. Zenodo.
> <https://doi.org/10.5281/zenodo.19734757>

The DOI above is the concept DOI, which always resolves to the latest
version. For citations to a specific release, see the version-specific
DOI on the [Zenodo record
page](https://doi.org/10.5281/zenodo.19734757). A BibTeX entry and the
installed version are available from R via
`citation("rcicrdiagnostics")`.

Author: Manuel Oliveira. Development was assisted by Claude (Anthropic);
the author is responsible for all content.
