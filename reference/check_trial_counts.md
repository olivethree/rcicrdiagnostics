# Check trial counts per participant

Counts the number of rows per participant and compares against expected
trial counts. If `expected_n` is not supplied, the check reports the
observed distribution without flagging anything. If `expected_n` is
supplied, participants whose trial count is not in the allowed set are
flagged.

## Usage

``` r
check_trial_counts(
  responses,
  expected_n = NULL,
  method = c("2ifc", "briefrc"),
  col_participant = "participant_id",
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- expected_n:

  Optional. A single integer (all participants should have this many
  trials) or a vector of allowed counts (useful for designs with
  multiple trial-count conditions, e.g. `c(300, 500, 1000)`). If `NULL`,
  no flagging occurs.

- method:

  Either `"2ifc"` or `"briefrc"`. Currently informational.

- col_participant:

  Name of the participant id column.

- ...:

  Unused. Reserved for consistency with other check functions.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
object. The `data` element contains `per_participant`, a data frame with
one row per participant and their trial count.

## Examples

``` r
responses <- data.frame(
  participant_id = rep(1:3, times = c(300, 300, 250)),
  stimulus       = 1,
  response       = 1
)
check_trial_counts(responses, expected_n = 300)
#> [FAIL] Trial counts
#>   1 of 3 participant{?s} have unexpected trial counts.
#>   Expected: {300}.
#>   Flagged counts: 3 (n=250).
```
