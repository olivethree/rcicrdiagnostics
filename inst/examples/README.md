# rcicrdiagnostics example scripts

Runnable scripts that generate a small synthetic dataset for each of
the pipelines `rcicrdiagnostics` supports, and demonstrate
`run_diagnostics()` on them. Useful for:

- Trying the package end-to-end without collecting any real data.
- Sanity-checking an installation.
- Seeing what the expected input formats look like.

## Files

| File | What it does |
|---|---|
| `base_face.jpg` | Neutral base face (AI-generated from *thispersondoesnotexist.com*; no real person depicted). |
| `01_generate_stimuli.R` | Generates the 2IFC stimulus bundle (via `rcicr::generateStimuli2IFC`) and a Brief-RC noise matrix. Run first. |
| `02a_bogus_responses_2ifc.R` | Generates a 30-participant 2IFC response CSV. |
| `02b_bogus_responses_briefrc12.R` | Generates a 30-participant Brief-RC 12-alternative response CSV. |
| `02c_bogus_responses_briefrc20.R` | Generates a 30-participant Brief-RC 20-alternative response CSV. |
| `03_run_diagnostics_demo.R` | Loads the generated data and runs `run_diagnostics()` for each pipeline. |

Each `02*` script produces a *truth table* CSV alongside the response
CSV, documenting which participant belongs to which archetype (signal,
biased, constant, or inverted). These let you check that the
diagnostics flagged the right participants.

## How to run

From an R session, after installing the package:

```r
library(rcicrdiagnostics)

# Optional: where to write the generated files.
# Default is a folder under tempdir(); set this if you want to keep them.
OUTPUT_DIR <- file.path(getwd(), "rcicrdiag-demo")
dir.create(OUTPUT_DIR, showWarnings = FALSE)

# Source scripts from the installed location, in order:
source(system.file("examples", "01_generate_stimuli.R",          package = "rcicrdiagnostics"))
source(system.file("examples", "02a_bogus_responses_2ifc.R",     package = "rcicrdiagnostics"))
source(system.file("examples", "02b_bogus_responses_briefrc12.R", package = "rcicrdiagnostics"))
source(system.file("examples", "02c_bogus_responses_briefrc20.R", package = "rcicrdiagnostics"))
source(system.file("examples", "03_run_diagnostics_demo.R",       package = "rcicrdiagnostics"))
```

## Typical runtimes

| Step | Time |
|---|---|
| `01_generate_stimuli.R` | ~30-60 s (2IFC stimulus generation via `rcicr`, single-threaded per §7.4 of the developer notes) |
| `02a/b/c_*` | a few seconds each |
| `03_run_diagnostics_demo.R` | seconds; longer (~1 min) if `infoval_iter` is set and `rcicr` builds a reference distribution on first call |

## Using your own data instead

For a realistic study, replace the generated CSVs and `.RData` with
your own files. The expected column layout is in Section 3 of the
user's guide:

```r
vignette("tutorial", package = "rcicrdiagnostics")
```

The minimum columns are `participant_id`, `stimulus`, `response`, and
optionally `rt`. Response coding is `{-1, +1}` for both pipelines.
