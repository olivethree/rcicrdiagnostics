#' Validate that a file path exists
#'
#' @param path Character scalar. Path to validate.
#' @param arg_name Character scalar. Name of the argument in the calling
#'   function, used in the error message.
#' @return Invisibly returns `path` if it exists. Aborts otherwise.
#' @keywords internal
#' @noRd
validate_path <- function(path, arg_name = "path") {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    cli::cli_abort(
      "{.arg {arg_name}} must be a single, non-NA character string.",
      call = rlang_caller_env()
    )
  }
  if (!file.exists(path)) {
    cli::cli_abort(
      c(
        "File not found: {.path {path}}",
        "i" = "Passed as {.arg {arg_name}}."
      ),
      call = rlang_caller_env()
    )
  }
  invisible(path)
}

#' Validate that a responses data frame has the expected columns
#'
#' @param responses A data.frame or data.table.
#' @param col_participant,col_stimulus,col_response Required column names.
#' @param col_rt Optional column name. If non-NULL, must be present.
#' @return Invisibly returns `responses`. Aborts if validation fails.
#' @keywords internal
#' @noRd
validate_responses_df <- function(responses,
                                  col_participant,
                                  col_stimulus,
                                  col_response,
                                  col_rt = NULL) {
  if (!is.data.frame(responses)) {
    cli::cli_abort("{.arg responses} must be a data frame.")
  }
  required <- c(col_participant, col_stimulus, col_response)
  if (!is.null(col_rt)) required <- c(required, col_rt)
  missing_cols <- setdiff(required, names(responses))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "{.arg responses} is missing required column{?s}: {.val {missing_cols}}",
      "i" = "Available columns: {.val {names(responses)}}"
    ))
  }
  invisible(responses)
}

# Minimal substitute for rlang::caller_env() so we do not need to import rlang
# just for error-call plumbing. Returns the environment two frames up from
# where this helper is called (i.e. the caller of the function that called
# this helper).
rlang_caller_env <- function() {
  parent.frame(2L)
}

# Attach one or more packages to the search path if not already attached.
# Used for wrappers around rcicr whose internal code relies on non-exported
# infix operators (%dopar%, %>%) or on tribble being in scope.
ensure_attached <- function(pkgs) {
  for (pkg in pkgs) {
    if (paste0("package:", pkg) %in% search()) next
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cli::cli_abort(c(
        "Package {.pkg {pkg}} is required for this operation.",
        "i" = "Install it with {.code install.packages(\"{pkg}\")}."
      ))
    }
    attachNamespace(pkg)
  }
  invisible(NULL)
}

# -----------------------------------------------------------------------------
# Helpers below this line are ported from rcicrely (R/utils.R, v0.2.x).
# Same MIT license, same author. Kept here so rcicrdiagnostics has no hard
# dependency on rcicrely.
# -----------------------------------------------------------------------------

# Run `expr` under a fixed RNG seed and restore the caller's RNG state on
# exit. NULL seed means "do nothing, run with the caller's RNG".
with_seed <- function(seed, expr) {
  if (is.null(seed)) return(force(expr))
  if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    old <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    on.exit(assign(".Random.seed", old, envir = .GlobalEnv), add = TRUE)
  } else {
    on.exit(
      rm(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
      add = TRUE
    )
  }
  set.seed(seed)
  force(expr)
}

# Optional cli progress bar. Returns an id usable by progress_tick / _done,
# or NULL when show = FALSE.
progress_start <- function(total, label, show = TRUE) {
  if (!isTRUE(show)) return(NULL)
  cli::cli_progress_bar(label, total = total, clear = TRUE)
}

progress_tick <- function(id) {
  if (is.null(id)) return(invisible())
  cli::cli_progress_update(id = id)
}

progress_done <- function(id) {
  if (is.null(id)) return(invisible())
  cli::cli_progress_done(id = id)
}

# Read a PNG or JPEG and return it as a 2D grayscale numeric matrix in
# [0, 1]. Used for loading user-supplied face masks via load_face_mask().
read_image_as_gray <- function(path) {
  if (!file.exists(path)) {
    cli::cli_abort("Image file not found: {.path {path}}")
  }
  ext <- tolower(tools::file_ext(path))
  img <- switch(
    ext,
    png = {
      if (!requireNamespace("png", quietly = TRUE)) {
        cli::cli_abort(
          "Reading PNG files requires the {.pkg png} package."
        )
      }
      png::readPNG(path)
    },
    jpg = ,
    jpeg = {
      if (!requireNamespace("jpeg", quietly = TRUE)) {
        cli::cli_abort(
          "Reading JPEG files requires the {.pkg jpeg} package."
        )
      }
      jpeg::readJPEG(path)
    },
    cli::cli_abort(
      "Unsupported image extension {.val {ext}} for {.path {path}}."
    )
  )
  if (length(dim(img)) == 2L) {
    return(img)
  }
  nch <- dim(img)[3]
  if (nch >= 3L) {
    0.2126 * img[, , 1] + 0.7152 * img[, , 2] + 0.0722 * img[, , 3]
  } else {
    img[, , 1]
  }
}

#' Load a face mask from a PNG or JPEG image
#'
#' Reads an image, converts to grayscale, and thresholds to a logical
#' mask. White-on-black masks (the typical convention) become `TRUE`
#' inside the face region and `FALSE` outside.
#'
#' Use this when you have a hand-crafted or anatomically tuned mask and
#' want to feed it to [diagnose_infoval()] or [infoval()] via the `mask`
#' argument. For the standard Schmitz 2024 oval, [face_mask()] is faster
#' and adds no dependencies.
#'
#' @param path Path to a PNG or JPEG file. Reading PNG requires the
#'   `png` package; reading JPEG requires `jpeg` (both Suggests).
#' @param threshold Numeric in `[0, 1]`. Pixels with grayscale value
#'   strictly greater than this are `TRUE`. Default `0.5`.
#' @param invert If `TRUE`, the mask is inverted (useful for
#'   black-on-white masks). Default `FALSE`.
#'
#' @return Logical vector of length `prod(img_dims)`, column-major (the
#'   convention [face_mask()] also uses).
#'
#' @seealso [face_mask()], [diagnose_infoval()].
#'
#' @export
load_face_mask <- function(path, threshold = 0.5, invert = FALSE) {
  img <- read_image_as_gray(path)
  out <- img > threshold
  if (isTRUE(invert)) out <- !out
  as.vector(out)
}
