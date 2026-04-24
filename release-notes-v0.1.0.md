# rcicrdiagnostics v0.1.0 — first tagged release

First public tagged release of `rcicrdiagnostics`, a toolkit for
data-quality diagnostics in reverse correlation experiments. Supports
both the two-image forced-choice (2IFC) pipeline through the `rcicr`
package and the Brief-RC pipeline (Schmitz, Rougier, & Yzerbyt, 2024).

## What's included

- **Diagnostic checks** (`check_*` family): response coding, trial
  counts, duplicates, response bias, reaction times, stimulus-pool
  alignment, version compatibility, response inversion.
- **Summary computations** (`compute_*` family): infoVal summary
  (wraps `rcicr::computeInfoVal2IFC`), RT × infoVal cross-validation.
- **Orchestrator** `run_diagnostics()` — runs the full battery and
  returns a pass / warn / fail report.
- **Runnable examples** under `inst/examples/` — bogus-data generators
  for 2IFC, Brief-RC 12, and Brief-RC 20, plus a base image, for
  end-to-end demonstration without needing real study data.
- **User's guide vignette** covering installation, data format
  requirements, every exported function with runnable examples,
  report interpretation, and a dedicated chapter on CI scaling
  decisions (which statistic to use for which downstream analysis:
  infoVal, pixel correlations, rating-task stimuli, figures).

## Status

The API is not yet stable; expect changes before v1.0. Distribution is
GitHub-only; no CRAN submission is planned at this stage.

## Install

```r
remotes::install_github("olivethree/rcicrdiagnostics@v0.1.0")
```

## Citation

```r
citation("rcicrdiagnostics")
```

This release will be archived on Zenodo and receive a DOI; the DOI
will be added to `inst/CITATION` and the README citation section in a
subsequent commit.
