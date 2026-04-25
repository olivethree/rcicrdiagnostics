#' Per-participant information-value (infoVal) summary
#'
#' Computes per-participant information value (infoVal; Brinkman et al.,
#' 2019) via the original `rcicr` 2IFC pipeline and returns a tidy
#' per-participant table. This is the thin compatibility wrapper around
#' [`rcicr::computeInfoVal2IFC()`]. For a richer, paradigm-agnostic
#' diagnostic (group-mean z, random-responder calibration check,
#' face-mask z-lift, interpretation bullets), see [diagnose_infoval()].
#'
#' Reported per-producer infoVal is paradigm- and target-dependent.
#' Brinkman et al. (2019, p. 12) report 54-68% of 2IFC gender
#' participants clearing z = 1.96 (median 3-4). Schmitz et al. (2024)
#' report Brief-RC infoVals below 1.96 across all conditions in both of
#' their experiments. The status returned here therefore does not
#' `"fail"` on a per-participant headcount alone: it returns `"pass"`
#' when the median per-participant z is positive and `"warn"`
#' otherwise. Use [diagnose_infoval()] when you need a proper verdict
#' (random-responder calibration + group-mean z + masking).
#'
#' The 2IFC path delegates to [`rcicr::batchGenerateCI2IFC()`] and
#' [`rcicr::computeInfoVal2IFC()`] from the original `rcicr` package
#' (Dotsch, 2016; v1.0.1). The original `rcicr` uses a pool-size
#' reference distribution and does not expose a Brief-RC path. The Brief-RC route
#' here returns a `"skip"` result and points users at
#' [diagnose_infoval()], which uses an in-package native Brief-RC
#' implementation with a per-trial-count reference distribution.
#'
#' **Side effect (2IFC).** `rcicr` caches a reference distribution inside
#' the supplied `rdata` file on the first call. Subsequent calls reuse
#' it. Copy your `rdata` beforehand if you want the original untouched.
#'
#' @param responses A data frame of trial-level responses.
#' @param method `"2ifc"` (supported) or `"briefrc"` (returns `"skip"`).
#' @param rdata Path to the rcicr `.RData` file that produced the
#'   stimuli. Required for 2IFC.
#' @param baseimage Name of the base image used at generation time
#'   (the key in `base_face_files` in the rdata). Default `"base"`.
#' @param col_participant,col_stimulus,col_response Column names.
#' @param iter Number of iterations for rcicr's reference-distribution
#'   simulation. Default `10000` (the rcicr-recommended value).
#' @param threshold Numeric. Participants with infoVal below this are
#'   flagged as likely noise. Default `1.96`.
#' @param ... Unused.
#'
#' @return An [rcdiag_result()] object. For 2IFC, `data$per_participant`
#'   has one row per participant with `participant_id`, `infoval`, and
#'   `above_threshold` (logical: `infoval >= threshold`). For Brief-RC,
#'   a `"skip"` result pointing the user at [diagnose_infoval()].
#'
#' @references
#' Brinkman, L., Goffin, S., van de Schoot, R., van Haren, N. E., Dotsch,
#' R., & Aarts, H. (2019). Quantifying the informational value of
#' classification images. *Behavior Research Methods*, 51(5), 2059--2073.
#'
#' Dotsch, R. (2016). *rcicr: Reverse-correlation image-classification
#' toolbox* \[R package\].
#' \url{https://github.com/rdotsch/rcicr}
#'
#' @examples
#' \dontrun{
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
  label  <- "Information value"

  if (method == "briefrc") {
    return(rcdiag_result(
      "skip", label,
      c(
        "compute_infoval_summary() is the thin original-rcicr wrapper,",
        "which does not support Brief-RC. Use diagnose_infoval() instead --",
        "it ships an in-package native Brief-RC infoVal with a",
        "per-trial-count reference distribution."
      ),
      data = list(method = "briefrc")
    ))
  }

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

  # rcicr's 2IFC code uses %dopar%, tribble, and %>% at eval time.
  # Loading the namespaces isn't enough; they need to be on the search path.
  ensure_attached(c("foreach", "tibble", "dplyr"))

  data_df <- as.data.frame(responses)
  tmp_out <- tempfile()
  dir.create(tmp_out, showWarnings = FALSE, recursive = TRUE)

  cis <- rcicr::batchGenerateCI2IFC(
    data        = data_df,
    by          = col_participant,
    stimuli     = col_stimulus,
    responses   = col_response,
    baseimage   = baseimage,
    rdata       = rdata,
    save_as_png = FALSE,
    targetpath  = tmp_out
  )

  per_participant <- vapply(
    names(cis),
    function(nm) rcicr::computeInfoVal2IFC(cis[[nm]], rdata, iter = iter),
    numeric(1L)
  )
  ids <- extract_participant_ids(names(cis), baseimage, col_participant)
  per_p <- data.frame(
    participant_id  = ids,
    infoval         = unname(per_participant),
    above_threshold = unname(per_participant) >= threshold,
    stringsAsFactors = FALSE
  )

  n_total <- nrow(per_p)
  n_above <- sum(per_p$above_threshold)
  pct_above <- n_above / n_total
  med_z <- stats::median(per_p$infoval)

  # Per-producer z is structurally low even for compliant data. Refuse to
  # "fail" purely on a headcount; "pass" when the median is positive,
  # "warn" otherwise. Use diagnose_infoval() for a real verdict.
  status <- if (is.finite(med_z) && med_z > 0) "pass" else "warn"

  detail <- c(
    sprintf(
      "%d of %d participants have infoVal >= %.2f (%.1f%%).",
      n_above, n_total, threshold, 100 * pct_above
    ),
    sprintf(
      "InfoVal range: [%.2f, %.2f]; median %.2f.",
      min(per_p$infoval), max(per_p$infoval), med_z
    ),
    "Per-producer z is structurally low; use diagnose_infoval() for the full picture."
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
