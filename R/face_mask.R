# -----------------------------------------------------------------------------
# face_mask() and ellipse_mask() helper.
#
# Ported (verbatim except for inlined helpers) from the companion package
# rcicrely (R/face_mask.R, v0.2.x), authored by Manuel Oliveira and licensed
# MIT. Kept in-tree so rcicrdiagnostics has no hard dependency on rcicrely.
# Geometry follows Schmitz, Rougier, & Yzerbyt (2024); see references below.
# -----------------------------------------------------------------------------

#' Oval face-region mask for a square image
#'
#' Returns a logical vector of length `prod(img_dims)` marking an
#' elliptical face region (or sub-region) centred on the image. Pass to
#' [diagnose_infoval()] (and [infoval()]) via the `mask` argument to
#' restrict both observed and reference Frobenius norms to the masked
#' region.
#'
#' Five regions are supported:
#' * `"full"` (default): the full face oval (Schmitz, Rougier, &
#'   Yzerbyt 2024 geometry).
#' * `"eyes"`: two small ellipses at typical eye positions.
#' * `"nose"`: a narrow vertical ellipse along the midline.
#' * `"mouth"`: a wide-and-short ellipse below centre.
#' * `"upper_face"`, `"lower_face"`: the top and bottom halves of the
#'   full face oval.
#'
#' All region geometries are heuristic approximations matched to a
#' typical centred face on a square base image (e.g., 256x256 KDEF
#' male). For non-default base images, tune `centre`, `half_width`,
#' and `half_height`; the sub-region geometries scale relative to that
#' ellipse.
#'
#' @param img_dims Integer `c(nrow, ncol)`, or a single integer for a
#'   square image.
#' @param region Character. One of `"full"` (default), `"eyes"`,
#'   `"nose"`, `"mouth"`, `"upper_face"`, `"lower_face"`.
#' @param centre Numeric `c(row, col)` in (0, 1) image-fraction
#'   coordinates. Default `c(0.5, 0.5)`.
#' @param half_width Full-face ellipse horizontal half-axis as a
#'   fraction of image width. Default `0.35`.
#' @param half_height Full-face ellipse vertical half-axis as a
#'   fraction of image height. Default `0.45`.
#'
#' @return Logical vector of length `prod(img_dims)`, column-major.
#'
#' @references
#' Schmitz, M., Rougier, M., & Yzerbyt, V. (2024). Introducing the
#' brief reverse correlation: an improved tool to assess visual
#' representations. *European Journal of Social Psychology*.
#' \doi{10.1002/ejsp.3100}
#'
#' @seealso [diagnose_infoval()], [infoval()].
#'
#' @examples
#' full <- face_mask(c(128L, 128L))
#' mean(full)              # ~0.49 of the image
#' eyes <- face_mask(c(128L, 128L), region = "eyes")
#' mean(eyes)              # ~0.02 of the image
#'
#' @export
face_mask <- function(img_dims,
                      region      = c("full", "eyes", "nose",
                                      "mouth", "upper_face",
                                      "lower_face"),
                      centre      = c(0.5, 0.5),
                      half_width  = 0.35,
                      half_height = 0.45) {
  region   <- match.arg(region)
  img_dims <- as.integer(img_dims)
  if (length(img_dims) == 1L) img_dims <- c(img_dims, img_dims)
  if (length(img_dims) != 2L || any(img_dims < 1L)) {
    cli::cli_abort(
      "{.arg img_dims} must be a positive length-1 or 2 integer."
    )
  }

  nr <- img_dims[1L]; nc <- img_dims[2L]
  full_oval <- ellipse_mask(img_dims, centre[1L], centre[2L],
                            half_height, half_width)

  if (region == "full") {
    return(as.vector(full_oval))
  }

  result <- matrix(FALSE, nr, nc)

  if (region == "eyes") {
    eye_row    <- centre[1L] - 0.10 * (2 * half_height)
    eye_offset <- 0.40 * half_width
    eye_hh     <- 0.10 * half_height
    eye_hw     <- 0.16 * half_width
    result <- result |
      ellipse_mask(img_dims, eye_row, centre[2L] - eye_offset,
                   eye_hh, eye_hw) |
      ellipse_mask(img_dims, eye_row, centre[2L] + eye_offset,
                   eye_hh, eye_hw)
  } else if (region == "nose") {
    nose_row <- centre[1L] + 0.05 * (2 * half_height)
    nose_hh  <- 0.20 * half_height
    nose_hw  <- 0.12 * half_width
    result <- ellipse_mask(img_dims, nose_row, centre[2L],
                           nose_hh, nose_hw)
  } else if (region == "mouth") {
    mouth_row <- centre[1L] + 0.32 * (2 * half_height)
    mouth_hh  <- 0.10 * half_height
    mouth_hw  <- 0.30 * half_width
    result <- ellipse_mask(img_dims, mouth_row, centre[2L],
                           mouth_hh, mouth_hw)
  } else if (region == "upper_face") {
    rr <- (row(matrix(0, nr, nc)) - 1L) / (nr - 1L)
    result <- full_oval & (rr < centre[1L])
  } else if (region == "lower_face") {
    rr <- (row(matrix(0, nr, nc)) - 1L) / (nr - 1L)
    result <- full_oval & (rr >= centre[1L])
  }

  # Sub-regions are intersected with the full face oval so they never
  # extend into hair / background.
  result <- result & full_oval
  as.vector(result)
}

