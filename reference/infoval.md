# Per-producer informational value with trial-count-matched reference

Computes a z-scored informational value (infoVal) for each producer's
classification image, using a reference distribution matched to that
producer's trial count. Handles both 2IFC and Brief-RC paradigms with a
single function: the difference is entirely in what the user passes as
`noise_matrix`.

## Usage

``` r
infoval(
  signal_matrix,
  noise_matrix,
  trial_counts,
  iter = 10000L,
  mask = NULL,
  with_replacement = c("auto", TRUE, FALSE),
  cache_path = NULL,
  seed = NULL,
  progress = TRUE
)
```

## Arguments

- signal_matrix:

  Pixels x participants numeric matrix of raw masks (one column per
  producer).

- noise_matrix:

  Pixels x pool-size numeric matrix of noise patterns. Each column is
  one pool item; the column index is the stimulus id used in your
  response data. Row count must match `signal_matrix`.

- trial_counts:

  Named integer vector. For each producer, the **number of trials they
  completed** (i.e. the number of rows in their response data, before
  any duplicate-stimulus collapse). Not the number of unique chosen
  stimuli, and not the number of alternatives shown per trial. Names
  must match `colnames(signal_matrix)`.

- iter:

  Reference-distribution Monte Carlo size. Default `10000L`.

- mask:

  Optional logical vector of length `nrow(signal_matrix)`. When
  supplied, both observed and reference norms are computed on the masked
  pixel subset.

- with_replacement:

  Sampling regime for the reference distribution at the
  **across-trials** level (i.e. how stimulus ids are drawn when
  simulating a random producer). One of: `"auto"` (default), `TRUE`, or
  `FALSE`. `"auto"` matches the common Brief-RC convention: without
  replacement when a producer's trial count fits in the pool, with
  replacement otherwise. Set explicitly only if your task design departs
  from this convention (e.g. you sampled with replacement on a small
  pool); see "Sampling regime" in Details.

- cache_path:

  Optional path to an `.rds` file. When set and the file exists with a
  matching configuration (iter, n_pool, mask signature), references are
  loaded from it; otherwise computed references are written there.
  Caches reference norms only.

- seed:

  Optional integer; RNG state restored on exit.

- progress:

  Show a `cli` progress bar.

## Value

Object of class `rcdiag_infoval` with fields `$infoval`, `$norms`,
`$reference`, `$ref_median`, `$ref_mad`, `$trial_counts`, `$mask`,
`$iter`, `$n_pool`, `$seed`.

## Details

The observed statistic is the Frobenius norm of producer j's
classification image mask, optionally restricted to a logical `mask`
(e.g. an oval face region via
[`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md)):

    norm_j = sqrt(sum( signal_matrix[mask, j]^2 ))

The reference distribution for producer j is built by simulating `iter`
random masks at the same trial count `trial_counts[j]`, mirroring the
`genMask()` construction of Schmitz, Rougier, & Yzerbyt (2024):

1.  Sample `trial_counts[j]` stimulus ids from `1:n_pool` without
    replacement when `trial_counts[j] <= n_pool` (the canonical case for
    both 2IFC and Brief-RC), with replacement otherwise.

2.  Sample `trial_counts[j]` responses uniformly from `{-1, +1}`.

3.  Collapse `response` by `stim` via
    [`mean()`](https://rdrr.io/r/base/mean.html) (Brief-RC duplicate-
    stim rule).

4.  Build the mask:
    `noise_matrix[, unique_stims] %*% mean_response / n_unique_stims`.

5.  Apply `mask` (if supplied) and compute the Frobenius norm.

The per-producer z-score is `(norm_j - median(ref)) / mad(ref)`, using
the reference matched to producer j's trial count. Producers sharing a
trial count share a reference.

Trial-count matching closes a calibration gap in canonical
[`rcicr::generateReferenceDistribution2IFC()`](https://rdrr.io/pkg/rcicr/man/generateReferenceDistribution2IFC.html),
which uses the full pool size for the reference even when individual
producers see only a subset (relevant for Brief-RC).

**Sampling regime.** The reference simulation needs to mirror the regime
the experimenter used. Two questions matter:

1.  *Within-trial*: each Brief-RC trial shows `m` distinct pool items
    (e.g. m=12 for Brief-RC 12), so within a single trial sampling is
    always without replacement. This is implicit in the data format and
    does not need a function argument.

2.  *Across-trials*: pool items can or cannot reappear on later trials,
    depending on whether the experimenter sampled the pool with or
    without replacement at the presentation level. This is a design
    decision and `with_replacement` controls it.

`with_replacement = "auto"` resolves to `n_trials > n_pool`, which
matches the standard Brief-RC convention (Schmitz et al., 2024 used
without replacement when `n_trials * stim_per_trial <= pool_size`, with
replacement otherwise). Override this only when you know your design
departs from the convention. Whichever choice you make, the
observed-mask side already handles duplicate chosen stimuli correctly
because the genMask collapse rule averages duplicates by `stim` id
before the matrix multiplication.

For 2IFC, `n_trials == n_pool` by definition, both branches of the
heuristic resolve to without-replacement, and the question does not
arise.

## References

Brinkman, L., Goffin, S., van de Schoot, R., van Haren, N. E. M.,
Dotsch, R., & Aarts, H. (2019). Quantifying the informational value of
classification images. *Behavior Research Methods*, 51(5), 2059-2073.
[doi:10.3758/s13428-019-01232-2](https://doi.org/10.3758/s13428-019-01232-2)

Schmitz, M., Muller, D., & Yzerbyt, V. (2019). Comment on "Quantifying
the informational value of classification images": A miscomputation of
the infoVal metric. *Behavior Research Methods*.
[doi:10.3758/s13428-019-01295-1](https://doi.org/10.3758/s13428-019-01295-1)

Schmitz, M., Muller, D., & Yzerbyt, V. (2020). Erratum to: Comment on
"Quantifying the informational value of classification images":
Miscomputation of infoVal metric was a minor issue and is now corrected.
*Behavior Research Methods*, 52, 1800-1801.
[doi:10.3758/s13428-020-01367-7](https://doi.org/10.3758/s13428-020-01367-7)

Schmitz, M., Rougier, M., & Yzerbyt, V. (2024). Introducing the brief
reverse correlation: an improved tool to assess visual representations.
*European Journal of Social Psychology*.
[doi:10.1002/ejsp.3100](https://doi.org/10.1002/ejsp.3100)

## See also

[`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md),
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md).
