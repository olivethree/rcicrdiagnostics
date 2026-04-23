# Check for response bias

Flags two kinds of response bias:

## Usage

``` r
check_response_bias(
  responses,
  method = c("2ifc", "briefrc"),
  col_participant = "participant_id",
  col_response = "response",
  bias_threshold = 0.6,
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- method:

  Either `"2ifc"` or `"briefrc"`.

- col_participant, col_response:

  Column names.

- bias_threshold:

  Numeric. Participants with absolute mean response exceeding this value
  are flagged. Default `0.6`, which for `{-1, 1}` coding corresponds to
  approximately 80% of responses in one direction.

- ...:

  Unused.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
object. The `data` element contains `per_participant`, a data.table with
participant id, trial count, mean response, flag for constant response,
and flag for extreme mean.

## Details

1.  Per-participant constant responding: a participant who gives the
    same response on every trial. This is almost always a serious
    problem (disengaged participant or a coding bug) and produces a
    status of `"fail"` if any such participant is present.

2.  Per-participant extreme mean: a participant whose mean response is
    further from zero than `bias_threshold`. For binary `{-1, 1}`
    coding, the default threshold of `0.6` corresponds to roughly an
    80/20 split. Status is `"warn"` if any extreme participants are
    found and no constant responders are present.

The absolute-threshold approach is more robust than MAD-scaled outlier
detection when the group is small, because MAD collapses when most
participants respond similarly.

## Examples

``` r
set.seed(1)
responses <- data.frame(
  participant_id = rep(1:4, each = 100),
  stimulus       = rep(1:100, 4),
  response       = c(
    sample(c(-1, 1), 100, replace = TRUE),
    sample(c(-1, 1), 100, replace = TRUE),
    rep(1, 100),
    sample(c(-1, 1), 100, replace = TRUE)
  )
)
check_response_bias(responses)
#> [FAIL] Response bias
#>   1 of 4 participants gave the same response on every trial.
#>   0 participants have |mean response| > 0.6 (extreme bias).
#>   Group mean response: 0.270.
```
