# Cross-validate infoVal against RT quality

Correlates per-participant infoVal with per-participant median response
time. The check looks for two patterns that are individually plausible
but jointly suspicious:

## Usage

``` r
cross_validate_rt_infoval(
  responses,
  method = c("2ifc", "briefrc"),
  rdata,
  baseimage = "base",
  col_participant = "participant_id",
  col_stimulus = "stimulus",
  col_response = "response",
  col_rt = "rt",
  iter = 10000L,
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- method:

  `"2ifc"` or `"briefrc"`.

- rdata:

  Path to the rcicr `.RData` file.

- baseimage:

  Name of the base image in `rdata$base_face_files`.

- col_participant, col_stimulus, col_response, col_rt:

  Column names. `col_rt` is required.

- iter:

  Reference-distribution iterations. Default `10000`.

- ...:

  Unused.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
object. `data$per_participant` has `participant_id`, `infoval`,
`median_rt`. `data$correlation` is the Pearson correlation between the
two.

## Details

1.  High infoVal with fast median RT. A participant producing a
    seemingly informative CI while responding faster than others is more
    likely to have produced a spurious signal than genuine meaningful
    information — the signal may be an artefact of a button-mashing
    strategy that happens to correlate with the noise.

2.  A negative correlation between infoVal and median RT across
    participants. If fast responders systematically score higher on
    infoVal, something about the measurement is off.

The function computes `cor(infoval, median_rt)` across participants and
returns the value plus a per-participant table for further inspection.
It does not auto-exclude anyone; interpretation requires judgement about
the specific experiment.

Requires `rcicr` via
[`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md).

## Examples

``` r
if (FALSE) { # \dontrun{
cross_validate_rt_infoval(
  responses, method = "2ifc",
  rdata = "stimuli.RData",
  col_rt = "rt"
)
} # }
```
