# rcicrdiagnostics

A toolkit for data-quality diagnostics in reverse correlation experiments. Covers 2IFC (rcicr) and Brief-RC pipelines.

[![DOI](https://zenodo.org/badge/1219369681.svg)](https://doi.org/10.5281/zenodo.19734757)

> **Status:** in development. The API is not yet stable and the package is not on CRAN. Distribution is GitHub-only.

## What it does

A toolkit that runs data-quality diagnostics for reverse correlation experiments. Supports both the standard two-image forced-choice (2IFC) pipeline via the [`rcicr`](https://github.com/rdotsch/rcicr) package (Dotsch, 2016, 2023) and the Brief-RC pipeline (Schmitz, Rougier, & Yzerbyt, 2024). Designed to be run before computing classification images or information values so that silent data-processing errors are caught early.

The diagnostics catch failures that neither base R nor `rcicr` catches because they live in the *match* between your response data and the files that generated the stimuli — miscoded responses, misaligned stimulus numbers, mismatched `.RData` parameter files, malformed noise matrices.

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

The expected inputs are a **response CSV** (columns `participant_id`, `stimulus`, `response`, optionally `rt`; response coding `{-1, +1}`) plus one auxiliary file per pipeline: an rcicr stimulus `.RData` for 2IFC, or a space-delimited noise matrix for Brief-RC. See the [user's guide](https://olivethree.github.io/rcicrdiagnostics/articles/tutorial.html) for full column specifications.

### With your own data

```r
library(rcicrdiagnostics)

# --- 2IFC ---
responses <- read.csv("path/to/your/responses.csv")
report    <- run_diagnostics(
  responses,
  method = "2ifc",
  rdata  = "path/to/your/rcicr_stimuli.RData",
  col_rt = "rt"   # omit if you do not have reaction times
)
print(report)

# --- Brief-RC (12 or 20 alternatives; row format is the same) ---
responses <- read.csv("path/to/your/responses.csv")
report    <- run_diagnostics(
  responses,
  method       = "briefrc",
  noise_matrix = "path/to/your/noise_matrix.txt",
  col_rt       = "rt"
)
print(report)
```

### Try it on synthetic data (no real study needed)

The package ships runnable example scripts under `inst/examples/` that generate a small synthetic dataset for each pipeline and demonstrate the diagnostic battery end-to-end. They use an AI-generated base face (from *thispersondoesnotexist.com*; no real person depicted).

```r
library(rcicrdiagnostics)

# Where to put the generated files (default is a tempdir folder).
OUTPUT_DIR <- file.path(getwd(), "rcicrdiag-demo")

# Generate stimuli (~30–60 s) and bogus responses, then run diagnostics
# on each pipeline:
source(system.file("examples", "01_generate_stimuli.R",           package = "rcicrdiagnostics"))
source(system.file("examples", "02a_bogus_responses_2ifc.R",      package = "rcicrdiagnostics"))
source(system.file("examples", "02b_bogus_responses_briefrc12.R", package = "rcicrdiagnostics"))
source(system.file("examples", "02c_bogus_responses_briefrc20.R", package = "rcicrdiagnostics"))
source(system.file("examples", "03_run_diagnostics_demo.R",       package = "rcicrdiagnostics"))
```

See [`inst/examples/README.md`](inst/examples/README.md) for what each script does, expected runtimes, and the participant "truth tables" that let you confirm the checks flagged the right participants.

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

> Oliveira, M. (2026). *rcicrdiagnostics: Data quality diagnostics for reverse correlation experiments in social psychology using the rcicr package* (Version 0.1.0) [R package]. Zenodo. <https://doi.org/10.5281/zenodo.19734757>

The concept DOI above always resolves to the latest version. For citations to a specific release, use the version-specific DOI available on the [Zenodo record page](https://doi.org/10.5281/zenodo.19734757). A BibTeX entry and the installed version are available via:

```r
citation("rcicrdiagnostics")
```

Please also cite the methodological sources appropriate to your pipeline:

- **2IFC**: Dotsch (2016, 2023) for the `rcicr` package; Brinkman et al. (2019) for infoVal
- **Brief-RC**: Schmitz, Rougier, and Yzerbyt (2024)

Full references are listed at the end of the [tutorial](https://olivethree.github.io/rcicrdiagnostics/articles/tutorial.html).

## License

Released under the MIT License. See [LICENSE](LICENSE) (copyright notice) and [LICENSE.md](LICENSE.md) (full text).

## Credits

Manuel Oliveira — <https://www.manueloliveira.nl>. Development was assisted by Claude (Anthropic); the author is responsible for all content and decisions.
