# Response-time distributional checks

Scans response times (RTs) for three kinds of pathology:

## Usage

``` r
check_rt(
  responses,
  method = c("2ifc", "briefrc"),
  col_participant = "participant_id",
  col_rt = "rt",
  fast_threshold = 200,
  slow_threshold = 5000,
  max_fast_frac = 0.05,
  max_slow_frac = 0.05,
  min_cv = 0.1,
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- method:

  Either `"2ifc"` or `"briefrc"`. Currently informational.

- col_participant:

  Participant id column.

- col_rt:

  RT column (required; the check aborts if `NULL`).

- fast_threshold:

  Milliseconds. Trials faster than this count as "fast". Default `200`.

- slow_threshold:

  Milliseconds. Trials slower than this count as "slow". Default `5000`.

- max_fast_frac:

  Fraction. Participants with more than this fraction of fast trials are
  flagged. Default `0.05` (warn) / `0.15` (fail).

- max_slow_frac:

  Fraction. Participants with more than this fraction of slow trials are
  flagged. Default `0.05` (warn).

- min_cv:

  Numeric. Participants with coefficient of variation of RT below this
  are flagged. Default `0.10`.

- ...:

  Unused.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
object. `data$per_participant` has one row per participant with columns:
`n_trials`, `mean_rt`, `median_rt`, `sd_rt`, `cv_rt`, `pct_fast`,
`pct_slow`, `is_flagged`.

## Details

1.  Implausibly fast responses (`rt < fast_threshold`, default 200 ms).
    These usually indicate the participant clicked without reading the
    stimulus.

2.  Implausibly slow responses (`rt > slow_threshold`, default 5000 ms).
    These suggest distraction or a task pause.

3.  Abnormally low within-participant RT variability (coefficient of
    variation below `min_cv`, default 0.10). A near-constant RT is a
    hint that the participant is responding mechanically.

## Examples

``` r
set.seed(1)
responses <- data.frame(
  participant_id = rep(1:3, each = 100),
  stimulus       = rep(1:100, 3),
  response       = sample(c(-1, 1), 300, replace = TRUE),
  rt             = c(
    exp(rnorm(100, 6.7, 0.4)) + 100,   # normal
    rep(150, 100),                     # all fast and constant
    exp(rnorm(100, 6.7, 0.4)) + 100
  )
)
check_rt(responses, col_rt = "rt")
#> [FAIL] Response times
#>   1 of 3 participants exceed 5% fast trials (< 200 ms).
#>   0 of 3 participants exceed 5% slow trials (> 5000 ms).
#>   1 of 3 participants have RT coefficient of variation below 0.1.
#>   1 participants exceed 15% fast trials (severe).
```
