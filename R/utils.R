#' Validate that a file path exists
#'
#' @param path Character scalar. Path to validate.
#' @param arg_name Character scalar. Name of the argument in the calling
#'   function, used in the error message.
#' @return Invisibly returns `path` if it exists. Aborts otherwise.
#' @keywords internal
#' @noRd
validate_path <- function(path, arg_name = "path") {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    cli::cli_abort(
      "{.arg {arg_name}} must be a single, non-NA character string.",
      call = rlang_caller_env()
    )
  }
  if (!file.exists(path)) {
    cli::cli_abort(
      c(
        "File not found: {.path {path}}",
        "i" = "Passed as {.arg {arg_name}}."
      ),
      call = rlang_caller_env()
    )
  }
  invisible(path)
}

#' Validate that a responses data frame has the expected columns
#'
#' @param responses A data.frame or data.table.
#' @param col_participant,col_stimulus,col_response Required column names.
#' @param col_rt Optional column name. If non-NULL, must be present.
#' @return Invisibly returns `responses`. Aborts if validation fails.
#' @keywords internal
#' @noRd
validate_responses_df <- function(responses,
                                  col_participant,
                                  col_stimulus,
                                  col_response,
                                  col_rt = NULL) {
  if (!is.data.frame(responses)) {
    cli::cli_abort("{.arg responses} must be a data frame.")
  }
  required <- c(col_participant, col_stimulus, col_response)
  if (!is.null(col_rt)) required <- c(required, col_rt)
  missing_cols <- setdiff(required, names(responses))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "{.arg responses} is missing required column{?s}: {.val {missing_cols}}",
      "i" = "Available columns: {.val {names(responses)}}"
    ))
  }
  invisible(responses)
}

# Minimal substitute for rlang::caller_env() so we do not need to import rlang
# just for error-call plumbing. Returns the environment two frames up from
# where this helper is called (i.e. the caller of the function that called
# this helper).
rlang_caller_env <- function() {
  parent.frame(2L)
}
