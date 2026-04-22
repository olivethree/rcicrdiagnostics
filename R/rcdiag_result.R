#' Construct an `rcdiag_result` object
#'
#' Every diagnostic function in the package returns an object of class
#' `"rcdiag_result"`. This constructor is the single source of truth for the
#' result shape.
#'
#' @param status One of `"pass"`, `"warn"`, `"fail"`, or `"skip"`.
#' @param label Short (one-line) description of the check.
#' @param detail Human-readable explanation of the result. Multiple lines
#'   allowed.
#' @param data Optional list of supporting data (data frames, flagged
#'   participant ids, summary statistics). Defaults to an empty list.
#'
#' @return An object of class `"rcdiag_result"`: a list with elements
#'   `status`, `label`, `detail`, and `data`.
#'
#' @examples
#' rcdiag_result("pass", "Response coding", "All responses coded {-1, 1}.")
#'
#' @export
rcdiag_result <- function(status, label, detail, data = list()) {
  valid <- c("pass", "warn", "fail", "skip")
  if (!is.character(status) || length(status) != 1L || !status %in% valid) {
    cli::cli_abort("{.arg status} must be one of {.val {valid}}.")
  }
  if (!is.character(label) || length(label) != 1L) {
    cli::cli_abort("{.arg label} must be a single string.")
  }
  if (!is.character(detail)) {
    cli::cli_abort("{.arg detail} must be a character vector.")
  }
  if (!is.list(data)) {
    cli::cli_abort("{.arg data} must be a list.")
  }
  structure(
    list(status = status, label = label, detail = detail, data = data),
    class = "rcdiag_result"
  )
}

#' Test whether an object is an `rcdiag_result`
#'
#' @param x Any R object.
#' @return `TRUE` if `x` inherits from `"rcdiag_result"`, otherwise `FALSE`.
#' @export
is_rcdiag_result <- function(x) inherits(x, "rcdiag_result")

#' @export
print.rcdiag_result <- function(x, ...) {
  cat(format_status_tag(x$status), " ", x$label, "\n", sep = "")
  for (line in x$detail) {
    cat("  ", line, "\n", sep = "")
  }
  invisible(x)
}

#' @export
format.rcdiag_result <- function(x, ...) {
  c(
    paste0(format_status_tag(x$status), " ", x$label),
    paste0("  ", x$detail)
  )
}

format_status_tag <- function(status) {
  switch(
    status,
    pass = cli::col_green("[PASS]"),
    warn = cli::col_yellow("[WARN]"),
    fail = cli::col_red("[FAIL]"),
    skip = cli::col_silver("[SKIP]"),
    paste0("[", toupper(status), "]")
  )
}
