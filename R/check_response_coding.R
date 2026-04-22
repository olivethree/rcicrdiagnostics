#' Check that response values use the expected coding
#'
#' For the 2IFC pipeline, responses must be coded as `{-1, 1}`. Common
#' miscodings (`{0, 1}` or `{1, 2}`) produce classification images that
#' look plausible but are shifted or inverted. This check detects the
#' common miscodings explicitly and returns a status with a fix suggestion.
#'
#' For the Brief-RC pipeline, responses may be binary `{-1, 1}` or
#' continuous weights. Anything numeric and finite is accepted.
#'
#' @param responses A data frame of trial-level responses.
#' @param method Either `"2ifc"` or `"briefrc"`.
#' @param col_response Name of the column holding response values.
#'   Defaults to `"response"`.
#' @param ... Unused. Reserved for consistency with other check functions.
#'
#' @return An [rcdiag_result()] object.
#'
#' @examples
#' responses <- data.frame(
#'   participant_id = rep(1, 10),
#'   stimulus       = 1:10,
#'   response       = sample(c(-1, 1), 10, replace = TRUE)
#' )
#' check_response_coding(responses, method = "2ifc")
#'
#' @export
check_response_coding <- function(responses,
                                  method = c("2ifc", "briefrc"),
                                  col_response = "response",
                                  ...) {
  method <- match.arg(method)
  if (!is.data.frame(responses)) {
    cli::cli_abort("{.arg responses} must be a data frame.")
  }
  if (!col_response %in% names(responses)) {
    cli::cli_abort(c(
      "Column {.val {col_response}} not found in {.arg responses}.",
      "i" = "Available columns: {.val {names(responses)}}"
    ))
  }
  label <- "Response coding"
  vals <- responses[[col_response]]

  if (!is.numeric(vals)) {
    return(rcdiag_result(
      "fail", label,
      c(
        sprintf("Column %s is not numeric (class: %s).",
                sQuote(col_response), class(vals)[1L]),
        "Convert to numeric before running further checks."
      )
    ))
  }

  n_total <- length(vals)
  n_na <- sum(is.na(vals))
  finite <- as.numeric(vals[is.finite(vals)])
  uniq <- sort(unique(finite))

  if (method == "briefrc") {
    if (n_na > 0) {
      return(rcdiag_result(
        "warn", label,
        sprintf("%d of %d responses are NA.", n_na, n_total),
        data = list(n_na = n_na, unique_values = uniq)
      ))
    }
    return(rcdiag_result(
      "pass", label,
      sprintf(
        "%d finite numeric responses; range [%.3g, %.3g], %d unique values.",
        n_total, min(finite), max(finite), length(uniq)
      ),
      data = list(unique_values = uniq)
    ))
  }

  if (identical(uniq, c(-1, 1)) && n_na == 0L) {
    return(rcdiag_result(
      "pass", label,
      sprintf("All %d responses coded as {-1, 1}.", n_total)
    ))
  }

  miscode <- detect_miscode(uniq)
  msgs <- character()
  if (n_na > 0L) {
    msgs <- c(msgs, sprintf("%d of %d responses are NA.", n_na, n_total))
  }
  if (!is.null(miscode)) {
    msgs <- c(
      msgs,
      sprintf("Detected %s coding. %s", miscode$name, miscode$fix)
    )
    status <- "warn"
  } else if (!identical(uniq, c(-1, 1))) {
    msgs <- c(
      msgs,
      sprintf(
        "Unexpected values for 2IFC: {%s}. Expected exactly {-1, 1}.",
        paste(format(uniq), collapse = ", ")
      )
    )
    status <- "fail"
  } else {
    status <- "warn"
  }

  rcdiag_result(
    status, label, msgs,
    data = list(unique_values = uniq, n_na = n_na, miscode = miscode)
  )
}

detect_miscode <- function(uniq) {
  if (identical(uniq, c(0, 1))) {
    return(list(
      name = "{0, 1}",
      fix  = "Recode with responses$response <- responses$response * 2 - 1."
    ))
  }
  if (identical(uniq, c(1, 2))) {
    return(list(
      name = "{1, 2}",
      fix  = "Recode with responses$response <- responses$response * 2 - 3."
    ))
  }
  NULL
}
