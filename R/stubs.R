# Stubs for checks not yet implemented. Each function errors informatively
# when called directly. `run_all_checks()` does not invoke these — the
# orchestrator only runs implemented checks.

not_yet_implemented <- function(fn_name, because) {
  cli::cli_abort(c(
    "{.fn {fn_name}} is not yet implemented.",
    "i" = because,
    "i" = "Track status at {.url https://github.com/olivethree/rcicrdiagnostics}."
  ))
}

#' Check whether response codes should be flipped (not yet implemented)
#'
#' Planned behaviour: compute the CI with the original response codes and
#' with the codes flipped, compare the information value of the two, and
#' flag the data as potentially inverted if the flipped version has a
#' substantially higher infoVal.
#'
#' @param ... Any arguments; ignored.
#'
#' @return Not implemented. Currently calls [cli::cli_abort()].
#'
#' @export
check_response_inversion <- function(...) {
  not_yet_implemented(
    "check_response_inversion",
    "Requires CI generation (rcicr for 2IFC, noise-matrix multiplication for briefRC) and a robust infoVal implementation."
  )
}

#' Check stimulus alignment with rdata / noise matrix (not yet implemented)
#'
#' Planned behaviour: verify that stimulus numbers in the response data
#' align with the columns of the noise matrix (briefRC) or the stimulus
#' parameters in the rdata file (2IFC).
#'
#' @param ... Any arguments; ignored.
#' @return Not implemented.
#' @export
check_stimulus_alignment <- function(...) {
  not_yet_implemented(
    "check_stimulus_alignment",
    "Requires inspection of rcicr rdata files (2IFC) or noise matrix validation against response data (briefRC)."
  )
}

#' Response-time diagnostics (not yet implemented)
#'
#' Planned behaviour: flag participants with implausibly fast responses
#' (e.g. under 200ms), unusually slow responses, or abnormally low
#' within-participant RT variability.
#'
#' @param ... Any arguments; ignored.
#' @return Not implemented.
#' @export
check_rt <- function(...) {
  not_yet_implemented(
    "check_rt",
    "Requires domain thresholds and per-participant RT distribution analysis."
  )
}

#' Check rcicr version compatibility (not yet implemented)
#'
#' Planned behaviour: verify that the rcicr version used to generate the
#' rdata file is compatible with the installed rcicr version used to
#' reconstruct CIs.
#'
#' @param ... Any arguments; ignored.
#' @return Not implemented.
#' @export
check_version_compat <- function(...) {
  not_yet_implemented(
    "check_version_compat",
    "Requires reading version metadata from rcicr-generated rdata files."
  )
}

#' Batch information-value summary (not yet implemented)
#'
#' Planned behaviour: compute infoVal for every participant (2IFC via
#' [rcicr::computeInfoVal2IFC()], briefRC via a standalone permutation
#' implementation) and return descriptive statistics with flags.
#'
#' @param ... Any arguments; ignored.
#' @return Not implemented.
#' @export
compute_infoval_summary <- function(...) {
  not_yet_implemented(
    "compute_infoval_summary",
    "Requires either rcicr for 2IFC or a validated standalone permutation-based infoVal for briefRC."
  )
}

#' Cross-validate infoVal against RT quality metrics (not yet implemented)
#'
#' Planned behaviour: correlate per-participant infoVal with per-participant
#' RT quality metrics (mean RT, RT variability) to detect patterns where
#' fast-responding participants have suspiciously high infoVal.
#'
#' @param ... Any arguments; ignored.
#' @return Not implemented.
#' @export
cross_validate_rt_infoval <- function(...) {
  not_yet_implemented(
    "cross_validate_rt_infoval",
    "Depends on compute_infoval_summary and check_rt."
  )
}
