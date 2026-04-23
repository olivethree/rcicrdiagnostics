# Check stimulus ids align with the stimulus pool

Verifies that the `stimulus` column in the response data refers to valid
indices in the stimulus pool defined by the supplied `.RData` (2IFC) or
noise-matrix file (Brief-RC). An off-by-one error in the response
export, or a mismatch between the pool used in the experiment and the
pool passed to the diagnostics, is the most common silent source of
wrong CIs — this check catches both.

## Usage

``` r
check_stimulus_alignment(
  responses,
  method = c("2ifc", "briefrc"),
  rdata = NULL,
  noise_matrix = NULL,
  col_stimulus = "stimulus",
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- method:

  Either `"2ifc"` or `"briefrc"`.

- rdata:

  Path to the `.RData` file produced by
  [`rcicr::generateStimuli2IFC()`](https://rdrr.io/pkg/rcicr/man/generateStimuli2IFC.html).
  Required when `method = "2ifc"`.

- noise_matrix:

  Path to the Brief-RC noise-matrix text file, or a numeric matrix
  already in memory. Required when `method = "briefrc"`.

- col_stimulus:

  Name of the stimulus column in `responses`.

- ...:

  Unused.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
object. `data` contains `pool_size` (number of stimuli in the pool),
`n_stim_used` (unique stimuli referenced in the data), `out_of_range`
(stimulus ids outside `1..pool_size`), and `unused_stimuli` (pool ids
never referenced).

## Examples

``` r
mat <- matrix(rnorm(16384 * 10, sd = 0.05), nrow = 16384, ncol = 10)
responses <- data.frame(
  participant_id = rep(1:2, each = 20),
  stimulus       = sample.int(10, 40, replace = TRUE),
  response       = sample(c(-1, 1), 40, replace = TRUE)
)
check_stimulus_alignment(
  responses, method = "briefrc", noise_matrix = mat
)
#> [PASS] Stimulus alignment
#>   10 of 10 pool stimuli are referenced in the response data.
```