#' @keywords internal
#' @noRd
ellipse_mask <- function(img_dims, c_row, c_col,
                         half_height, half_width) {
  nr <- img_dims[1L]; nc <- img_dims[2L]
  rr <- (row(matrix(0, nr, nc)) - 1L) / (nr - 1L) - c_row
  cc <- (col(matrix(0, nr, nc)) - 1L) / (nc - 1L) - c_col
  (rr / half_height)^2 + (cc / half_width)^2 <= 1
}

#' Plot a face mask for visual verification
#'
#' Renders a face mask so you can confirm it covers the region you
#' intended before passing it to [diagnose_infoval()] or [infoval()].
#' Accepts the same input forms the diagnostics accept: a logical or
#' numeric vector (column-major, with `img_dims` supplied), a
#' logical/numeric matrix, or a path to a PNG/JPEG mask file.
#'
#' If `base_image` is supplied, the mask is drawn as a translucent
#' overlay on top of the base face — the most useful view for
#' verifying that the mask aligns with eyes, nose, mouth, etc. The
#' base image must have the same dimensions as the mask; otherwise
#' the base is dropped with a warning.
#'
#' @param mask One of: a logical or numeric vector of length
#'   `prod(img_dims)` (column-major, as returned by [face_mask()] or
#'   [load_face_mask()]); a logical or numeric matrix; or a path to
#'   a PNG/JPEG mask file.
#' @param img_dims Integer `c(nrow, ncol)`, or a single integer for a
#'   square image. Required when `mask` is a vector; ignored
#'   otherwise.
#' @param base_image Optional path to a PNG or JPEG base face. When
#'   supplied, the mask is rendered as a translucent overlay on top.
#' @param alpha Numeric in `[0, 1]`. Overlay opacity. Default `0.5`.
#' @param col Highlight colour for the masked region. Default
#'   `"red"`.
#' @param threshold When `mask` is a numeric matrix or image path,
#'   pixels strictly above this value are treated as inside the
#'   mask. Default `0.5`. Ignored for logical input.
#' @param main Optional plot title.
#' @param ... Reserved for future use.
#'
#' @return Invisibly returns the resolved logical matrix
#'   (`nrow` x `ncol`, top-left origin).
#'
#' @seealso [face_mask()], [load_face_mask()], [diagnose_infoval()].
#'
#' @examples
#' m <- face_mask(c(128L, 128L), region = "eyes")
#' plot_face_mask(m, img_dims = c(128L, 128L), main = "eyes region")
#'
#' @export
plot_face_mask <- function(mask,
                           img_dims   = NULL,
                           base_image = NULL,
                           alpha      = 0.5,
                           col        = "red",
                           threshold  = 0.5,
                           main       = NULL,
                           ...) {
  if (!is.numeric(alpha) || length(alpha) != 1L ||
      alpha < 0 || alpha > 1) {
    cli::cli_abort("{.arg alpha} must be a single number in [0, 1].")
  }

  mat <- resolve_mask_to_matrix(mask, img_dims, threshold = threshold)
  nr <- nrow(mat); nc <- ncol(mat)

  base <- NULL
  if (!is.null(base_image)) {
    if (is.character(base_image) && length(base_image) == 1L) {
      base <- read_image_as_gray(base_image)
    } else if (is.matrix(base_image) && is.numeric(base_image)) {
      base <- base_image
    } else {
      cli::cli_abort(
        "{.arg base_image} must be a file path or a numeric matrix."
      )
    }
    if (!identical(dim(base), c(nr, nc))) {
      cli::cli_warn(c(
        "Base image dims do not match mask dims; dropping base.",
        "i" = "mask: {nr}x{nc}; base: {dim(base)[1L]}x{dim(base)[2L]}"
      ))
      base <- NULL
    } else {
      base[base < 0] <- 0
      base[base > 1] <- 1
    }
  }

  op <- graphics::par(mar = c(0.5, 0.5,
                              if (is.null(main)) 0.5 else 2, 0.5))
  on.exit(graphics::par(op), add = TRUE)

  graphics::plot.new()
  graphics::plot.window(xlim = c(0, nc), ylim = c(0, nr),
                        asp = 1, xaxs = "i", yaxs = "i")

  if (!is.null(base)) {
    graphics::rasterImage(base, 0, 0, nc, nr, interpolate = FALSE)
  } else {
    graphics::rect(0, 0, nc, nr, col = "grey90", border = NA)
  }

  rgba <- grDevices::col2rgb(col) / 255
  fill <- grDevices::rgb(rgba[1L], rgba[2L], rgba[3L], alpha = alpha)
  overlay <- matrix(grDevices::rgb(0, 0, 0, 0), nr, nc)
  overlay[mat] <- fill
  graphics::rasterImage(overlay, 0, 0, nc, nr, interpolate = FALSE)

  graphics::rect(0, 0, nc, nr, border = "grey40", lwd = 1)

  if (!is.null(main)) graphics::title(main = main)

  invisible(mat)
}

