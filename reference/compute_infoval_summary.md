# Per-participant information-value (infoVal) summary

Computes the information value (infoVal; Brinkman et al., 2019) for
every participant and returns a pass / warn / fail summary plus a
per-participant table flagging those below the `threshold`.

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
with `participant_id`, `infoval`, and `meaningful` (logical:
`infoval >= threshold`). For Brief-RC, a `"skip"` result with an
explanatory message.

## Details

infoVal is a z-like score describing how far a participant's
classification image (CI) is from a null-response reference
distribution. Values at or below `1.96` are effectively
indistinguishable from noise; higher values indicate meaningful signal.

The 2IFC path delegates to
[`rcicr::batchGenerateCI2IFC()`](https://rdrr.io/pkg/rcicr/man/batchGenerateCI2IFC.html)
and
[`rcicr::computeInfoVal2IFC()`](https://rdrr.io/pkg/rcicr/man/computeInfoVal2IFC.html)
from the canonical `rcicr` package (Dotsch, 2016; v1.0.1 on GitHub as of
2023). Canonical `rcicr` does not expose Brief-RC-specific CI or infoVal
functions, so the Brief-RC path returns a `"skip"` result. A correct
Brief-RC infoVal requires a reference distribution matched to each
participant's trial count (not the pool size stored in the rdata), and
implementing that correctly is deferred to the companion `rcicrely`
package.

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
