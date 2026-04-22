#' Check for duplicate rows in response data
#'
#' Duplicate rows in response data almost always indicate a merge bug or
#' an accidental double-write. This check flags two distinct cases:
#'
#' 1. Fully duplicated rows (identical across every column).
#' 2. Duplicated `(participant, stimulus)` pairs where the response or RT
#'    differs. These are harder to interpret: either the design legitimately
#'    repeats stimuli (in which case the check should be skipped), or the
#'    data pipeline glued together two runs for the same participant.
#'
#' @param responses A data frame of trial-level responses.
#' @param method Either `"2ifc"` or `"briefrc"`. Currently informational.
#' @param col_participant,col_stimulus Column names.
#' @param ... Unused.
#'
#' @return An [rcdiag_result()] object. The `data` element contains
#'   `full_duplicates` and `pair_duplicates` data frames of the flagged rows.
#'
#' @examples
#' responses <- data.frame(
#'   participant_id = c(1, 1, 1, 2),
#'   stimulus       = c(1, 2, 2, 1),
#'   response       = c(1, -1, -1, 1)
#' )
#' check_duplicates(responses)
#'
#' @export
check_duplicates <- function(responses,
                             method = c("2ifc", "briefrc"),
                             col_participant = "participant_id",
                             col_stimulus = "stimulus",
                             ...) {
  method <- match.arg(method)
  if (!is.data.frame(responses)) {
    cli::cli_abort("{.arg responses} must be a data frame.")
  }
  missing_cols <- setdiff(c(col_participant, col_stimulus), names(responses))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "Missing column{?s} in {.arg responses}: {.val {missing_cols}}",
      "i" = "Available: {.val {names(responses)}}"
    ))
  }
  label <- "Duplicates"

  dt <- data.table::as.data.table(responses)
  n_rows <- nrow(dt)

  full_dup_mask <- duplicated(dt)
  n_full_dup <- sum(full_dup_mask)

  pair_key <- dt[, c(col_participant, col_stimulus), with = FALSE]
  pair_dup_mask <- duplicated(pair_key) | duplicated(pair_key, fromLast = TRUE)
  pair_dup_mask_excl <- pair_dup_mask & !full_dup_mask
  n_pair_dup <- sum(pair_dup_mask_excl)

  full_pct <- n_full_dup / n_rows
  status <- if (n_full_dup >= 2L && full_pct > 0.05) {
    "fail"
  } else if (n_full_dup > 0L || n_pair_dup > 0L) {
    "warn"
  } else {
    "pass"
  }

  detail <- c(
    sprintf("%d of %d rows are fully duplicated.", n_full_dup, n_rows),
    sprintf(
      paste(
        "%d rows share a (participant, stimulus) pair",
        "with differing response or RT."
      ),
      n_pair_dup
    )
  )

  rcdiag_result(
    status, label, detail,
    data = list(
      full_duplicates = dt[full_dup_mask, ],
      pair_duplicates = dt[pair_dup_mask_excl, ]
    )
  )
}
