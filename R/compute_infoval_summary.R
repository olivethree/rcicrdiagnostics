#' Per-participant information-value (infoVal) summary
#'
#' Computes the information value (infoVal; Brinkman et al., 2019) for
#' every participant and returns a pass / warn / fail summary plus a
#' per-participant table flagging those below the `threshold`.
#'
#' infoVal is a z-like score describing how far a participant's
#' classification image (CI) is from a null-response reference
#' distribution. Values around or below `1.96` are effectively
#' indistinguishable from noise; higher values indicate meaningful
#' signal.
#'
#' This function delegates the heavy lifting to the `rcicr` package
#' ([`rcicr::batchGenerateCI2IFC()`][rcicr::batchGenerateCI2IFC] and
#' [`rcicr::computeInfoVal2IFC()`][rcicr::computeInfoVal2IFC] for 2IFC;
#' the corresponding `*_brief` functions for Brief-RC). It is therefore
#' only runnable with `rcicr` installed and with the `rdata` file that
#' produced the stimuli.
#'
#' **Side effect.** rcicr caches a reference distribution inside the
#' supplied `rdata` file on the first call. Subsequent calls reuse it
#' and run much faster. Copy your `rdata` file beforehand if you want
#' the original untouched.
#'
#' @param responses A data frame of trial-level responses.
#' @param method `"2ifc"` or `"briefrc"`.
#' @param rdata Path to the rcicr `.RData` file that produced the
#'   stimuli. Required.
#' @param baseimage Name of the base image used at generation time
#'   (the key in `base_face_files` in the rdata). Default `"base"`.
#' @param col_participant,col_stimulus,col_response Column names.
#'   `col_response` is used by the 2IFC path only.
#' @param iter Number of iterations for rcicr's reference-distribution
#'   simulation. Default `10000` (the rcicr-recommended value).
#' @param threshold Numeric. Participants with infoVal below this are
#'   flagged as likely noise. Default `1.96` (a conventional z-threshold
#'   from Brinkman et al., 2019).
#' @param ... Unused.
#'
#' @return An [rcdiag_result()] object. `data$per_participant` has one
#'   row per participant with `participant_id`, `infoval`, and
#'   `meaningful` (logical: `infoval >= threshold`).
#'
#' @examples
#' \dontrun{
#' # Requires rcicr and a 2IFC rdata file
#' compute_infoval_summary(
#'   responses, method = "2ifc",
#'   rdata = "stimuli.RData",
#'   iter = 10000
#' )
#' }
#'
#' @export
compute_infoval_summary <- function(responses,
                                    method = c("2ifc", "briefrc"),
                                    rdata,
                                    baseimage = "base",
                                    col_participant = "participant_id",
                                    col_stimulus = "stimulus",
                                    col_response = "response",
                                    iter = 10000L,
                                    threshold = 1.96,
                                    ...) {
  method <- match.arg(method)
  if (!requireNamespace("rcicr", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg rcicr} is required for {.fn compute_infoval_summary}.",
      "i" = "Install with {.code remotes::install_github(\"rdotsch/rcicr\")}."
    ))
  }
  validate_path(rdata, "rdata")
  validate_responses_df(
    responses, col_participant, col_stimulus, col_response
  )
  label <- "Information value"

  # rcicr's internals require these packages attached, not just loaded via
  # ::, because they use %>%, tribble, and %dopar% at evaluation time.
  ensure_attached(c("foreach", "tibble", "dplyr"))

  data_df <- as.data.frame(responses)
  tmp_out <- tempfile()
  dir.create(tmp_out, showWarnings = FALSE, recursive = TRUE)

  cis <- switch(
    method,
    "2ifc" = rcicr::batchGenerateCI2IFC(
      data        = data_df,
      by          = col_participant,
      stimuli     = col_stimulus,
      responses   = col_response,
      baseimage   = baseimage,
      rdata       = rdata,
      save_as_png = FALSE,
      targetpath  = tmp_out
    ),
    "briefrc" = rcicr::batchGenerateCI_brief(
      data      = data_df,
      by        = col_participant,
      stimuli   = col_stimulus,
      responses = col_response,
      rdata     = rdata
    )
  )

  infoval_fn <- if (method == "2ifc") {
    rcicr::computeInfoVal2IFC
  } else {
    rcicr::computeInfoVal_brief
  }

  per_participant <- vapply(
    names(cis),
    function(nm) infoval_fn(cis[[nm]], rdata, iter = iter),
    numeric(1L)
  )
  ids <- extract_participant_ids(names(cis), baseimage, col_participant)
  per_p <- data.frame(
    participant_id = ids,
    infoval        = unname(per_participant),
    meaningful     = unname(per_participant) >= threshold,
    stringsAsFactors = FALSE
  )

  n_total <- nrow(per_p)
  n_meaningful <- sum(per_p$meaningful)
  pct_meaningful <- n_meaningful / n_total

  status <- if (pct_meaningful >= 0.80) {
    "pass"
  } else if (pct_meaningful >= 0.50) {
    "warn"
  } else {
    "fail"
  }

  detail <- c(
    sprintf(
      "%d of %d participants have infoVal >= %.2f (%.1f%%).",
      n_meaningful, n_total, threshold, 100 * pct_meaningful
    ),
    sprintf(
      "InfoVal range: [%.2f, %.2f]; median %.2f.",
      min(per_p$infoval), max(per_p$infoval),
      stats::median(per_p$infoval)
    )
  )

  rcdiag_result(
    status, label, detail,
    data = list(
      per_participant = per_p,
      threshold       = threshold,
      iter            = iter,
      method          = method
    )
  )
}

# rcicr's batch CI functions return lists named
# "<baseimage>_<by>_<id>"; recover the <id> component.
extract_participant_ids <- function(nms, baseimage, by) {
  prefix <- paste0("^", baseimage, "_", by, "_")
  sub(prefix, "", nms)
}
