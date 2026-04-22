#' Construct an `rcdiag_report` object
#'
#' An `rcdiag_report` collects the outputs of multiple diagnostic checks
#' into a single printable summary, together with the method that was run
#' and the names of checks that were skipped because they are not yet
#' implemented.
#'
#' @param results A named list of [rcdiag_result()] objects.
#' @param skipped_checks Character vector of check names that were not
#'   executed. Defaults to an empty vector.
#' @param method Either `"2ifc"` or `"briefrc"`.
#'
#' @return An object of class `"rcdiag_report"`.
#'
#' @examples
#' r <- rcdiag_report(
#'   results = list(
#'     a = rcdiag_result("pass", "Check A", "Looks fine.")
#'   ),
#'   method = "2ifc"
#' )
#' print(r)
#'
#' @export
rcdiag_report <- function(results,
                          skipped_checks = character(),
                          method = c("2ifc", "briefrc")) {
  method <- match.arg(method)
  if (!is.list(results) || !all(vapply(results, is_rcdiag_result, logical(1L)))) {
    cli::cli_abort("{.arg results} must be a list of {.cls rcdiag_result} objects.")
  }
  structure(
    list(
      results = results,
      skipped_checks = as.character(skipped_checks),
      method = method
    ),
    class = "rcdiag_report"
  )
}

#' @export
print.rcdiag_report <- function(x, ...) {
  cat("== Data-quality report (", x$method, ") ==\n", sep = "")
  cat("\n")
  status_counts <- table(factor(
    vapply(x$results, function(r) r$status, character(1L)),
    levels = c("pass", "warn", "fail", "skip")
  ))
  for (nm in names(x$results)) {
    print(x$results[[nm]])
  }
  cat("\nSummary: ")
  cat(paste(
    sprintf("%s=%d", names(status_counts), as.integer(status_counts)),
    collapse = ", "
  ))
  cat("\n")
  if (length(x$skipped_checks) > 0L) {
    cat("\nSkipped checks:\n")
    for (nm in x$skipped_checks) {
      cat("  - ", nm, "\n", sep = "")
    }
  }
  invisible(x)
}

#' @export
summary.rcdiag_report <- function(object, ...) {
  statuses <- vapply(object$results, function(r) r$status, character(1L))
  data.frame(
    check = names(object$results),
    status = statuses,
    label = vapply(object$results, function(r) r$label, character(1L)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}
