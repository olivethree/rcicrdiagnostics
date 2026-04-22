#' Check trial counts per participant
#'
#' Counts the number of rows per participant and compares against expected
#' trial counts. If `expected_n` is not supplied, the check reports the
#' observed distribution without flagging anything. If `expected_n` is
#' supplied, participants whose trial count is not in the allowed set are
#' flagged.
#'
#' @param responses A data frame of trial-level responses.
#' @param expected_n Optional. A single integer (all participants should
#'   have this many trials) or a vector of allowed counts (useful for
#'   designs with multiple trial-count conditions, e.g. `c(300, 500, 1000)`).
#'   If `NULL`, no flagging occurs.
#' @param method Either `"2ifc"` or `"briefrc"`. Currently informational.
#' @param col_participant Name of the participant id column.
#' @param ... Unused. Reserved for consistency with other check functions.
#'
#' @return An [rcdiag_result()] object. The `data` element contains
#'   `per_participant`, a data frame with one row per participant and
#'   their trial count.
#'
#' @examples
#' responses <- data.frame(
#'   participant_id = rep(1:3, times = c(300, 300, 250)),
#'   stimulus       = 1,
#'   response       = 1
#' )
#' check_trial_counts(responses, expected_n = 300)
#'
#' @export
check_trial_counts <- function(responses,
                               expected_n = NULL,
                               method = c("2ifc", "briefrc"),
                               col_participant = "participant_id",
                               ...) {
  method <- match.arg(method)
  if (!is.data.frame(responses)) {
    cli::cli_abort("{.arg responses} must be a data frame.")
  }
  if (!col_participant %in% names(responses)) {
    cli::cli_abort(c(
      "Column {.val {col_participant}} not found in {.arg responses}.",
      "i" = "Available columns: {.val {names(responses)}}"
    ))
  }
  label <- "Trial counts"

  dt <- data.table::as.data.table(responses)
  per_p <- dt[, list(n = .N), by = c(col_participant)]
  data.table::setnames(per_p, col_participant, "participant")
  data.table::setorder(per_p, -n)

  n_participants <- nrow(per_p)
  count_tbl <- table(per_p$n)

  if (is.null(expected_n)) {
    return(rcdiag_result(
      "pass", label,
      c(
        sprintf("%d participants total.", n_participants),
        sprintf(
          "Trial counts observed: %s.",
          paste(
            sprintf("%s trials (%s participants)", names(count_tbl), count_tbl),
            collapse = "; "
          )
        )
      ),
      data = list(per_participant = per_p, count_table = count_tbl)
    ))
  }

  if (!is.numeric(expected_n) || any(expected_n <= 0)) {
    cli::cli_abort("{.arg expected_n} must be a positive numeric vector.")
  }

  bad <- per_p[!per_p$n %in% expected_n, ]
  n_bad <- nrow(bad)

  if (n_bad == 0L) {
    return(rcdiag_result(
      "pass", label,
      sprintf(
        "All %d participant{?s} have trial counts in {%s}.",
        n_participants,
        paste(expected_n, collapse = ", ")
      ),
      data = list(per_participant = per_p, flagged = bad)
    ))
  }

  pct_bad <- n_bad / n_participants
  status <- if (pct_bad > 0.10) "fail" else "warn"

  rcdiag_result(
    status, label,
    c(
      sprintf(
        "%d of %d participant{?s} have unexpected trial counts.",
        n_bad, n_participants
      ),
      sprintf("Expected: {%s}.", paste(expected_n, collapse = ", ")),
      sprintf(
        "Flagged counts: %s.",
        paste(
          sprintf("%s (n=%d)", bad$participant, bad$n),
          collapse = "; "
        )
      )
    ),
    data = list(per_participant = per_p, flagged = bad)
  )
}
