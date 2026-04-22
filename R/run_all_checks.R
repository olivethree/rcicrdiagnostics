#' Run the full battery of implemented diagnostic checks
#'
#' Executes every implemented check and returns a [rcdiag_report()] object
#' collecting the results. Checks that are not yet implemented are listed
#' in the report under `$skipped_checks` but are not called.
#'
#' The orchestrator auto-detects the method when only `rdata` or only
#' `noise_matrix` is supplied; otherwise pass `method` explicitly.
#'
#' @param responses A data frame of trial-level responses.
#' @param method Either `"2ifc"` or `"briefrc"`, or left as the default
#'   `NULL` to auto-detect from the supplied `rdata` / `noise_matrix`.
#' @param rdata Optional. Path to a 2IFC `.RData` file produced by
#'   [rcicr::generateStimuli2IFC()]. Not used by the current set of
#'   implemented checks; reserved for future CI-dependent checks.
#' @param noise_matrix Optional. Path to a Brief-RC noise matrix text
#'   file. Used by [validate_noise_matrix()] when supplied.
#' @param expected_n Optional. Passed through to [check_trial_counts()].
#' @param col_participant,col_stimulus,col_response,col_rt Column name
#'   overrides, passed to the individual checks.
#' @param ... Unused. Reserved for forward compatibility.
#'
#' @return An object of class `"rcdiag_report"` with elements
#'   `results` (named list of [rcdiag_result()]s), `skipped_checks`
#'   (character vector), and `method`.
#'
#' @examples
#' responses <- data.frame(
#'   participant_id = rep(1:3, each = 100),
#'   stimulus       = rep(1:100, 3),
#'   response       = sample(c(-1, 1), 300, replace = TRUE)
#' )
#' report <- run_all_checks(responses, method = "2ifc")
#' print(report)
#'
#' @export
run_all_checks <- function(responses,
                           method = NULL,
                           rdata = NULL,
                           noise_matrix = NULL,
                           expected_n = NULL,
                           col_participant = "participant_id",
                           col_stimulus = "stimulus",
                           col_response = "response",
                           col_rt = NULL,
                           ...) {
  method <- resolve_method(method, rdata, noise_matrix)

  results <- list()

  results$response_coding <- check_response_coding(
    responses,
    method = method,
    col_response = col_response
  )

  results$trial_counts <- check_trial_counts(
    responses,
    expected_n = expected_n,
    method = method,
    col_participant = col_participant
  )

  results$duplicates <- check_duplicates(
    responses,
    method = method,
    col_participant = col_participant,
    col_stimulus = col_stimulus
  )

  results$response_bias <- check_response_bias(
    responses,
    method = method,
    col_participant = col_participant,
    col_response = col_response
  )

  if (method == "briefrc" && !is.null(noise_matrix)) {
    mat <- read_noise_matrix(noise_matrix)
    results$noise_matrix <- validate_noise_matrix(mat)
  }

  rcdiag_report(
    results = results,
    skipped_checks = c(
      "check_response_inversion",
      "check_stimulus_alignment",
      "check_rt",
      "check_version_compat",
      "compute_infoval_summary",
      "cross_validate_rt_infoval"
    ),
    method = method
  )
}

resolve_method <- function(method, rdata, noise_matrix) {
  if (!is.null(method)) {
    return(match.arg(method, c("2ifc", "briefrc")))
  }
  have_rdata <- !is.null(rdata)
  have_nm <- !is.null(noise_matrix)
  if (have_rdata && have_nm) {
    cli::cli_abort(c(
      "Both {.arg rdata} and {.arg noise_matrix} were supplied.",
      "i" = "Set {.arg method} explicitly to {.val 2ifc} or {.val briefrc}."
    ))
  }
  if (have_rdata) return("2ifc")
  if (have_nm) return("briefrc")
  cli::cli_abort(c(
    "Cannot auto-detect {.arg method}.",
    "i" = "Supply {.arg method = \"2ifc\"} or {.arg method = \"briefrc\"}."
  ))
}
