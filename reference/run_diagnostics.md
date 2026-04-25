# Run the full battery of diagnostic checks

Executes every implemented check and returns a
[`rcdiag_report()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_report.md)
collecting the results. Checks whose required inputs are missing are
skipped gracefully and listed in the report's `$skipped_checks` element.

## Usage

``` r
run_diagnostics(
  responses,
  method = NULL,
  rdata = NULL,
  noise_matrix = NULL,
  baseimage = "base",
  expected_n = NULL,
  col_participant = "participant_id",
  col_stimulus = "stimulus",
  col_response = "response",
  col_rt = NULL,
  infoval_iter = NULL,
  face_mask = "auto",
  with_replacement = "auto",
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- method:

  `"2ifc"` or `"briefrc"`, or `NULL` to auto-detect.

- rdata:

  Optional. Path to an rcicr `.RData` file. Enables
  [`check_stimulus_alignment()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_stimulus_alignment.md),
  [`check_version_compat()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_version_compat.md)
  (2IFC),
  [`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md),
  [`check_response_inversion()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_response_inversion.md),
  and
  [`cross_validate_rt_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/cross_validate_rt_infoval.md).

- noise_matrix:

  Optional. Path to a Brief-RC noise-matrix text file, or an
  already-loaded numeric matrix. Enables
  [`validate_noise_matrix()`](https://olivethree.github.io/rcicrdiagnostics/reference/validate_noise_matrix.md)
  and
  [`check_stimulus_alignment()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_stimulus_alignment.md)
  (Brief-RC).

- baseimage:

  Name of the base image used at stimulus-generation time (key in
  `base_face_files` in the rdata). Default `"base"`. Only consulted when
  the infoval-dependent checks run.

- expected_n:

  Optional. Passed to
  [`check_trial_counts()`](https://olivethree.github.io/rcicrdiagnostics/reference/check_trial_counts.md).

- col_participant, col_stimulus, col_response, col_rt:

  Column-name overrides.

- infoval_iter:

  Number of iterations for rcicr's reference distribution; `NULL`
  disables infoVal checks even if `rdata` is supplied. Default `NULL`
  because the reference simulation is slow and unwanted by default; set
  e.g. `10000` to enable.

- face_mask:

  Mask spec passed to
  [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md).
  Default `"auto"` (Schmitz 2024 oval). Pass `NULL` to skip the
  masked-vs- unmasked comparison, or any value
  [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
  accepts.

- with_replacement:

  Sampling regime forwarded to
  [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
  /
  [`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md)
  for the across-trials reference distribution. Default `"auto"` matches
  the standard Brief-RC convention.

- ...:

  Unused.

## Value

An object of class `rcdiag_report`.

## Details

The orchestrator auto-detects the method when only `rdata` or only
`noise_matrix` is supplied; otherwise pass `method` explicitly.

## Examples

``` r
responses <- data.frame(
  participant_id = rep(1:3, each = 100),
  stimulus       = rep(1:100, 3),
  response       = sample(c(-1, 1), 300, replace = TRUE),
  rt             = round(exp(rnorm(300, 6.7, 0.4)) + 100, 1)
)
report <- run_diagnostics(responses, method = "2ifc", col_rt = "rt")
print(report)
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
#>   Group mean response: -0.033.
#> [PASS] Response times
#>   0 of 3 participants exceed 5% fast trials (< 200 ms).
#>   0 of 3 participants exceed 5% slow trials (> 5000 ms).
#>   0 of 3 participants have RT coefficient of variation below 0.1.
#> 
#> Summary: pass=5, warn=0, fail=0, skip=0
#> 
#> Skipped checks:
#>   - check_stimulus_alignment (no rdata / noise_matrix)
#>   - check_version_compat (no rdata)
#>   - diagnose_infoval (need infoval_iter)
#>   - compute_infoval_summary (need rdata + infoval_iter)
#>   - check_response_inversion (needs infoval)
#>   - cross_validate_rt_infoval (needs infoval)
```