# Resolve any of the accepted mask input forms (vector + img_dims,
# matrix, or path) into a logical (nr x nc) matrix with top-left
# origin — matching the orientation read_image_as_gray() and
# face_mask() use.
#' @keywords internal
#' @noRd
resolve_mask_to_matrix <- function(mask, img_dims, threshold = 0.5) {
  if (is.character(mask) && length(mask) == 1L) {
    img <- read_image_as_gray(mask)
    return(img > threshold)
  }
  if (is.matrix(mask)) {
    if (is.logical(mask)) return(mask)
    if (is.numeric(mask)) return(mask > threshold)
    cli::cli_abort("{.arg mask} matrix must be logical or numeric.")
  }
  if (is.logical(mask) || is.numeric(mask)) {
    if (is.null(img_dims)) {
      cli::cli_abort(
        "{.arg img_dims} is required when {.arg mask} is a vector."
      )
    }
    img_dims <- as.integer(img_dims)
    if (length(img_dims) == 1L) img_dims <- c(img_dims, img_dims)
    if (length(img_dims) != 2L || any(img_dims < 1L)) {
      cli::cli_abort(
        "{.arg img_dims} must be a positive length-1 or 2 integer."
      )
    }
    if (length(mask) != prod(img_dims)) {
      cli::cli_abort(c(
        "{.arg mask} length does not match {.arg img_dims}.",
        "i" = "length(mask) = {length(mask)}, prod(img_dims) = {prod(img_dims)}"
      ))
    }
    mat <- matrix(mask, nrow = img_dims[1L], ncol = img_dims[2L])
    if (is.numeric(mat)) mat <- mat > threshold
    return(mat)
  }
  cli::cli_abort(
    "{.arg mask} must be a logical/numeric vector or matrix, or a file path."
  )
}
