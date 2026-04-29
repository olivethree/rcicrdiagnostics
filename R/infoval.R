# -----------------------------------------------------------------------------
# infoval() with trial-count-matched reference distribution.
#
# Ported from rcicrely (R/infoval.R, v0.2.x), authored by Manuel Oliveira and
# licensed MIT. Kept in-tree so rcicrdiagnostics has no hard dependency on
# rcicrely. Embeds the v0.2.1 sampling-without-replacement fix that
# corrected systematically inflated reference Frobenius norms in the original
# rcicr `generateReferenceDistribution2IFC()`.
# -----------------------------------------------------------------------------

#' Per-producer informational value with trial-count-matched reference
#'
#' Computes a z-scored informational value (infoVal) for each producer's
#' classification image, using a reference distribution matched to that
#' producer's trial count. Handles both 2IFC and Brief-RC paradigms with a
#' single function: the difference is entirely in what the user passes as
#' `noise_matrix`.
#'
#' The observed statistic is the Frobenius norm of producer j's
#' classification image mask, optionally restricted to a logical `mask`
#' (e.g. an oval face region via [face_mask()]):
#'
#' ```
#' norm_j = sqrt(sum( signal_matrix[mask, j]^2 ))
#' ```
#'
#' The reference distribution for producer j is built by simulating
#' `iter` random masks at the same trial count `trial_counts[j]`,
#' mirroring the `genMask()` construction of Schmitz, Rougier, &
#' Yzerbyt (2024):
#'
#' 1. Sample `trial_counts[j]` stimulus ids from `1:n_pool` without
#'    replacement when `trial_counts[j] <= n_pool` (the typical case
#'    for both 2IFC and Brief-RC), with replacement otherwise.
#' 2. Sample `trial_counts[j]` responses uniformly from `{-1, +1}`.
#' 3. Collapse `response` by `stim` via `mean()` (Brief-RC duplicate-
#'    stim rule).
#' 4. Build the mask: `noise_matrix[, unique_stims] %*% mean_response /
#'    n_unique_stims`.
#' 5. Apply `mask` (if supplied) and compute the Frobenius norm.
#'
#' The per-producer z-score is `(norm_j - median(ref)) / mad(ref)`,
#' using the reference matched to producer j's trial count. Producers
#' sharing a trial count share a reference.
#'
#' Trial-count matching closes a calibration gap in the original
#' `rcicr::generateReferenceDistribution2IFC()`, which uses the full
#' pool size for the reference even when individual producers see only
#' a subset (relevant for Brief-RC).
#'
#' **Sampling regime.** The reference simulation needs to mirror the
#' regime the experimenter used. Two questions matter:
#'
#' 1. *Within-trial*: each Brief-RC trial shows `m` distinct pool items
#'    (e.g. m=12 for Brief-RC 12), so within a single trial sampling
#'    is always without replacement. This is implicit in the data
#'    format and does not need a function argument.
#' 2. *Across-trials*: pool items can or cannot reappear on later
#'    trials, depending on whether the experimenter sampled the pool
#'    with or without replacement at the presentation level. This is
#'    a design decision and `with_replacement` controls it.
#'
#' `with_replacement = "auto"` resolves to `n_trials > n_pool`, which
#' matches the typical Brief-RC convention of without-replacement
#' presentation when the pool is large enough to fill the task
#' (Schmitz et al., 2024 do not explicitly characterize their two
#' experiments under this label, but their Experiment 1 design is
#' consistent with it: 60 trials x 12 alternatives = 720 = pool of 720
#' noisy faces). Override this only when you know your design departs
#' from the convention. Whichever choice you make, the observed-mask
#' side already handles duplicate chosen stimuli correctly because
#' the genMask collapse rule averages duplicates by `stim` id before
#' the matrix multiplication.
#'
#' For 2IFC, `n_trials == n_pool` by definition, both branches of the
#' heuristic resolve to without-replacement, and the question does not
#' arise.
#'
#' **Response-marginal assumption.** The reference simulator draws
#' random responses with `sample(c(-1, 1), n_trials, replace = TRUE)`
#' — uniform 50/50 ±1. This is exact under the standard Brief-RC
#' trial structure (Schmitz et al., 2024, p. 6), where each trial
#' shows an equal number of oriented and inverted faces (6/6 in
#' Brief-RC 12, 10/10 in Brief-RC 20), so a random producer's pick
#' yields `P(response = +1) = 0.5`. For 2IFC the assumption is
#' likewise exact (one oriented + one inverted per trial). Designs
#' with an unbalanced oriented/inverted split per trial, or trials
#' that overlap on the pool in non-standard ways, will see a small
#' calibration drift; the simulator does not currently expose a knob
#' for unbalanced splits.
#'
#' @param signal_matrix Pixels x participants numeric matrix of raw
#'   masks (one column per producer).
#' @param noise_matrix Pixels x pool-size numeric matrix of noise
#'   patterns. Each column is one pool item; the column index is the
#'   stimulus id used in your response data. Row count must match
#'   `signal_matrix`.
#' @param trial_counts Named integer vector. For each producer, the
#'   **number of trials they completed** (i.e. the number of rows in
#'   their response data, before any duplicate-stimulus collapse). Not
#'   the number of unique chosen stimuli, and not the number of
#'   alternatives shown per trial. Names must match
#'   `colnames(signal_matrix)`.
#' @param iter Reference-distribution Monte Carlo size. Default
#'   `10000L`.
#' @param mask Optional logical vector of length `nrow(signal_matrix)`.
#'   When supplied, both observed and reference norms are computed on
#'   the masked pixel subset.
#' @param with_replacement Sampling regime for the reference
#'   distribution at the **across-trials** level (i.e. how stimulus
#'   ids are drawn when simulating a random producer). One of:
#'   `"auto"` (default), `TRUE`, or `FALSE`. `"auto"` matches the
#'   common Brief-RC convention: without replacement when a producer's
#'   trial count fits in the pool, with replacement otherwise. Set
#'   explicitly only if your task design departs from this convention
#'   (e.g. you sampled with replacement on a small pool); see
#'   "Sampling regime" in Details.
#' @param cache_path Optional path to an `.rds` file. When set and the
#'   file exists with a matching configuration (iter, n_pool, mask
#'   signature), references are loaded from it; otherwise computed
#'   references are written there. Caches reference norms only.
#' @param seed Optional integer; RNG state restored on exit.
#' @param progress Show a `cli` progress bar.
#'
#' @return Object of class `rcdiag_infoval` with fields `$infoval`,
#'   `$norms`, `$reference`, `$ref_median`, `$ref_mad`,
#'   `$trial_counts`, `$mask`, `$iter`, `$n_pool`, `$seed`.
#'
#' @references
#' Brinkman, L., Goffin, S., van de Schoot, R., van Haren, N. E. M.,
#' Dotsch, R., & Aarts, H. (2019). Quantifying the informational value
#' of classification images. *Behavior Research Methods*, 51(5),
#' 2059-2073. \doi{10.3758/s13428-019-01232-2}
#'
#' Schmitz, M., Rougier, M., & Yzerbyt, V. (2020). Comment on
#' "Quantifying the informational value of classification images": A
#' miscomputation of the infoVal metric. *Behavior Research Methods*,
#' 52(3), 1383-1386. \doi{10.3758/s13428-019-01295-1}
#'
#' Schmitz, M., Rougier, M., Yzerbyt, V., Brinkman, L., & Dotsch, R.
#' (2020). Erratum to: Comment on "Quantifying the informational value
#' of classification images": Miscomputation of infoVal metric was a
#' minor issue and is now corrected. *Behavior Research Methods*,
#' 52(4), 1800-1801. \doi{10.3758/s13428-020-01367-7}
#'
#' Schmitz, M., Rougier, M., & Yzerbyt, V. (2024). Introducing the
#' brief reverse correlation: an improved tool to assess visual
#' representations. *European Journal of Social Psychology*.
#' \doi{10.1002/ejsp.3100}
#'
#' @seealso [face_mask()], [diagnose_infoval()].
#'
#' @export
infoval <- function(signal_matrix,
                    noise_matrix,
                    trial_counts,
                    iter             = 10000L,
                    mask             = NULL,
                    with_replacement = c("auto", TRUE, FALSE),
                    cache_path       = NULL,
                    seed             = NULL,
                    progress         = TRUE) {
  if (is.character(with_replacement)) {
    with_replacement <- match.arg(with_replacement)
  } else if (!isTRUE(with_replacement) && !isFALSE(with_replacement)) {
    cli::cli_abort(
      "{.arg with_replacement} must be {.val auto}, {.val TRUE}, or {.val FALSE}."
    )
  }
  if (!is.matrix(signal_matrix) || !is.numeric(signal_matrix)) {
    cli::cli_abort("{.arg signal_matrix} must be a numeric matrix.")
  }
  if (!is.matrix(noise_matrix) || !is.numeric(noise_matrix)) {
    cli::cli_abort("{.arg noise_matrix} must be a numeric matrix.")
  }
  if (nrow(signal_matrix) != nrow(noise_matrix)) {
    cli::cli_abort(c(
      "Row counts of {.arg signal_matrix} and {.arg noise_matrix} must match.",
      "*" = "signal: {nrow(signal_matrix)} pixels",
      "*" = "noise: {nrow(noise_matrix)} pixels"
    ))
  }
  n_pix  <- nrow(signal_matrix)
  n_pool <- ncol(noise_matrix)

  if (is.null(colnames(signal_matrix))) {
    colnames(signal_matrix) <- sprintf("p%03d", seq_len(ncol(signal_matrix)))
  }
  producers <- colnames(signal_matrix)

  if (is.null(names(trial_counts))) {
    cli::cli_abort(
      "{.arg trial_counts} must be a named integer vector; names must match {.code colnames(signal_matrix)}."
    )
  }
  missing_ids <- setdiff(producers, names(trial_counts))
  if (length(missing_ids) > 0L) {
    cli::cli_abort(c(
      "Missing trial counts for {length(missing_ids)} producer{?s}:",
      "*" = "{.val {missing_ids}}"
    ))
  }
  trial_counts <- as.integer(trial_counts[producers])

  if (!is.null(mask)) {
    if (!is.logical(mask) || length(mask) != n_pix) {
      cli::cli_abort(
        "{.arg mask} must be a logical vector of length {n_pix}."
      )
    }
  }

  iter <- as.integer(iter)
  if (iter < 100L) {
    cli::cli_warn(
      "{.arg iter} = {iter} is very low; MAD will be unstable."
    )
  }

  # ---- observed norms -------------------------------------------------
  norms <- vapply(
    seq_len(ncol(signal_matrix)),
    function(j) {
      x <- signal_matrix[, j]
      if (!is.null(mask)) x <- x[mask]
      sqrt(sum(x * x))
    },
    numeric(1L)
  )
  names(norms) <- producers

  # ---- reference distributions, keyed on unique trial counts ---------
  unique_n_trials <- sort(unique(trial_counts))

  cache <- NULL
  cache_hit <- FALSE
  if (!is.null(cache_path) && file.exists(cache_path)) {
    cache <- readRDS(cache_path)
    if (is.list(cache) &&
          !is.null(cache$reference) &&
          !is.null(cache$iter) &&
          cache$iter == iter &&
          setequal(names(cache$reference), as.character(unique_n_trials)) &&
          identical(cache$n_pool, n_pool) &&
          identical(cache$mask_sig, mask_signature(mask)) &&
          identical(cache$with_replacement, with_replacement)) {
      cache_hit <- TRUE
    }
  }

  if (cache_hit) {
    reference <- cache$reference[as.character(unique_n_trials)]
  } else {
    reference <- stats::setNames(
      vector("list", length(unique_n_trials)),
      as.character(unique_n_trials)
    )
    total_sims <- iter * length(unique_n_trials)
    pid <- progress_start(total_sims, "infoval reference", show = progress)
    on.exit(progress_done(pid), add = TRUE)
    with_seed(seed, {
      for (n_t in unique_n_trials) {
        reference[[as.character(n_t)]] <-
          simulate_reference_norms(noise_matrix, n_t, iter, mask,
                                   with_replacement, pid)
      }
    })
    if (!is.null(cache_path)) {
      saveRDS(list(
        reference        = reference,
        iter             = iter,
        n_pool           = n_pool,
        mask_sig         = mask_signature(mask),
        with_replacement = with_replacement
      ), cache_path)
    }
  }

  ref_median <- vapply(reference, stats::median, numeric(1L))
  ref_mad    <- vapply(reference, stats::mad,    numeric(1L))

  # ---- per-producer z-scores -----------------------------------------
  iv <- vapply(
    seq_along(norms),
    function(j) {
      key <- as.character(trial_counts[j])
      (norms[j] - ref_median[key]) / ref_mad[key]
    },
    numeric(1L)
  )
  names(iv) <- producers

  new_rcdiag_infoval(
    infoval      = iv,
    norms        = norms,
    reference    = reference,
    ref_median   = ref_median,
    ref_mad      = ref_mad,
    trial_counts = stats::setNames(trial_counts, producers),
    mask         = mask,
    iter         = iter,
    n_pool       = n_pool,
    seed         = seed
  )
}

