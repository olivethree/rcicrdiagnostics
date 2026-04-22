#' Response-time distributional checks
#'
#' Scans response times (RTs) for three kinds of pathology:
#'
#' 1. Implausibly fast responses (`rt < fast_threshold`, default 200 ms).
#'   These usually indicate the participant clicked without reading the
#'   stimulus.
#' 2. Implausibly slow responses (`rt > slow_threshold`, default 5000 ms).
#'   These suggest distraction or a task pause.
#' 3. Abnormally low within-participant RT variability (coefficient of
#'   variation below `min_cv`, default 0.10). A near-constant RT is a hint
#'   that the participant is responding mechanically.
#'
#' @param responses A data frame of trial-level responses.
#' @param method Either `"2ifc"` or `"briefrc"`. Currently informational.
#' @param col_participant Participant id column.
#' @param col_rt RT column (required; the check aborts if `NULL`).
#' @param fast_threshold Milliseconds. Trials faster than this count as
#'   "fast". Default `200`.
#' @param slow_threshold Milliseconds. Trials slower than this count as
#'   "slow". Default `5000`.
#' @param max_fast_frac Fraction. Participants with more than this fraction
#'   of fast trials are flagged. Default `0.05` (warn) / `0.15` (fail).
#' @param max_slow_frac Fraction. Participants with more than this fraction
#'   of slow trials are flagged. Default `0.05` (warn).
#' @param min_cv Numeric. Participants with coefficient of variation of RT
#'   below this are flagged. Default `0.10`.
#' @param ... Unused.
#'
#' @return An [rcdiag_result()] object. `data$per_participant` has one row
#'   per participant with columns: `n_trials`, `mean_rt`, `median_rt`,
#'   `sd_rt`, `cv_rt`, `pct_fast`, `pct_slow`, `is_flagged`.
#'
#' @examples
#' set.seed(1)
#' responses <- data.frame(
#'   participant_id = rep(1:3, each = 100),
#'   stimulus       = rep(1:100, 3),
#'   response       = sample(c(-1, 1), 300, replace = TRUE),
#'   rt             = c(
#'     exp(rnorm(100, 6.7, 0.4)) + 100,   # normal
#'     rep(150, 100),                     # all fast and constant
#'     exp(rnorm(100, 6.7, 0.4)) + 100
#'   )
#' )
#' check_rt(responses, col_rt = "rt")
#'
#' @export
check_rt <- function(responses,
                     method = c("2ifc", "briefrc"),
                     col_participant = "participant_id",
                     col_rt = "rt",
                     fast_threshold = 200,
                     slow_threshold = 5000,
                     max_fast_frac = 0.05,
                     max_slow_frac = 0.05,
                     min_cv = 0.10,
                     ...) {
  method <- match.arg(method)
  if (!is.data.frame(responses)) {
    cli::cli_abort("{.arg responses} must be a data frame.")
  }
  if (is.null(col_rt)) {
    cli::cli_abort(c(
      "{.arg col_rt} is required for {.fn check_rt}.",
      "i" = "Pass the name of your RT column, e.g. {.code col_rt = \"rt\"}."
    ))
  }
  missing_cols <- setdiff(c(col_participant, col_rt), names(responses))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "Missing column{?s} in {.arg responses}: {.val {missing_cols}}",
      "i" = "Available: {.val {names(responses)}}"
    ))
  }
  label <- "Response times"

  dt <- data.table::as.data.table(responses)
  per_p <- dt[, list(
    n_trials  = .N,
    mean_rt   = mean(.SD[[1L]],   na.rm = TRUE),
    median_rt = stats::median(.SD[[1L]], na.rm = TRUE),
    sd_rt     = stats::sd(.SD[[1L]], na.rm = TRUE),
    pct_fast  = mean(.SD[[1L]] < fast_threshold, na.rm = TRUE),
    pct_slow  = mean(.SD[[1L]] > slow_threshold, na.rm = TRUE)
  ), by = c(col_participant), .SDcols = col_rt]

  per_p$cv_rt <- per_p$sd_rt / per_p$mean_rt

  per_p$is_too_fast <- per_p$pct_fast > max_fast_frac
  per_p$is_too_slow <- per_p$pct_slow > max_slow_frac
  per_p$is_low_var  <- !is.na(per_p$cv_rt) & per_p$cv_rt < min_cv
  per_p$is_flagged  <- per_p$is_too_fast | per_p$is_too_slow | per_p$is_low_var

  n_p       <- nrow(per_p)
  n_fast    <- sum(per_p$is_too_fast)
  n_slow    <- sum(per_p$is_too_slow)
  n_lowvar  <- sum(per_p$is_low_var)
  n_severe  <- sum(per_p$pct_fast > 0.15)

  status <- if (n_severe > 0) {
    "fail"
  } else if (n_fast + n_slow + n_lowvar > 0) {
    "warn"
  } else {
    "pass"
  }

  detail <- c(
    sprintf(
      "%d of %d participants exceed %g%% fast trials (< %g ms).",
      n_fast, n_p, 100 * max_fast_frac, fast_threshold
    ),
    sprintf(
      "%d of %d participants exceed %g%% slow trials (> %g ms).",
      n_slow, n_p, 100 * max_slow_frac, slow_threshold
    ),
    sprintf(
      "%d of %d participants have RT coefficient of variation below %g.",
      n_lowvar, n_p, min_cv
    )
  )
  if (n_severe > 0) {
    detail <- c(
      detail,
      sprintf("%d participants exceed 15%% fast trials (severe).", n_severe)
    )
  }

  rcdiag_result(
    status, label, detail,
    data = list(per_participant = per_p)
  )
}
