#' Run the full battery of diagnostic checks
#'
#' Executes every implemented check and returns a [rcdiag_report()]
#' collecting the results. Checks whose required inputs are missing are
#' skipped gracefully and listed in the report's `$skipped_checks`
#' element.
#'
#' The orchestrator auto-detects the method when only `rdata` or only
#' `noise_matrix` is supplied; otherwise pass `method` explicitly.
#'
#' @param responses A data frame of trial-level responses.
#' @param method `"2ifc"` or `"briefrc"`, or `NULL` to auto-detect.
#' @param rdata Optional. Path to an rcicr `.RData` file. Enables
#'   [check_stimulus_alignment()], [check_version_compat()] (2IFC),
#'   [compute_infoval_summary()], [check_response_inversion()], and
#'   [cross_validate_rt_infoval()].
#' @param noise_matrix Optional. Path to a Brief-RC noise-matrix text
#'   file, or an already-loaded numeric matrix. Enables
#'   [validate_noise_matrix()] and [check_stimulus_alignment()] (Brief-RC).
#' @param baseimage Name of the base image used at stimulus-generation
#'   time (key in `base_face_files` in the rdata). Default `"base"`.
#'   Only consulted when the infoval-dependent checks run.
#' @param expected_n Optional. Passed to [check_trial_counts()].
#' @param col_participant,col_stimulus,col_response,col_rt Column-name
#'   overrides.
#' @param infoval_iter Number of iterations for rcicr's reference
#'   distribution; `NULL` disables infoVal checks even if `rdata` is
#'   supplied. Default `NULL` because the reference simulation is slow
#'   and unwanted by default; set e.g. `10000` to enable.
#' @param ... Unused.
#'
#' @return An object of class `rcdiag_report`.
#'
#' @examples
#' responses <- data.frame(
#'   participant_id = rep(1:3, each = 100),
#'   stimulus       = rep(1:100, 3),
#'   response       = sample(c(-1, 1), 300, replace = TRUE),
#'   rt             = round(exp(rnorm(300, 6.7, 0.4)) + 100, 1)
#' )
#' report <- run_diagnostics(responses, method = "2ifc", col_rt = "rt")
#' print(report)
#'
#' @export
run_diagnostics <- function(responses,
                           method = NULL,
                           rdata = NULL,
                           noise_matrix = NULL,
                           baseimage = "base",
                           expected_n = NULL,
                           col_participant = "participant_id",
                           col_stimulus = "stimulus",
                           col_response = "response",
                           col_rt = NULL,
                           infoval_iter = NULL,
                           ...) {
  method <- resolve_method(method, rdata, noise_matrix)

  results <- list()
  skipped <- character()

  results$response_coding <- check_response_coding(
    responses, method = method, col_response = col_response
  )
  results$trial_counts <- check_trial_counts(
    responses, expected_n = expected_n, method = method,
    col_participant = col_participant
  )
  results$duplicates <- check_duplicates(
    responses, method = method,
    col_participant = col_participant, col_stimulus = col_stimulus
  )
  results$response_bias <- check_response_bias(
    responses, method = method,
    col_participant = col_participant, col_response = col_response
  )

  if (!is.null(col_rt) && col_rt %in% names(responses)) {
    results$rt <- check_rt(
      responses, method = method,
      col_participant = col_participant, col_rt = col_rt
    )
  } else {
    skipped <- c(skipped, "check_rt (no col_rt)")
  }

  if (method == "briefrc" && !is.null(noise_matrix)) {
    mat <- if (is.character(noise_matrix)) {
      read_noise_matrix(noise_matrix)
    } else {
      noise_matrix
    }
    results$noise_matrix <- validate_noise_matrix(mat)
    results$stimulus_alignment <- check_stimulus_alignment(
      responses, method = "briefrc",
      noise_matrix = mat, col_stimulus = col_stimulus
    )
  } else if (method == "2ifc" && !is.null(rdata)) {
    results$stimulus_alignment <- check_stimulus_alignment(
      responses, method = "2ifc",
      rdata = rdata, col_stimulus = col_stimulus
    )
    results$version_compat <- check_version_compat(rdata = rdata)
  } else {
    skipped <- c(
      skipped,
      "check_stimulus_alignment (no rdata / noise_matrix)",
      if (method == "2ifc") "check_version_compat (no rdata)"
    )
  }

  can_infoval <- !is.null(rdata) && !is.null(infoval_iter)
  if (can_infoval) {
    iv_res <- tryCatch(
      compute_infoval_summary(
        responses, method = method, rdata = rdata, baseimage = baseimage,
        col_participant = col_participant, col_stimulus = col_stimulus,
        col_response = col_response, iter = infoval_iter
      ),
      error = function(e) {
        rcdiag_result(
          "skip", "Information value",
          c("compute_infoval_summary failed:", conditionMessage(e))
        )
      }
    )
    results$infoval <- iv_res

    if (iv_res$status != "skip") {
      results$response_inversion <- tryCatch(
        check_response_inversion(
          responses, method = method, rdata = rdata, baseimage = baseimage,
          col_participant = col_participant, col_stimulus = col_stimulus,
          col_response = col_response, iter = infoval_iter
        ),
        error = function(e) {
          rcdiag_result(
            "skip", "Response inversion",
            c("check_response_inversion failed:", conditionMessage(e))
          )
        }
      )

      if (!is.null(col_rt) && col_rt %in% names(responses)) {
        results$rt_infoval <- tryCatch(
          cross_validate_rt_infoval(
            responses, method = method, rdata = rdata, baseimage = baseimage,
            col_participant = col_participant, col_stimulus = col_stimulus,
            col_response = col_response, col_rt = col_rt, iter = infoval_iter
          ),
          error = function(e) {
            rcdiag_result(
              "skip", "RT vs infoVal",
              c("cross_validate_rt_infoval failed:", conditionMessage(e))
            )
          }
        )
      } else {
        skipped <- c(skipped, "cross_validate_rt_infoval (no col_rt)")
      }
    }
  } else {
    skipped <- c(
      skipped,
      "compute_infoval_summary (need rdata + infoval_iter)",
      "check_response_inversion (needs infoval)",
      "cross_validate_rt_infoval (needs infoval)"
    )
  }

  rcdiag_report(
    results        = results,
    skipped_checks = skipped,
    method         = method
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
