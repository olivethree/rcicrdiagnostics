# Check for duplicate rows in response data

Duplicate rows in response data almost always indicate a merge bug or an
accidental double-write. This check flags two distinct cases:

## Usage

``` r
check_duplicates(
  responses,
  method = c("2ifc", "briefrc"),
  col_participant = "participant_id",
  col_stimulus = "stimulus",
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- method:

  Either `"2ifc"` or `"briefrc"`. Currently informational.

- col_participant, col_stimulus:

  Column names.

- ...:

  Unused.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
object. The `data` element contains `full_duplicates` and
`pair_duplicates` data frames of the flagged rows.

## Details

1.  Fully duplicated rows (identical across every column).

2.  Duplicated `(participant, stimulus)` pairs where the response or RT
    differs. These are harder to interpret: either the design
    legitimately repeats stimuli (in which case the check should be
    skipped), or the data pipeline glued together two runs for the same
    participant.

## Examples

``` r
responses <- data.frame(
  participant_id = c(1, 1, 1, 2),
  stimulus       = c(1, 2, 2, 1),
  response       = c(1, -1, -1, 1)
)
check_duplicates(responses)
#> [WARN] Duplicates
#>   1 of 4 rows are fully duplicated.
#>   1 rows share a (participant, stimulus) pair with differing response or RT.
```
