#' Check rcicr version compatibility with a 2IFC rdata file
#'
#' The `.RData` produced by `rcicr::generateStimuli2IFC()` stores a
#' `generator_version` field. When a different rcicr version is used
#' later to reconstruct CIs from that rdata, subtle numerical or API
#' changes may produce wrong results silently. This check compares the
#' generator version against the installed rcicr version and warns on
#' mismatch.
#'
#' Only applicable to the 2IFC pipeline; Brief-RC does not use a
#' generated `.RData` file.
#'
#' @param rdata Path to the 2IFC `.RData` file.
#' @param ... Unused.
#'
#' @return An [rcdiag_result()] object. `data` contains
#'   `generator_version` and `installed_version`.
#'
#' @examples
#' \dontrun{
#' check_version_compat("stimuli.RData")
#' }
#'
#' @export
check_version_compat <- function(rdata, ...) {
  label <- "rcicr version compatibility"
  validate_path(rdata, "rdata")

  e <- new.env()
  load(rdata, envir = e)
  gen_ver <- if (exists("generator_version", envir = e, inherits = FALSE)) {
    as.character(e$generator_version)
  } else {
    NA_character_
  }

  inst_ver <- if (requireNamespace("rcicr", quietly = TRUE)) {
    as.character(utils::packageVersion("rcicr"))
  } else {
    NA_character_
  }

  if (is.na(gen_ver)) {
    return(rcdiag_result(
      "warn", label,
      c(
        "The rdata file does not store a generator_version field.",
        "Cannot verify the rcicr version that produced it."
      ),
      data = list(generator_version = gen_ver, installed_version = inst_ver)
    ))
  }

  if (is.na(inst_ver)) {
    return(rcdiag_result(
      "warn", label,
      c(
        sprintf("rdata was produced by rcicr %s.", gen_ver),
        "rcicr is not installed in the current R session.",
        "Install it to generate CIs: remotes::install_github(\"rdotsch/rcicr\")"
      ),
      data = list(generator_version = gen_ver, installed_version = inst_ver)
    ))
  }

  if (gen_ver == inst_ver) {
    return(rcdiag_result(
      "pass", label,
      sprintf(
        "rdata and installed rcicr are both at version %s.", gen_ver
      ),
      data = list(generator_version = gen_ver, installed_version = inst_ver)
    ))
  }

  rcdiag_result(
    "warn", label,
    c(
      sprintf("rdata was produced by rcicr %s.", gen_ver),
      sprintf("Installed rcicr is version %s.", inst_ver),
      "Reconstructed CIs may differ from those produced at experiment time."
    ),
    data = list(generator_version = gen_ver, installed_version = inst_ver)
  )
}
