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
the 2IFC path to the canonical `rcicr` package (Dotsch, 2016, 2023).
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

At the time of writing, the canonical `rcicr` is version 1.0.1 (2023),
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

### Response data (both pipelines)

A trial-level data frame — one row per trial — that you either load from
a CSV or build in R. At minimum it needs:

| Column           | Purpose                                                                                                                                                                                                                                               |
|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `participant_id` | Identifier for each participant. Character or integer is fine.                                                                                                                                                                                        |
| `stimulus`       | The stimulus number for that trial. Must match the numbering used when the stimuli were generated.                                                                                                                                                    |
| `response`       | The participant’s response on that trial. Coding depends on method.                                                                                                                                                                                   |
| `rt` (optional)  | Response time in milliseconds. Used by [`check_rt()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_rt.md) and [`cross_validate_rt_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/cross_validate_rt_infoval.md). |

If your column names differ, every function accepts overrides via
`col_participant`, `col_stimulus`, `col_response`, and `col_rt`.

### Response coding by method

- **`"2ifc"`**: `response` must be numeric `{-1, 1}`. The sign matters
  because the CI is a weighted sum of the per-trial noise patterns: a
  `+1` means the noise on that trial is added to the CI, a `-1` means
  it’s subtracted. If responses are coded `{0, 1}` instead, the
  “subtract” information is lost and the CI comes out close to blank.
  This is one of the most common silent failures in RC data; Section 6.1
  detects it.
- **`"briefrc"`**: Following Schmitz et al. (2024), each trial is
  recorded as one row with `stimulus` = id of the chosen noise pattern
  and `response` = `+1` if the participant picked the oriented version
  (`base + noise`) or `-1` if the inverted version (`base - noise`).
  This matches how rcicr’s `genCI` adaptation is built.

### Auxiliary inputs by method

- **2IFC** uses the `.RData` file produced by
  [`rcicr::generateStimuli2IFC()`](https://rdrr.io/pkg/rcicr/man/generateStimuli2IFC.html)
  plus the base image (the neutral face the noise was added to). Pass
  these as `rdata` and `base_image`.
- **Brief-RC** uses a **noise matrix**: a plain-text file with pixels as
  rows and stimuli as columns, each cell a real-valued noise weight. For
  128×128 images and 300 stimuli, the matrix is 16 384 rows × 300
  columns. Pass as `noise_matrix`.

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
      - compute_infoval_summary (need rdata + infoval_iter)
      - check_response_inversion (needs infoval)
      - cross_validate_rt_infoval (needs infoval)

nothing has failed — you just haven’t handed
[`run_diagnostics()`](https://olivethree.github.io/rcicrdiagnostics/reference/run_diagnostics.md)
the extra inputs those checks need. Section 7.1 walks through exactly
what to pass for each one so you can progressively unlock them.

## 5. The result object

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

## 6. The checks one by one

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

The 2IFC path delegates the heavy lifting to the canonical `rcicr`
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

- **pass** if ≥ 80% of participants have `infoval >= threshold`;
- **warn** if 50–80% do;
- **fail** otherwise (your data is mostly noise).

Use `$data$per_participant` to pull out individual participants’ scores
and the `meaningful` flag for downstream exclusion.

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

### 7.1. Unlocking the skipped checks

By default — with only `responses` and `method` — only the four basic
checks run. The remaining six are skipped and listed; each needs a
specific additional input. The table is the full map:

| Skipped check                                                                                                         | How to unlock                                                                  |
|-----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| [`check_rt()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_rt.md)                                   | pass `col_rt = "rt"` (and make sure that column exists in `responses`)         |
| [`check_stimulus_alignment()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_stimulus_alignment.md)   | pass `rdata = "..."` (2IFC) or `noise_matrix = "..."` (Brief-RC)               |
| [`check_version_compat()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_version_compat.md)           | pass `rdata = "..."` (2IFC only)                                               |
| [`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md)     | pass `rdata` **and** `infoval_iter` (e.g. `10000`)                             |
| [`check_response_inversion()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_response_inversion.md)   | pass `rdata` **and** `infoval_iter` (runs infoVal twice, so takes ~2× as long) |
| [`cross_validate_rt_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/cross_validate_rt_infoval.md) | pass `rdata`, `infoval_iter`, **and** `col_rt`                                 |

`infoval_iter` is `NULL` by default because the reference-distribution
simulation at `10000` iterations takes a few minutes on the first call.
`rcicr` caches the distribution inside the `.RData` file, so subsequent
calls on the same file are fast — you pay that cost once per rdata.

A full-battery invocation for a 2IFC analysis looks like this:

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
# When every input is supplied, the "Skipped checks" block disappears
# and you get all 10 checks in the report.
```

For Brief-RC, swap `rdata` for `noise_matrix` at the
`check_stimulus_alignment` step. The infoVal-based checks (Sections
6.9–6.11) will each return a `"skip"` result for Brief-RC regardless of
what you pass — canonical `rcicr` does not ship Brief-RC infoVal
machinery. See Section 6.9 for the full explanation.

**On the name**:
[`run_diagnostics()`](https://olivethree.github.io/rcicrdiagnostics/reference/run_diagnostics.md)
runs *every check whose required inputs are available*, not “every check
unconditionally”. The printed `Skipped checks` list is how it keeps that
honest — nothing runs halfway, nothing errors silently. Treat the list
as a to-do: each line tells you exactly what to add to the call to
unlock that check.

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

### 9.2. The five scaling options in `rcicr`

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
