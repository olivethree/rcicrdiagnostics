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

# ---- image normalisation --------------------------------------------------
# rcicr::generateStimuli2IFC needs a square, single-channel (grayscale)
# image whose pixel dims equal img_size. It does not resize or
# convert on your behalf. We normalise into a temp file so your
# original stays untouched.

normalise_image <- function(path, target_size) {
  ext <- tolower(tools::file_ext(path))
  img <- switch(
    ext,
    jpg  = jpeg::readJPEG(path),
    jpeg = jpeg::readJPEG(path),
    png  = png::readPNG(path),
    stop("Unsupported image extension: ", ext)
  )

  # Drop alpha channel if present; collapse RGB to luminance.
  if (length(dim(img)) == 3L) {
    if (dim(img)[3L] == 4L) img <- img[, , 1:3]
    img <- img[, , 1L] * 0.299 + img[, , 2L] * 0.587 + img[, , 3L] * 0.114
  }

  # Center-crop to a square if necessary.
  if (nrow(img) != ncol(img)) {
    cat(sprintf(
      "  Image is %dx%d; center-cropping to a square.\n",
      nrow(img), ncol(img)
    ))
    sz <- min(nrow(img), ncol(img))
    r_off <- (nrow(img) - sz) %/% 2L
    c_off <- (ncol(img) - sz) %/% 2L
    img <- img[(r_off + 1L):(r_off + sz), (c_off + 1L):(c_off + sz)]
  }

  # Nearest-neighbour resize. Test data doesn't need bilinear smoothing.
  if (nrow(img) != target_size) {
    cat(sprintf(
      "  Resizing from %dx%d to %dx%d (nearest-neighbour).\n",
      nrow(img), ncol(img), target_size, target_size
    ))
    idx <- round(seq(1, nrow(img), length.out = target_size))
    img <- img[idx, idx]
  }

  out <- tempfile(fileext = ".jpg")
  jpeg::writeJPEG(img, out, quality = 0.95)
  out
}

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

  # rcicr uses `foreach(...) %dopar%` internally but doesn't re-export
  # `%dopar%`. Attach foreach so the operator is found at evaluation time.
  if (!requireNamespace("foreach", quietly = TRUE)) {
    stop("rcicr needs 'foreach'. install.packages('foreach').")
  }
  if (!requireNamespace("jpeg", quietly = TRUE)) {
    stop("Image normalisation needs 'jpeg'. install.packages('jpeg').")
  }
  if (!requireNamespace("png", quietly = TRUE)) {
    stop("Image normalisation needs 'png'. install.packages('png').")
  }
  library(foreach)

  cat("Normalising base image for rcicr...\n")
  normalised_path <- normalise_image(base_path, img_size_2ifc)

  # ncores = 1 avoids a known issue on macOS where PSOCK workers die
  # during rcicr's foreach loop (the ~78 MB stimuli array gets serialized
  # to each worker, racing with socket shutdown). With one worker the
  # loop completes cleanly and rcicr's post-loop save() actually runs.
  rcicr::generateStimuli2IFC(
    base_face_files = list(base = normalised_path),
    n_trials        = n_stimuli,
    img_size        = img_size_2ifc,
    stimulus_path   = stim_2ifc_dir,
    label           = "rcdiag_2ifc",
    seed            = seed_2ifc,
    ncores          = 1L
  )

  # rcicr saves to stimulus_path/${label}_seed_${seed}_time_<ts>.Rdata
  # (lowercase 'Rdata'). Match case-insensitively and search both
  # stimulus_path and the working directory for older rcicr versions.
  found <- c(
    list.files(".",           pattern = "rcdiag_2ifc.*\\.Rdata$",
               ignore.case = TRUE, full.names = TRUE),
    list.files(stim_2ifc_dir, pattern = "rcdiag_2ifc.*\\.Rdata$",
               ignore.case = TRUE, full.names = TRUE)
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
