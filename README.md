# rcicrdiagnostics

Pre-flight data-quality diagnostics for reverse correlation experiments.

> **Status:** in development. The API is not yet stable and the package is not on CRAN. Distribution is GitHub-only.

## What it does

Reverse correlation pipelines fail silently. Miscoded responses, misaligned stimulus numbers, mismatched `.RData` parameter files, and malformed noise matrices all produce CIs and infoVal scores that look plausible but are wrong. `rcicrdiagnostics` is a systematic battery of checks to run *before* interpreting any CI or computing reliability.

It supports both pipelines through a single `method` argument:

- **2IFC** — the standard two-image forced-choice pipeline, using the [`rcicr`](https://github.com/rdotsch/rcicr) package for CI and infoVal.
- **Brief-RC** — the Schmitz et al. (2024) multi-alternative variant, which uses direct noise-matrix multiplication and ships no `.RData` file.

Exported functions fall into three families:

- `check_*()` — individual diagnostics (response coding, stimulus alignment, trial counts, duplicates, response bias, RT, version compatibility, response inversion).
- `compute_*()` — summary computations (batch infoVal with flags, RT × infoVal cross-validation).
- `run_diagnostics()` — orchestrator that runs the full battery and returns a formatted pass/warn/fail report.

## Installation

From GitHub (primary):

```r
# install.packages("remotes")
remotes::install_github("olivethree/rcicrdiagnostics")
```

Or with `pak`:

```r
# install.packages("pak")
pak::pak("olivethree/rcicrdiagnostics")
```

`rcicr` (Dotsch, 2016) is a **Suggests** dependency needed only for the 2IFC infoVal-based checks. Brief-RC users do not need it; the Brief-RC infoVal path is intentionally skipped in this package (a proper Brief-RC infoVal implementation is planned for the companion `rcicrely`). To install `rcicr`, follow Dotsch's own instructions:

```r
# Stable release (CRAN):
install.packages("rcicr")

# Or latest development version from GitHub:
install.packages("devtools")
devtools::install_github("rdotsch/rcicr")
```

## Quick start

### 2IFC

```r
library(rcicrdiagnostics)

responses <- read.csv(system.file("extdata", "example_2ifc_responses.csv",
                                  package = "rcicrdiagnostics"))
rdata     <- system.file("extdata", "example_rcicr_stimuli.RData",
                         package = "rcicrdiagnostics")

report <- run_diagnostics(responses, method = "2ifc", rdata = rdata)
print(report)
```

### Brief-RC

```r
library(rcicrdiagnostics)

responses    <- read.csv(system.file("extdata", "example_briefrc_responses.csv",
                                     package = "rcicrdiagnostics"))
noise_matrix <- system.file("extdata", "example_noise_matrix_128.txt",
                            package = "rcicrdiagnostics")
base_image   <- system.file("extdata", "example_base_face_128.png",
                            package = "rcicrdiagnostics")

report <- run_diagnostics(responses, method = "briefrc",
                         noise_matrix = noise_matrix,
                         base_image   = base_image)
print(report)
```

## Tutorial

A comprehensive walk-through covering installation, data format
requirements, every implemented function, and how to interpret the
report:

- Web: <https://olivethree.github.io/rcicrdiagnostics/articles/tutorial.html>
- Locally, after installation:

    ```r
    vignette("tutorial", package = "rcicrdiagnostics")
    ```

## Documentation

Full function reference: <https://olivethree.github.io/rcicrdiagnostics/>

Pipeline-specific quickstarts (`quickstart-2ifc`, `quickstart-briefrc`)
are planned once the CI-generation–dependent checks land.

## Citation

```r
citation("rcicrdiagnostics")
```

If you use the Brief-RC pipeline, also cite:

> Schmitz, M., et al. (2024). *Brief reverse correlation.*

## License

Released under CC0 1.0 Universal. See [LICENSE](LICENSE).

## Author

Manuel Oliveira — <https://www.manueloliveira.nl>

## Acknowledgements

This package was co-developed with the assistance of [Claude](https://www.anthropic.com/claude) (Anthropic).
