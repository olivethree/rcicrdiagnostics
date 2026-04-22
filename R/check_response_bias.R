#' Check for response bias
#'
#' Flags two kinds of response bias:
#'
#' 1. Per-participant constant responding: a participant who gives the same
#'   response on every trial. This is almost always a serious problem
#'   (disengaged participant or a coding bug) and produces a status of
#'   `"fail"` if any such participant is present.
#' 2. Per-participant extreme mean: a participant whose mean response is
#'   further from zero than `bias_threshold`. For binary `{-1, 1}` coding,
#'   the default threshold of `0.6` corresponds to roughly an 80/20 split.
#'   Status is `"warn"` if any extreme participants are found and no
#'   constant responders are present.
#'
#' The absolute-threshold approach is more robust than MAD-scaled outlier
#' detection when the group is small, because MAD collapses when most
#' participants respond similarly.
#'
#' @param responses A data frame of trial-level responses.
#' @param method Either `"2ifc"` or `"briefrc"`.
#' @param col_participant,col_response Column names.
#' @param bias_threshold Numeric. Participants with absolute mean response
#'   exceeding this value are flagged. Default `0.6`, which for `{-1, 1}`
#'   coding corresponds to approximately 80% of responses in one direction.
#' @param ... Unused.
#'
#' @return An [rcdiag_result()] object. The `data` element contains
#'   `per_participant`, a data.table with participant id, trial count,
#'   mean response, flag for constant response, and flag for extreme mean.
#'
#' @examples
#' set.seed(1)
#' responses <- data.frame(
#'   participant_id = rep(1:4, each = 100),
#'   stimulus       = rep(1:100, 4),
#'   response       = c(
#'     sample(c(-1, 1), 100, replace = TRUE),
#'     sample(c(-1, 1), 100, replace = TRUE),
#'     rep(1, 100),
#'     sample(c(-1, 1), 100, replace = TRUE)
#'   )
#' )
#' check_response_bias(responses)
#'
#' @export
check_response_bias <- function(responses,
                                method = c("2ifc", "briefrc"),
                                col_participant = "participant_id",
                                col_response = "response",
                                bias_threshold = 0.6,
                                ...) {
  method <- match.arg(method)
  if (!is.data.frame(responses)) {
    cli::cli_abort("{.arg responses} must be a data frame.")
  }
  missing_cols <- setdiff(c(col_participant, col_response), names(responses))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "Missing column{?s} in {.arg responses}: {.val {missing_cols}}",
      "i" = "Available: {.val {names(responses)}}"
    ))
  }
  label <- "Response bias"

  dt <- data.table::as.data.table(responses)
  per_p <- dt[, list(
    n_trials = .N,
    mean = mean(as.numeric(.SD[[1L]]), na.rm = TRUE),
    constant = data.table::uniqueN(.SD[[1L]]) == 1L
  ), by = c(col_participant), .SDcols = col_response]

  per_p$is_biased <- abs(per_p$mean) > bias_threshold & !per_p$constant

  n_constant <- sum(per_p$constant)
  n_biased <- sum(per_p$is_biased)
  n_p <- nrow(per_p)
  group_mean <- mean(per_p$mean, na.rm = TRUE)

  status <- if (n_constant > 0) {
    "fail"
  } else if (n_biased > 0) {
    "warn"
  } else {
    "pass"
  }

  detail <- c(
    sprintf(
      "%d of %d participants gave the same response on every trial.",
      n_constant, n_p
    ),
    sprintf(
      "%d participants have |mean response| > %g (extreme bias).",
      n_biased, bias_threshold
    ),
    sprintf("Group mean response: %.3f.", group_mean)
  )

  rcdiag_result(
    status, label, detail,
    data = list(
      per_participant = per_p,
      group_mean = group_mean,
      bias_threshold = bias_threshold
    )
  )
}
