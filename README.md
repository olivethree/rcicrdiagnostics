# rcicrdiagnostics

A toolkit for data-quality diagnostics in reverse correlation experiments. Covers 2IFC (rcicr) and Brief-RC pipelines.

> **Status:** in development. The API is not yet stable and the package is not on CRAN. Distribution is GitHub-only.

## What it does

Reverse correlation pipelines fail silently. Miscoded responses, misaligned stimulus numbers, mismatched `.RData` parameter files, and malformed noise matrices all produce CIs and infoVal scores that look plausible but are wrong. `rcicrdiagnostics` provides a systematic battery of checks to run *before* interpreting any CI or computing reliability.

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

If you use `rcicrdiagnostics` in your research, please cite it as:

> Oliveira, M. (2026). *rcicrdiagnostics: Diagnostics Toolkit for Reverse Correlation Experiments* (R package version 0.0.0.9000). <https://github.com/olivethree/rcicrdiagnostics>

A BibTeX entry and up-to-date version string are available via:

```r
citation("rcicrdiagnostics")
```

A Zenodo DOI will be added at first tagged release.

Please also cite the methodological sources appropriate to your pipeline:

- **2IFC**: Dotsch (2016), Brinkman et al. (2019) for infoVal
- **Brief-RC**: Schmitz, Rougier, and Yzerbyt (2024)

Full references are listed at the end of the [tutorial](https://olivethree.github.io/rcicrdiagnostics/articles/tutorial.html).

## License

Released under the MIT License. See [LICENSE](LICENSE) (copyright notice) and [LICENSE.md](LICENSE.md) (full text).

## Credits

Manuel Oliveira — <https://www.manueloliveira.nl>. Development was assisted by Claude (Anthropic); the author is responsible for all content and decisions.
