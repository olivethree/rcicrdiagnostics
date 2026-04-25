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

# S3 constructor for the raw infoval() output. Wrapped by diagnose_infoval()
# in an rcdiag_result so it slots into rcdiag_report. Exposed mainly for users
# who want the per-producer z-vector and reference distributions for plotting.
new_rcdiag_infoval <- function(infoval, norms, reference,
                               ref_median, ref_mad, trial_counts,
                               mask, iter, n_pool, seed) {
  structure(
    list(
      infoval      = infoval,
      norms        = norms,
      reference    = reference,
      ref_median   = ref_median,
      ref_mad      = ref_mad,
      trial_counts = trial_counts,
      mask         = mask,
      iter         = iter,
      n_pool       = n_pool,
      seed         = seed
    ),
    class = "rcdiag_infoval"
  )
}

#' @export
print.rcdiag_infoval <- function(x, ...) {
  cat("<rcdiag_infoval>\n")
  cat(sprintf("  producers : %d\n", length(x$infoval)))
  cat(sprintf("  pool size : %d\n", x$n_pool))
  cat(sprintf("  iter      : %d\n", x$iter))
  cat(sprintf("  mask      : %s\n",
              if (is.null(x$mask)) "none" else
              sprintf("%d / %d pixels", sum(x$mask), length(x$mask))))
  q <- stats::quantile(x$infoval, c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE)
  cat(sprintf(
    "  z summary : min %.2f | Q1 %.2f | median %.2f | Q3 %.2f | max %.2f\n",
    q[1L], q[2L], q[3L], q[4L], q[5L]
  ))
  invisible(x)
}
