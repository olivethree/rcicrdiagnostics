# Guided diagnostic for low or negative infoVal

Walks through six checks that explain why per-producer infoVal often
looks "low" even on healthy data, and surfaces the numbers that actually
belong in a methods section. Use this when individual producers' infoVal
z-scores look suspiciously low or negative and you want to know whether
the data is broken or merely structurally diluted.

## Usage

``` r
diagnose_infoval(
  responses,
  method = NULL,
  rdata = NULL,
  noise_matrix = NULL,
  baseimage = "base",
  col_participant = "participant_id",
  col_stimulus = "stimulus",
  col_response = "response",
  iter = 1000L,
  face_mask = "auto",
  with_replacement = "auto",
  seed = NULL,
  progress = TRUE,
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- method:

  `"2ifc"` or `"briefrc"`. If `NULL`, inferred from whichever of `rdata`
  / `noise_matrix` is supplied.

- rdata:

  Path to an rcicr `.RData` file (2IFC).

- noise_matrix:

  Path to a Brief-RC noise-matrix text file, or an already-loaded
  numeric matrix.

- baseimage:

  Name of the base image in the rdata `base_face_files` list. Default
  `"base"`. Only consulted for 2IFC.

- col_participant, col_stimulus, col_response:

  Column names.

- iter:

  Reference-distribution Monte Carlo size. Default `1000L` (a
  diagnostic-grade value). Bump to `10000` for publication numbers.

- face_mask:

  Mask specification. One of:

  - `"auto"` (default): generate a Schmitz 2024 oval via
    [`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md)
    sized to the image dims.

  - `NULL`: skip the masked-vs-unmasked comparison.

  - A logical vector of length `n_pixels`.

  - A numeric matrix matching the image dims (coerced via `> 0.5`).

  - A character path to a PNG / JPEG mask image (loaded via
    [`load_face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/load_face_mask.md)).

- with_replacement:

  Sampling regime forwarded to
  [`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md)
  for building the reference distribution at the across-trials level.
  `"auto"` (default) matches the standard Brief-RC convention (without
  replacement when a producer's trial count fits in the pool, with
  replacement otherwise). Set explicitly only if your task design
  departs from this convention. See
  [`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md)
  for details. Ignored on the 2IFC path because there `n_trials` equals
  the pool size by construction.

- seed:

  Optional integer; RNG state restored on exit.

- progress:

  Show a `cli` progress bar.

- ...:

  Unused.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md).
`data` carries the rich output:

- `random_responder_z` – numeric scalar.

- `infoval_unmasked` – `rcdiag_infoval` object (see
  [`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md)).

- `infoval_masked` – `rcdiag_infoval`; `NULL` when no mask.

- `group_mean_z_unmasked`, `group_mean_z_masked` – scalars.

- `tally` – named integer vector with counts per z band.

- `mask` – logical vector or `NULL`.

- `interpretation` – character vector of human-readable bullets.

## Details

The six steps:

1.  Simulate the reference distribution at every unique producer trial
    count present in the data.

2.  Sanity-check the reference with a simulated random responder. A
    random producer should land near `z = 0`; `|z| > 2` indicates the
    reference is mis-calibrated.

3.  Compute per-producer z unmasked.

4.  Compute per-producer z with the supplied (or auto-generated) face
    mask, and report the median masked-vs-unmasked z lift.

5.  Compute the group-mean CI's z, against a reference matched to the
    same producer count and trial counts.

6.  Tabulate per-producer z into four bands (`< -1.96`, `[-1.96, 0)`,
    `[0, 1.96)`, `>= 1.96`) and produce interpretation bullets
    summarising the evidence.

Whether per-producer z values cluster above or below the conventional
1.96 threshold is paradigm- and target-dependent. Brinkman et al. (2019)
report 68% (lab) and 54% (online) of 2IFC participants clearing 1.96 on
perceived gender, with mean per-participant infoVal 3.9 (lab) and 2.9
(online); Schmitz et al. (2024) report Brief-RC infoVals systematically
below 1.96 across all conditions in both experiments. The reportable
summary is therefore context-specific: per-producer z is useful for
exclusion decisions on individual cases. Neither paper computes a
group-mean CI's z directly, but the mathematical extension (a group-mean
CI compared against an N-producer-matched reference) is a useful
aggregate when individual-level z is noisy, and `diagnose_infoval()`
reports it.

For `method = "2ifc"`, the function calls `rcicr` to reconstruct
per-trial noise patterns from `stimuli_params` and `p` (the `.RData`
does not store the patterns themselves; see vignette "What data the
package expects"). The reconstruction is one
[`rcicr::generateNoiseImage()`](https://rdrr.io/pkg/rcicr/man/generateNoiseImage.html)
call per pool item, which is fast (seconds) but does require `rcicr` to
be installed. The Brief-RC path needs no `rcicr` dependency.

## References

Brinkman, L., Goffin, S., van de Schoot, R., van Haren, N. E. M.,
Dotsch, R., & Aarts, H. (2019). Quantifying the informational value of
classification images. *Behavior Research Methods*, 51(5), 2059-2073.

Schmitz, M., Rougier, M., & Yzerbyt, V. (2024). Introducing the brief
reverse correlation: an improved tool to assess visual representations.
*European Journal of Social Psychology*.

## See also

[`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md),
[`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md),
[`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md).

## Examples

``` r
if (FALSE) { # \dontrun{
diagnose_infoval(
  responses, method = "2ifc",
  rdata = "stimuli.RData",
  iter  = 1000
)
} # }
```
