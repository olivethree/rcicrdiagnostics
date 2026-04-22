#' Read a Brief-RC noise matrix text file
#'
#' Reads a space-delimited text file where each column is one stimulus and
#' each row is one pixel. For 128x128 images this produces a 16384-row
#' matrix; for 256x256 it produces a 65536-row matrix. Uses
#' [data.table::fread()] for speed.
#'
#' @param path Path to a space-delimited text file of floats.
#' @param header Logical. Does the file have a header row? Defaults to
#'   `FALSE`, matching the Schmitz et al. (2024) convention.
#'
#' @return A numeric matrix with `n_pixels` rows and `n_stimuli` columns.
#'
#' @examples
#' \dontrun{
#' mat <- read_noise_matrix("noise_matrix_128.txt")
#' dim(mat)
#' }
#'
#' @export
read_noise_matrix <- function(path, header = FALSE) {
  validate_path(path, "path")
  dt <- data.table::fread(path, header = header)
  mat <- as.matrix(dt)
  dimnames(mat) <- NULL
  if (!is.numeric(mat)) {
    cli::cli_abort(c(
      "Noise matrix at {.path {path}} is not numeric.",
      "i" = "Column classes: {.val {vapply(dt, class, character(1L))}}"
    ))
  }
  mat
}

#' Validate a Brief-RC noise matrix
#'
#' Runs basic sanity checks on a noise matrix: numeric, finite, expected
#' dimensions. Returns an [rcdiag_result()] with status `"pass"`, `"warn"`,
#' or `"fail"` rather than aborting, because users typically want to see
#' all problems at once, not just the first.
#'
#' @param mat A numeric matrix, as returned by [read_noise_matrix()].
#' @param expected_pixels Optional integer. If supplied, checks that
#'   `nrow(mat) == expected_pixels`. For example, 128*128 = 16384.
#' @param expected_stimuli Optional integer. If supplied, checks that
#'   `ncol(mat) == expected_stimuli`.
#'
#' @return An object of class `"rcdiag_result"`.
#'
#' @examples
#' mat <- matrix(rnorm(16384 * 10, sd = 0.05), nrow = 16384, ncol = 10)
#' validate_noise_matrix(mat, expected_pixels = 16384, expected_stimuli = 10)
#'
#' @export
validate_noise_matrix <- function(mat,
                                  expected_pixels = NULL,
                                  expected_stimuli = NULL) {
  label <- "Noise matrix"
  detail <- character()
  status <- "pass"

  if (!is.matrix(mat) || !is.numeric(mat)) {
    return(rcdiag_result(
      "fail", label,
      "Argument is not a numeric matrix."
    ))
  }

  n_finite <- sum(is.finite(mat))
  n_total <- length(mat)
  if (n_finite < n_total) {
    status <- "fail"
    detail <- c(
      detail,
      sprintf(
        "%d of %d entries are NA/NaN/Inf.",
        n_total - n_finite, n_total
      )
    )
  }

  if (!is.null(expected_pixels) && nrow(mat) != expected_pixels) {
    status <- "fail"
    detail <- c(
      detail,
      sprintf(
        "Expected %d rows (pixels), found %d.",
        expected_pixels, nrow(mat)
      )
    )
  }

  if (!is.null(expected_stimuli) && ncol(mat) != expected_stimuli) {
    status <- "fail"
    detail <- c(
      detail,
      sprintf(
        "Expected %d columns (stimuli), found %d.",
        expected_stimuli, ncol(mat)
      )
    )
  }

  if (status == "pass") {
    detail <- sprintf(
      "%d pixels x %d stimuli, all finite. Range: [%.3g, %.3g].",
      nrow(mat), ncol(mat), min(mat), max(mat)
    )
  }

  rcdiag_result(
    status, label, detail,
    data = list(
      dim = dim(mat),
      range = range(mat),
      n_missing = n_total - n_finite
    )
  )
}
