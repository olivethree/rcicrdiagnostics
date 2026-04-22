# Generate noise patterns for the 2IFC and Brief-RC 12-alternative pipelines.
#
# Inputs
#   data-raw/stimuli/<any-png-or-jpeg>   your base (neutral) face image
#
# Outputs (data-raw/generated/)
#   rcicr_2ifc_stimuli.RData             rcicr stimulus parameters for 2IFC
#   stimuli_2ifc/                        rcicr's per-trial PNG pairs
#   noise_matrix_briefrc12.txt           16384 x 300 space-delimited noise matrix
#
# Requirements
#   CRAN:   data.table
#   GitHub: rcicr  (remotes::install_github("rdotsch/rcicr"))
#
# Usage
#   setwd("<repo root>")
#   source("data-raw/01_generate_noise.R")
#
# Run once. Regeneration only needed if you change the base image, image size,
# or stimulus count.

# ---- configuration --------------------------------------------------------

stim_dir  <- "data-raw/stimuli"
out_dir   <- "data-raw/generated"

img_size_2ifc       <- 256L
img_size_briefrc    <- 128L
n_stimuli           <- 300L
noise_sd_briefrc    <- 0.05
seed_2ifc           <- 1L
seed_briefrc        <- 1L

# ---- setup ----------------------------------------------------------------

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

image_paths <- list.files(
  stim_dir,
  pattern = "\\.(png|jpg|jpeg)$",
  ignore.case = TRUE,
  full.names = TRUE
)
if (length(image_paths) == 0L) {
  stop(
    "No base image found in ", stim_dir, ".\n",
    "Place a square PNG or JPEG there and re-run."
  )
}
base_path <- image_paths[1L]
cat("Using base image:", base_path, "\n")

# ---- 2IFC stimuli via rcicr ----------------------------------------------

if (!requireNamespace("rcicr", quietly = TRUE)) {
  warning(
    "rcicr is not installed; skipping 2IFC stimulus generation.\n",
    "Install with: remotes::install_github(\"rdotsch/rcicr\")"
  )
} else {
  cat("\n-- 2IFC stimuli via rcicr --\n")
  stim_2ifc_dir <- file.path(out_dir, "stimuli_2ifc")
  dir.create(stim_2ifc_dir, showWarnings = FALSE, recursive = TRUE)

  # API varies slightly between rcicr versions. The call below follows the
  # current (2.x) signature. If you get "unused argument" or similar, check
  # ?rcicr::generateStimuli2IFC and adjust.
  rcicr::generateStimuli2IFC(
    base_face_files = c(base = base_path),
    n_trials        = n_stimuli,
    img_size        = img_size_2ifc,
    stimulus_path   = stim_2ifc_dir,
    label           = "rcdiag_2ifc",
    seed            = seed_2ifc
  )

  # rcicr writes the .RData to the current working directory in some versions
  # and to stimulus_path in others. Find and normalise the location.
  found <- c(
    list.files(".",           pattern = "rcdiag_2ifc.*\\.RData$", full.names = TRUE),
    list.files(stim_2ifc_dir, pattern = "rcdiag_2ifc.*\\.RData$", full.names = TRUE)
  )
  if (length(found) > 0L) {
    dest <- file.path(out_dir, "rcicr_2ifc_stimuli.RData")
    file.copy(found[1L], dest, overwrite = TRUE)
    if (normalizePath(found[1L]) != normalizePath(dest)) file.remove(found[1L])
    cat("2IFC .RData -> ", dest, "\n", sep = "")
  } else {
    warning("Could not locate rcicr's .RData output; check your rcicr version.")
  }
  cat("2IFC stimulus PNGs -> ", stim_2ifc_dir, "\n", sep = "")
}

# ---- Brief-RC 12 noise matrix --------------------------------------------

cat("\n-- Brief-RC 12 noise matrix --\n")
set.seed(seed_briefrc)
n_pixels <- img_size_briefrc * img_size_briefrc
noise_mat <- matrix(
  rnorm(n_pixels * n_stimuli, mean = 0, sd = noise_sd_briefrc),
  nrow = n_pixels, ncol = n_stimuli
)

briefrc_out <- file.path(out_dir, "noise_matrix_briefrc12.txt")
data.table::fwrite(
  data.table::as.data.table(noise_mat),
  file    = briefrc_out,
  sep     = " ",
  col.names = FALSE,
  row.names = FALSE
)
cat(sprintf(
  "Brief-RC 12 noise matrix: %d pixels x %d stimuli (sd = %g) -> %s\n",
  nrow(noise_mat), ncol(noise_mat), noise_sd_briefrc, briefrc_out
))

cat("\nDone.\n")
