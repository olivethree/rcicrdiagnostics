# 01_generate_stimuli.R ------------------------------------------------------
# Generate the stimulus artifacts needed by the 2IFC and Brief-RC pipelines.
#
# Outputs written to OUTPUT_DIR (default: tempdir() subfolder):
#   rcicr_2ifc_stimuli.RData        # 2IFC stimulus bundle (rcicr format)
#   noise_matrix_briefrc.txt        # Brief-RC noise matrix (shared by 12 & 20)
#
# Requires:
#   rcicr, foreach, jpeg, png      (install if missing)

# ---- user-configurable paths ----------------------------------------------

if (!exists("OUTPUT_DIR")) {
  OUTPUT_DIR <- file.path(tempdir(), "rcicrdiagnostics-examples")
}
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# Base image ships alongside this script.
.find_script_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) {
    f <- sys.frame(i)
    if (exists("ofile", envir = f, inherits = FALSE)) {
      v <- get("ofile", envir = f)
      if (is.character(v) && nzchar(v)) return(dirname(normalizePath(v)))
    }
  }
  NULL
}
.script_dir <- .find_script_dir()
BASE_IMAGE <- if (!is.null(.script_dir)) {
  file.path(.script_dir, "base_face.jpg")
} else {
  system.file("examples", "base_face.jpg", package = "rcicrdiagnostics")
}
if (!file.exists(BASE_IMAGE)) {
  stop("Base image not found at ", BASE_IMAGE)
}

# ---- parameters (kept small for quick demo) -------------------------------

IMG_SIZE       <- 128L       # 128x128 keeps rcicr generation under ~60 s
N_STIMULI      <- 300L       # shared pool size across 2IFC and Brief-RC
NOISE_SD       <- 0.05       # Brief-RC noise standard deviation
SEED           <- 1L

# ---- dependencies ---------------------------------------------------------

for (pkg in c("rcicr", "foreach", "jpeg", "png", "data.table")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Please install '", pkg, "' before running this example.")
  }
}
# rcicr uses foreach::`%dopar%` internally but does not re-export it.
if (!"package:foreach" %in% search()) attachNamespace("foreach")

# ---- helper: grayscale + center-crop + nearest-neighbour resize -----------

normalise_image <- function(path, target_size) {
  ext <- tolower(tools::file_ext(path))
  img <- switch(
    ext,
    jpg  = jpeg::readJPEG(path),
    jpeg = jpeg::readJPEG(path),
    png  = png::readPNG(path),
    stop("Unsupported image extension: ", ext)
  )
  if (length(dim(img)) == 3L) {
    if (dim(img)[3L] == 4L) img <- img[, , 1:3]
    img <- 0.299 * img[, , 1L] + 0.587 * img[, , 2L] + 0.114 * img[, , 3L]
  }
  if (nrow(img) != ncol(img)) {
    sz <- min(nrow(img), ncol(img))
    r_off <- (nrow(img) - sz) %/% 2L
    c_off <- (ncol(img) - sz) %/% 2L
    img <- img[(r_off + 1L):(r_off + sz), (c_off + 1L):(c_off + sz)]
  }
  if (nrow(img) != target_size) {
    idx <- round(seq(1, nrow(img), length.out = target_size))
    img <- img[idx, idx]
  }
  out <- tempfile(fileext = ".jpg")
  jpeg::writeJPEG(img, out, quality = 0.95)
  out
}

# ---- 2IFC stimulus bundle -------------------------------------------------

message("[1/2] Generating 2IFC stimulus bundle (~30-60 s)...")
normalised_path <- normalise_image(BASE_IMAGE, IMG_SIZE)
stim_dir_2ifc <- file.path(OUTPUT_DIR, "stimuli_2ifc_png")
dir.create(stim_dir_2ifc, showWarnings = FALSE, recursive = TRUE)

# ncores = 1 avoids a macOS-specific PSOCK-worker race with rcicr.
rcicr::generateStimuli2IFC(
  base_face_files = list(base = normalised_path),
  n_trials        = N_STIMULI,
  img_size        = IMG_SIZE,
  stimulus_path   = stim_dir_2ifc,
  label           = "rcdiag_demo",
  seed            = SEED,
  ncores          = 1L
)

# rcicr writes `<label>_*.Rdata` (lowercase). Locate and rename.
found <- c(
  list.files(".",             pattern = "rcdiag_demo.*\\.Rdata$",
             ignore.case = TRUE, full.names = TRUE),
  list.files(stim_dir_2ifc,   pattern = "rcdiag_demo.*\\.Rdata$",
             ignore.case = TRUE, full.names = TRUE)
)
if (length(found) == 0L) {
  stop("rcicr did not produce a .RData file. Check your rcicr installation.")
}
rdata_path <- file.path(OUTPUT_DIR, "rcicr_2ifc_stimuli.RData")
file.copy(found[1L], rdata_path, overwrite = TRUE)
if (normalizePath(found[1L]) != normalizePath(rdata_path)) {
  file.remove(found[1L])
}

# ---- Brief-RC noise matrix (shared by 12 and 20 variants) -----------------

message("[2/2] Generating Brief-RC noise matrix...")
set.seed(SEED)
n_pixels  <- IMG_SIZE * IMG_SIZE
noise_mat <- matrix(
  rnorm(n_pixels * N_STIMULI, mean = 0, sd = NOISE_SD),
  nrow = n_pixels, ncol = N_STIMULI
)
noise_path <- file.path(OUTPUT_DIR, "noise_matrix_briefrc.txt")
data.table::fwrite(
  data.table::as.data.table(noise_mat),
  file      = noise_path,
  sep       = " ",
  col.names = FALSE
)

message(
  "Done. Outputs in: ", OUTPUT_DIR, "\n",
  "  2IFC stimulus bundle:  rcicr_2ifc_stimuli.RData\n",
  "  Brief-RC noise matrix: noise_matrix_briefrc.txt\n"
)
