# Per-participant information-value (infoVal) summary

Computes per-participant information value (infoVal; Brinkman et al.,
2019) via the original `rcicr` 2IFC pipeline and returns a tidy
per-participant table. This is the thin compatibility wrapper around
[`rcicr::computeInfoVal2IFC()`](https://rdrr.io/pkg/rcicr/man/computeInfoVal2IFC.html).
For a richer, paradigm-agnostic diagnostic (group-mean z,
random-responder calibration check, face-mask z-lift, interpretation
bullets), see
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md).

## Usage

``` r
compute_infoval_summary(
  responses,
  method = c("2ifc", "briefrc"),
  rdata,
  baseimage = "base",
  col_participant = "participant_id",
  col_stimulus = "stimulus",
  col_response = "response",
  iter = 10000L,
  threshold = 1.96,
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- method:

  `"2ifc"` (supported) or `"briefrc"` (returns `"skip"`).

- rdata:

  Path to the rcicr `.RData` file that produced the stimuli. Required
  for 2IFC.

- baseimage:

  Name of the base image used at generation time (the key in
  `base_face_files` in the rdata). Default `"base"`.

- col_participant, col_stimulus, col_response:

  Column names.

- iter:

  Number of iterations for rcicr's reference-distribution simulation.
  Default `10000` (the rcicr-recommended value).

- threshold:

  Numeric. Participants with infoVal below this are flagged as likely
  noise. Default `1.96`.

- ...:

  Unused.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
object. For 2IFC, `data$per_participant` has one row per participant
with `participant_id`, `infoval`, and `above_threshold` (logical:
`infoval >= threshold`). For Brief-RC, a `"skip"` result pointing the
user at
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md).

## Details

Reported per-producer infoVal is paradigm- and target-dependent.
Brinkman et al. (2019, p. 12) report 54-68% of 2IFC gender participants
clearing z = 1.96 (median 3-4). Schmitz et al. (2024) report Brief-RC
infoVals below 1.96 across all conditions in both of their experiments.
The status returned here therefore does not `"fail"` on a
per-participant headcount alone: it returns `"pass"` when the median
per-participant z is positive and `"warn"` otherwise. Use
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
when you need a proper verdict (random-responder calibration +
group-mean z + masking).

The 2IFC path delegates to
[`rcicr::batchGenerateCI2IFC()`](https://rdrr.io/pkg/rcicr/man/batchGenerateCI2IFC.html)
and
[`rcicr::computeInfoVal2IFC()`](https://rdrr.io/pkg/rcicr/man/computeInfoVal2IFC.html)
from the original `rcicr` package (Dotsch, 2016; v1.0.1). The original
`rcicr` uses a pool-size reference distribution and does not expose a
Brief-RC path. The Brief-RC route here returns a `"skip"` result and
points users at
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md),
which uses an in-package native Brief-RC implementation with a
per-trial-count reference distribution.

**Side effect (2IFC).** `rcicr` caches a reference distribution inside
the supplied `rdata` file on the first call. Subsequent calls reuse it.
Copy your `rdata` beforehand if you want the original untouched.

## References

Brinkman, L., Goffin, S., van de Schoot, R., van Haren, N. E., Dotsch,
R., & Aarts, H. (2019). Quantifying the informational value of
classification images. *Behavior Research Methods*, 51(5), 2059–2073.

Dotsch, R. (2016). *rcicr: Reverse-correlation image-classification
toolbox* \[R package\]. <https://github.com/rdotsch/rcicr>

## Examples

``` r
if (FALSE) { # \dontrun{
compute_infoval_summary(
  responses, method = "2ifc",
  rdata = "stimuli.RData",
  iter = 10000
)
} # }
```