# Simulate `iter` random Frobenius norms for a given trial count.
# Mirrors Schmitz's genMask() construction (random sign per stim,
# mean-by-stim collapse, divide by number of unique chosen stims,
# Frobenius norm). The `with_replacement` argument selects the
# across-trials sampling regime: "auto" => n_trials > n_pool (the
# Schmitz convention), TRUE/FALSE override.
simulate_reference_norms <- function(noise_matrix, n_trials, iter,
                                     mask = NULL,
                                     with_replacement = "auto",
                                     pid = NULL) {
  n_pool <- ncol(noise_matrix)
  use_replace <- if (identical(with_replacement, "auto")) {
    n_trials > n_pool
  } else {
    isTRUE(with_replacement)
  }
  if (!use_replace && n_trials > n_pool) {
    cli::cli_abort(c(
      "Cannot sample {n_trials} trials without replacement from a pool of {n_pool}.",
      "i" = "Set {.arg with_replacement = TRUE} or use a larger noise pool."
    ))
  }
  norms  <- numeric(iter)
  for (k in seq_len(iter)) {
    stim <- sample.int(n_pool, n_trials, replace = use_replace)
    resp <- sample(c(-1, 1), n_trials, replace = TRUE)
    uniq <- sort(unique(stim))
    if (length(uniq) < length(stim)) {
      idx <- match(stim, uniq)
      sums <- tabulate(idx, length(uniq))
      wts  <- as.vector(tapply(resp, idx, sum)) / sums
    } else {
      ord  <- order(stim)
      uniq <- stim[ord]
      wts  <- resp[ord]
    }
    mask_vec <- noise_matrix[, uniq, drop = FALSE] %*% wts / length(uniq)
    if (!is.null(mask)) mask_vec <- mask_vec[mask]
    norms[k] <- sqrt(sum(mask_vec * mask_vec))
    progress_tick(pid)
  }
  norms
}

# Cheap signature of a mask vector for cache identity checking.
mask_signature <- function(mask) {
  if (is.null(mask)) return("none")
  sprintf("%d/%d", sum(mask), length(mask))
}
