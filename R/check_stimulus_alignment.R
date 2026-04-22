#' Check stimulus ids align with the stimulus pool
#'
#' Verifies that the `stimulus` column in the response data refers to
#' valid indices in the stimulus pool defined by the supplied `.RData`
#' (2IFC) or noise-matrix file (Brief-RC). An off-by-one error in the
#' response export, or a mismatch between the pool used in the experiment
#' and the pool passed to the diagnostics, is the most common silent
#' source of wrong CIs — this check catches both.
#'
#' @param responses A data frame of trial-level responses.
#' @param method Either `"2ifc"` or `"briefrc"`.
#' @param rdata Path to the `.RData` file produced by
#'   `rcicr::generateStimuli2IFC()`. Required when `method = "2ifc"`.
#' @param noise_matrix Path to the Brief-RC noise-matrix text file, or a
#'   numeric matrix already in memory. Required when `method = "briefrc"`.
#' @param col_stimulus Name of the stimulus column in `responses`.
#' @param ... Unused.
#'
#' @return An [rcdiag_result()] object. `data` contains
#'   `pool_size` (number of stimuli in the pool), `n_stim_used` (unique
#'   stimuli referenced in the data), `out_of_range` (stimulus ids
#'   outside `1..pool_size`), and `unused_stimuli` (pool ids never
#'   referenced).
#'
#' @examples
#' mat <- matrix(rnorm(16384 * 10, sd = 0.05), nrow = 16384, ncol = 10)
#' responses <- data.frame(
#'   participant_id = rep(1:2, each = 20),
#'   stimulus       = sample.int(10, 40, replace = TRUE),
#'   response       = sample(c(-1, 1), 40, replace = TRUE)
#' )
#' check_stimulus_alignment(
#'   responses, method = "briefrc", noise_matrix = mat
#' )
#'
#' @export
check_stimulus_alignment <- function(responses,
                                     method = c("2ifc", "briefrc"),
                                     rdata = NULL,
                                     noise_matrix = NULL,
                                     col_stimulus = "stimulus",
                                     ...) {
  method <- match.arg(method)
  if (!is.data.frame(responses)) {
    cli::cli_abort("{.arg responses} must be a data frame.")
  }
  if (!col_stimulus %in% names(responses)) {
    cli::cli_abort(c(
      "Column {.val {col_stimulus}} not found in {.arg responses}.",
      "i" = "Available columns: {.val {names(responses)}}"
    ))
  }
  label <- "Stimulus alignment"

  pool_size <- switch(
    method,
    "2ifc"    = pool_size_from_rdata(rdata),
    "briefrc" = pool_size_from_noise_matrix(noise_matrix)
  )

  stim <- responses[[col_stimulus]]
  if (!is.numeric(stim)) {
    return(rcdiag_result(
      "fail", label,
      sprintf(
        "Stimulus column %s is not numeric (class: %s).",
        sQuote(col_stimulus), class(stim)[1L]
      )
    ))
  }

  used <- sort(unique(stim[is.finite(stim)]))
  out_of_range <- used[used < 1L | used > pool_size |
                       used != as.integer(used)]
  unused <- setdiff(seq_len(pool_size), used)

  if (length(out_of_range) > 0L) {
    preview <- utils::head(out_of_range, 10)
    return(rcdiag_result(
      "fail", label,
      c(
        sprintf(
          "%d stimulus id(s) are outside the valid range [1, %d].",
          length(out_of_range), pool_size
        ),
        sprintf(
          "Examples of out-of-range ids: %s%s",
          paste(preview, collapse = ", "),
          if (length(out_of_range) > 10L) ", ..." else ""
        )
      ),
      data = list(
        pool_size      = pool_size,
        n_stim_used    = length(used),
        out_of_range   = out_of_range,
        unused_stimuli = unused
      )
    ))
  }

  status <- if (length(unused) / pool_size > 0.5) "warn" else "pass"
  detail <- c(
    sprintf(
      "%d of %d pool stimuli are referenced in the response data.",
      length(used), pool_size
    ),
    if (length(unused) > 0L) {
      sprintf(
        "%d pool stimuli are never referenced (%.1f%% of the pool).",
        length(unused), 100 * length(unused) / pool_size
      )
    }
  )

  rcdiag_result(
    status, label, detail,
    data = list(
      pool_size      = pool_size,
      n_stim_used    = length(used),
      out_of_range   = integer(),
      unused_stimuli = unused
    )
  )
}

# Load a 2IFC rdata file and return the pool size (number of stimuli).
pool_size_from_rdata <- function(rdata) {
  if (is.null(rdata)) {
    cli::cli_abort("{.arg rdata} is required for {.val 2ifc}.")
  }
  validate_path(rdata, "rdata")
  e <- new.env()
  load(rdata, envir = e)
  if (!exists("n_trials", envir = e, inherits = FALSE)) {
    cli::cli_abort(c(
      "{.path {rdata}} does not contain an {.field n_trials} object.",
      "i" = "Is this file produced by {.fn rcicr::generateStimuli2IFC}?"
    ))
  }
  as.integer(e$n_trials)
}

# Pool size from a Brief-RC noise matrix: either a file path (read_noise_matrix)
# or a numeric matrix already in memory. Returns ncol(mat).
pool_size_from_noise_matrix <- function(noise_matrix) {
  if (is.null(noise_matrix)) {
    cli::cli_abort("{.arg noise_matrix} is required for {.val briefrc}.")
  }
  mat <- if (is.character(noise_matrix)) {
    read_noise_matrix(noise_matrix)
  } else if (is.matrix(noise_matrix)) {
    noise_matrix
  } else {
    cli::cli_abort(
      "{.arg noise_matrix} must be a file path or a numeric matrix."
    )
  }
  ncol(mat)
}
