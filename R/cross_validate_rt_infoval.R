#' Cross-validate infoVal against RT quality
#'
#' Correlates per-participant infoVal with per-participant median
#' response time. The check looks for two patterns that are
#' individually plausible but jointly suspicious:
#'
#' 1. High infoVal with fast median RT. A participant producing a
#'   seemingly informative CI while responding faster than others is
#'   more likely to have produced a spurious signal than genuine
#'   meaningful information — the signal may be an artefact of a
#'   button-mashing strategy that happens to correlate with the noise.
#' 2. A negative correlation between infoVal and median RT across
#'   participants. If fast responders systematically score higher on
#'   infoVal, something about the measurement is off.
#'
#' The function computes `cor(infoval, median_rt)` across participants
#' and returns the value plus a per-participant table for further
#' inspection. It does not auto-exclude anyone; interpretation requires
#' judgement about the specific experiment.
#'
#' Requires `rcicr` via [compute_infoval_summary()].
#'
#' @param responses A data frame of trial-level responses.
#' @param method `"2ifc"` or `"briefrc"`.
#' @param rdata Path to the rcicr `.RData` file.
#' @param baseimage Name of the base image in `rdata$base_face_files`.
#' @param col_participant,col_stimulus,col_response,col_rt Column names.
#'   `col_rt` is required.
#' @param iter Reference-distribution iterations. Default `10000`.
#' @param ... Unused.
#'
#' @return An [rcdiag_result()] object. `data$per_participant` has
#'   `participant_id`, `infoval`, `median_rt`. `data$correlation` is
#'   the Pearson correlation between the two.
#'
#' @examples
#' \dontrun{
#' cross_validate_rt_infoval(
#'   responses, method = "2ifc",
#'   rdata = "stimuli.RData",
#'   col_rt = "rt"
#' )
#' }
#'
#' @export
cross_validate_rt_infoval <- function(responses,
                                      method = c("2ifc", "briefrc"),
                                      rdata,
                                      baseimage = "base",
                                      col_participant = "participant_id",
                                      col_stimulus = "stimulus",
                                      col_response = "response",
                                      col_rt = "rt",
                                      iter = 10000L,
                                      ...) {
  method <- match.arg(method)
  label  <- "RT vs infoVal"

  if (method == "briefrc") {
    return(rcdiag_result(
      "skip", label,
      c(
        "RT x infoVal cross-validation is not supported for Brief-RC in",
        "rcicrdiagnostics. It depends on compute_infoval_summary(), which",
        "is not implemented for Brief-RC (see that function's help)."
      ),
      data = list(method = "briefrc")
    ))
  }

  if (!col_rt %in% names(responses)) {
    cli::cli_abort(c(
      "Column {.val {col_rt}} not found in {.arg responses}.",
      "i" = "Available: {.val {names(responses)}}"
    ))
  }

  iv_result <- compute_infoval_summary(
    responses, method = method, rdata = rdata, baseimage = baseimage,
    col_participant = col_participant, col_stimulus = col_stimulus,
    col_response = col_response, iter = iter
  )

  dt <- data.table::as.data.table(responses)
  rt_per_p <- dt[, list(median_rt = stats::median(.SD[[1L]], na.rm = TRUE)),
                 by = c(col_participant), .SDcols = col_rt]
  data.table::setnames(rt_per_p, col_participant, "participant_id")

  per_p <- merge(
    iv_result$data$per_participant[, c("participant_id", "infoval")],
    as.data.frame(rt_per_p), by = "participant_id"
  )

  r <- suppressWarnings(
    stats::cor(per_p$infoval, per_p$median_rt, use = "pairwise.complete.obs")
  )

  # Flag "fast and confident" participants: median RT below group
  # median, yet infoval above group median.
  grp_rt_med <- stats::median(per_p$median_rt, na.rm = TRUE)
  grp_iv_med <- stats::median(per_p$infoval,   na.rm = TRUE)
  per_p$fast_and_confident <-
    per_p$median_rt < grp_rt_med & per_p$infoval > grp_iv_med
  n_fac <- sum(per_p$fast_and_confident)

  status <- if (!is.finite(r)) {
    "skip"
  } else if (r <= -0.30) {
    "warn"
  } else {
    "pass"
  }

  detail <- c(
    sprintf(
      "Correlation between infoVal and median RT: r = %s.",
      if (is.finite(r)) sprintf("%.3f", r) else "NA"
    ),
    sprintf(
      paste(
        "%d participants are both faster and more 'informative'",
        "than the group median."
      ),
      n_fac
    ),
    if (isTRUE(r <= -0.30)) {
      paste(
        "A moderate negative correlation means fast responders score",
        "higher on infoVal, which is suspicious."
      )
    }
  )

  rcdiag_result(
    status, label, detail,
    data = list(
      per_participant = per_p,
      correlation     = r
    )
  )
}
