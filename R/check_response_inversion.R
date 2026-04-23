#' Detect response-code inversion
#'
#' Some participants (or whole batches of exported data) may have their
#' response codes flipped relative to the convention `rcicr` expects:
#' `+1` means "inverted version chosen" when the analyst intended
#' "oriented chosen", or the CSV export inadvertently negated the
#' response column. A straightforward way to detect this is to compute
#' the infoVal twice per participant — once with the original codes
#' and once with every response negated — and compare. For correctly
#' coded data, the original should score higher; if the flipped CI
#' scores meaningfully higher, the response column is probably inverted.
#'
#' This check calls [compute_infoval_summary()] twice and reports
#' participants whose flipped infoVal exceeds the original by `margin`
#' or more. A non-zero count is a strong signal that the response
#' column is miscoded for those participants.
#'
#' Requires `rcicr` (same as [compute_infoval_summary()]). Runs two
#' infoVal sweeps, so it takes roughly twice as long.
#'
#' @param responses A data frame of trial-level responses.
#' @param method `"2ifc"` or `"briefrc"`.
#' @param rdata Path to the rcicr `.RData` file.
#' @param baseimage Name of the base image in `rdata$base_face_files`.
#' @param col_participant,col_stimulus,col_response Column names.
#' @param margin Numeric. Flagging threshold: flipped infoVal must
#'   exceed original infoVal by at least this amount. Default `1.96`.
#' @param iter Reference-distribution iterations. Default `10000`.
#' @param ... Passed through to [compute_infoval_summary()].
#'
#' @return An [rcdiag_result()] object. `data$per_participant` has
#'   `participant_id`, `infoval_original`, `infoval_flipped`, and
#'   `likely_inverted` (logical).
#'
#' @examples
#' \dontrun{
#' check_response_inversion(
#'   responses, method = "2ifc",
#'   rdata = "stimuli.RData"
#' )
#' }
#'
#' @export
check_response_inversion <- function(responses,
                                     method = c("2ifc", "briefrc"),
                                     rdata,
                                     baseimage = "base",
                                     col_participant = "participant_id",
                                     col_stimulus = "stimulus",
                                     col_response = "response",
                                     margin = 1.96,
                                     iter = 10000L,
                                     ...) {
  method <- match.arg(method)
  label  <- "Response inversion"

  if (method == "briefrc") {
    return(rcdiag_result(
      "skip", label,
      c(
        "Response-inversion detection is not supported for Brief-RC in",
        "rcicrdiagnostics. It depends on compute_infoval_summary(), which",
        "is not implemented for Brief-RC (see that function's help)."
      ),
      data = list(method = "briefrc")
    ))
  }

  original <- compute_infoval_summary(
    responses, method = method, rdata = rdata, baseimage = baseimage,
    col_participant = col_participant, col_stimulus = col_stimulus,
    col_response = col_response, iter = iter, ...
  )

  flipped_responses <- responses
  flipped_responses[[col_response]] <- -flipped_responses[[col_response]]
  flipped <- compute_infoval_summary(
    flipped_responses, method = method, rdata = rdata, baseimage = baseimage,
    col_participant = col_participant, col_stimulus = col_stimulus,
    col_response = col_response, iter = iter, ...
  )

  per_p <- merge(
    original$data$per_participant[, c("participant_id", "infoval")],
    flipped$data$per_participant[, c("participant_id", "infoval")],
    by = "participant_id", suffixes = c("_original", "_flipped")
  )
  per_p$delta <- per_p$infoval_flipped - per_p$infoval_original
  per_p$likely_inverted <- per_p$delta >= margin

  n_inv <- sum(per_p$likely_inverted)
  n_p   <- nrow(per_p)

  status <- if (n_inv == 0L) {
    "pass"
  } else if (n_inv / n_p >= 0.50) {
    "fail"
  } else {
    "warn"
  }

  detail <- c(
    sprintf(
      paste(
        "%d of %d participants have flipped infoVal exceeding",
        "original by >= %.2f."
      ),
      n_inv, n_p, margin
    ),
    if (n_inv > 0L) {
      "The flagged participants' response codes are likely inverted."
    }
  )

  rcdiag_result(
    status, label, detail,
    data = list(
      per_participant = per_p,
      margin          = margin
    )
  )
}
