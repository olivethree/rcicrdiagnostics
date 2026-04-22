# data-raw/

Developer-side scripts that generate the fake datasets used to exercise
the diagnostic checks. Nothing here ships with the installed package —
`data-raw/` is listed in `.Rbuildignore` and `data-raw/generated/` in
`.gitignore`.

## Layout

```
data-raw/
├── stimuli/                        # you put your base image here
│   └── <your_base_face>.png
├── generated/                      # script outputs land here (gitignored)
│   ├── rcicr_2ifc_stimuli.RData
│   ├── stimuli_2ifc/               # rcicr's per-trial PNGs
│   ├── noise_matrix_briefrc12.txt
│   ├── responses_2ifc.csv
│   ├── participants_2ifc.csv
│   ├── responses_briefrc12.csv
│   └── participants_briefrc12.csv
├── 01_generate_noise.R
├── 02_generate_bogus_2ifc.R
└── 02_generate_bogus_briefrc12.R
```

## Prerequisites

```r
install.packages(c("data.table"))
remotes::install_github("rdotsch/rcicr")   # only needed for 2IFC step
```

## How to run

From the repository root:

```r
setwd("<path to rcicrdiagnostics>")
source("data-raw/01_generate_noise.R")               # run once
source("data-raw/02_generate_bogus_2ifc.R")          # run any time
source("data-raw/02_generate_bogus_briefrc12.R")     # run any time
```

`01_generate_noise.R` is the slow step (rcicr writes hundreds of PNGs).
The bogus-data scripts are fast and deterministic — regenerate freely
when you want to tweak archetype counts or RT distributions.

## What the generators produce

Both bogus-data scripts use the same participant layout: 30 participants
split across three trial-count conditions (10 × 300 trials, 10 × 500,
10 × 1000) and four response archetypes chosen to exercise every check:

| Count | Archetype | What it looks like                                     | Expected check status   |
| ----- | --------- | ------------------------------------------------------ | ------------------------- |
| 20    | signal    | near-balanced responses                                | pass                      |
|  6    | biased    | ~80/20 split toward one response                       | warn (`check_response_bias`) |
|  2    | constant  | every row identical                                     | fail (`check_response_bias`) |
|  2    | inverted  | same distribution as signal, sign-flipped              | pass today; flagged later by `check_response_inversion` |

The `participants_*.csv` files in `generated/` record the true archetype
per participant, so you can confirm the diagnostics flag the right ones.

## Parameters you might want to change

Top of each script, in the `# ---- configuration ----` block:

- `n_stimuli` — pool size (default 300 across all scripts; must match).
- `img_size_2ifc`, `img_size_briefrc` — pixel dimensions.
- `trial_counts` / `archetype` — adjust the participant mix.
- `noise_sd_briefrc` — SD of the Brief-RC noise matrix entries.
