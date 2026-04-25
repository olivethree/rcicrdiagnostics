#' Guided diagnostic for low or negative infoVal
#'
#' Walks through six checks that explain why per-producer infoVal often
#' looks "low" even on healthy data, and surfaces the numbers that
#' actually belong in a methods section. Use this when individual
#' producers' infoVal z-scores look suspiciously low or negative and
#' you want to know whether the data is broken or merely structurally
#' diluted.
#'
#' The six steps:
#'
#' 1. Simulate the reference distribution at every unique producer
#'    trial count present in the data.
#' 2. Sanity-check the reference with a simulated random responder.
#'    A random producer should land near `z = 0`; `|z| > 2` indicates
#'    the reference is mis-calibrated.
#' 3. Compute per-producer z unmasked.
#' 4. Compute per-producer z with the supplied (or auto-generated)
#'    face mask, and report the median masked-vs-unmasked z lift.
#' 5. Compute the group-mean CI's z, against a reference matched to
#'    the same producer count and trial counts.
#' 6. Tabulate per-producer z into four bands (`< -1.96`,
#'    `[-1.96, 0)`, `[0, 1.96)`, `>= 1.96`) and produce interpretation
#'    bullets summarising the evidence.
#'
#' Whether per-producer z values cluster above or below the
#' conventional 1.96 threshold is paradigm- and target-dependent.
#' Brinkman et al. (2019) report 54-68% of 2IFC participants clearing
#' 1.96 on perceived gender (median 3-4); Schmitz et al. (2024) report
#' Brief-RC infoVals systematically below 1.96 across all conditions
#' in both experiments. The reportable summary is therefore
#' context-specific: per-producer z is useful for exclusion decisions
#' on individual cases, while the group-mean CI's z is often the more
#' defensible aggregate when individual-level z is noisy.
#'
#' For `method = "2ifc"`, the function calls `rcicr` to reconstruct
#' per-trial noise patterns from `stimuli_params` and `p` (the
#' `.RData` does not store the patterns themselves; see vignette
#' "What data the package expects"). The reconstruction is one
#' `rcicr::generateNoiseImage()` call per pool item, which is fast
#' (seconds) but does require `rcicr` to be installed. The Brief-RC
#' path needs no `rcicr` dependency.
#'
#' @param responses A data frame of trial-level responses.
#' @param method `"2ifc"` or `"briefrc"`. If `NULL`, inferred from
#'   whichever of `rdata` / `noise_matrix` is supplied.
#' @param rdata Path to an rcicr `.RData` file (2IFC).
#' @param noise_matrix Path to a Brief-RC noise-matrix text file, or
#'   an already-loaded numeric matrix.
#' @param baseimage Name of the base image in the rdata
#'   `base_face_files` list. Default `"base"`. Only consulted for 2IFC.
#' @param col_participant,col_stimulus,col_response Column names.
#' @param iter Reference-distribution Monte Carlo size. Default
#'   `1000L` (a diagnostic-grade value). Bump to `10000` for
#'   publication numbers.
#' @param face_mask Mask specification. One of:
#'   * `"auto"` (default): generate a Schmitz 2024 oval via
#'     [face_mask()] sized to the image dims.
#'   * `NULL`: skip the masked-vs-unmasked comparison.
#'   * A logical vector of length `n_pixels`.
#'   * A numeric matrix matching the image dims (coerced via `> 0.5`).
#'   * A character path to a PNG / JPEG mask image (loaded via
#'     [load_face_mask()]).
#' @param with_replacement Sampling regime forwarded to [infoval()] for
#'   building the reference distribution at the across-trials level.
#'   `"auto"` (default) matches the standard Brief-RC convention
#'   (without replacement when a producer's trial count fits in the
#'   pool, with replacement otherwise). Set explicitly only if your
#'   task design departs from this convention. See [infoval()] for
#'   details. Ignored on the 2IFC path because there `n_trials`
#'   equals the pool size by construction.
#' @param seed Optional integer; RNG state restored on exit.
#' @param progress Show a `cli` progress bar.
#' @param ... Unused.
#'
#' @return An [rcdiag_result()]. `data` carries the rich output:
#'   * `random_responder_z` -- numeric scalar.
#'   * `infoval_unmasked` -- `rcdiag_infoval` object (see [infoval()]).
#'   * `infoval_masked` -- `rcdiag_infoval`; `NULL` when no mask.
#'   * `group_mean_z_unmasked`, `group_mean_z_masked` -- scalars.
#'   * `tally` -- named integer vector with counts per z band.
#'   * `mask` -- logical vector or `NULL`.
#'   * `interpretation` -- character vector of human-readable bullets.
#'
#' @seealso [infoval()], [face_mask()], [compute_infoval_summary()].
#'
#' @references
#' Brinkman, L., Goffin, S., van de Schoot, R., van Haren, N. E. M.,
#' Dotsch, R., & Aarts, H. (2019). Quantifying the informational value
#' of classification images. *Behavior Research Methods*, 51(5),
#' 2059-2073.
#'
#' Schmitz, M., Rougier, M., & Yzerbyt, V. (2024). Introducing the
#' brief reverse correlation: an improved tool to assess visual
#' representations. *European Journal of Social Psychology*.
#'
#' @examples
#' \dontrun{
#' diagnose_infoval(
#'   responses, method = "2ifc",
#'   rdata = "stimuli.RData",
#'   iter  = 1000
#' )
#' }
#'
#' @export
diagnose_infoval <- function(responses,
                             method           = NULL,
                             rdata            = NULL,
                             noise_matrix     = NULL,
                             baseimage        = "base",
                             col_participant  = "participant_id",
                             col_stimulus     = "stimulus",
                             col_response     = "response",
                             iter             = 1000L,
                             face_mask        = "auto",
                             with_replacement = "auto",
                             seed             = NULL,
                             progress         = TRUE,
                             ...) {
  method <- resolve_method(method, rdata, noise_matrix)
  validate_responses_df(responses, col_participant, col_stimulus, col_response)
  iter <- as.integer(iter)
  label <- "InfoVal diagnostic"

  built <- build_diagnose_inputs(
    responses, method, rdata, noise_matrix, baseimage,
    col_participant, col_stimulus, col_response
  )
  signal_matrix <- built$signal_matrix
  noise_mat     <- built$noise_matrix
  trial_counts  <- built$trial_counts
  img_dims      <- built$img_dims

  mask_vec <- resolve_face_mask(face_mask, img_dims, nrow(signal_matrix))

  # Step 1+3: per-producer z, unmasked.
  iv_unmasked <- infoval(
    signal_matrix    = signal_matrix,
    noise_matrix     = noise_mat,
    trial_counts     = trial_counts,
    iter             = iter,
    mask             = NULL,
    with_replacement = with_replacement,
    seed             = seed,
    progress         = progress
  )

  # Step 4: per-producer z, masked (optional).
  iv_masked <- NULL
  if (!is.null(mask_vec)) {
    iv_masked <- infoval(
      signal_matrix    = signal_matrix,
      noise_matrix     = noise_mat,
      trial_counts     = trial_counts,
      iter             = iter,
      mask             = mask_vec,
      with_replacement = with_replacement,
      seed             = seed,
      progress         = progress
    )
  }

  # Step 2: random-responder calibration. Re-uses iv_unmasked's reference
  # distribution at the median trial count.
  cal_n_trials <- as.integer(stats::median(trial_counts))
  cal_key      <- as.character(cal_n_trials)
  if (!cal_key %in% names(iv_unmasked$reference)) {
    # median trial count not present (e.g., even-N median falls between
    # bins); fall back to the most common trial count.
    cal_n_trials <- as.integer(
      names(sort(table(trial_counts), decreasing = TRUE))[1L]
    )
    cal_key <- as.character(cal_n_trials)
  }
  random_z <- random_responder_calibration(
    noise_matrix     = noise_mat,
    n_trials         = cal_n_trials,
    mask             = NULL,
    reference_norms  = iv_unmasked$reference[[cal_key]],
    with_replacement = with_replacement,
    seed             = seed
  )

  # Step 5: group-mean CI z, unmasked and masked.
  grp_z_unmasked <- group_mean_z(
    signal_matrix, noise_mat, trial_counts, iter,
    mask = NULL, with_replacement = with_replacement,
    seed = seed, progress = progress
  )
  grp_z_masked <- if (!is.null(mask_vec)) {
    group_mean_z(
      signal_matrix, noise_mat, trial_counts, iter,
      mask = mask_vec, with_replacement = with_replacement,
      seed = seed, progress = progress
    )
  } else NA_real_

  # Step 6: tally + interpretation.
  z_for_tally <- if (!is.null(iv_masked)) iv_masked$infoval else iv_unmasked$infoval
  tally <- tally_z(z_for_tally)
  bullets <- interpret_infoval(
    random_z         = random_z,
    iv_unmasked      = iv_unmasked,
    iv_masked        = iv_masked,
    grp_z_unmasked   = grp_z_unmasked,
    grp_z_masked     = grp_z_masked,
    tally            = tally
  )

  status <- decide_status(random_z, grp_z_unmasked, grp_z_masked)
  detail <- c(
    sprintf("Random-responder z = %+.2f (expected near 0).", random_z),
    sprintf(
      "Group-mean CI z = %+.2f (unmasked)%s.",
      grp_z_unmasked,
      if (!is.na(grp_z_masked))
        sprintf(", %+.2f (masked)", grp_z_masked) else ""
    ),
    sprintf(
      "Per-producer z: median %+.2f%s; %d / %d above 1.96.",
      stats::median(z_for_tally),
      if (!is.null(iv_masked))
        sprintf(" (masked); %+.2f (unmasked)",
                stats::median(iv_unmasked$infoval)) else "",
      tally[["above_1.96"]], length(z_for_tally)
    ),
    "",
    bullets
  )

  rcdiag_result(
    status, label, detail,
    data = list(
      method                = method,
      iter                  = iter,
      mask                  = mask_vec,
      random_responder_z    = random_z,
      infoval_unmasked      = iv_unmasked,
      infoval_masked        = iv_masked,
      group_mean_z_unmasked = grp_z_unmasked,
      group_mean_z_masked   = grp_z_masked,
      tally                 = tally,
      interpretation        = bullets
    )
  )
}

# ---- Internal helpers -------------------------------------------------

# Build per-producer signal matrix, noise matrix, trial counts, img dims.
build_diagnose_inputs <- function(responses, method, rdata, noise_matrix,
                                  baseimage, col_participant,
                                  col_stimulus, col_response) {
  if (method == "2ifc") {
    if (is.null(rdata)) {
      cli::cli_abort("{.arg rdata} is required for {.arg method = \"2ifc\"}.")
    }
    validate_path(rdata, "rdata")
    return(build_inputs_2ifc(
      responses, rdata, baseimage,
      col_participant, col_stimulus, col_response
    ))
  }

  if (is.null(noise_matrix)) {
    cli::cli_abort(
      "{.arg noise_matrix} is required for {.arg method = \"briefrc\"}."
    )
  }
  build_inputs_briefrc(
    responses, noise_matrix,
    col_participant, col_stimulus, col_response
  )
}

build_inputs_2ifc <- function(responses, rdata, baseimage,
                              col_participant, col_stimulus, col_response) {
  if (!requireNamespace("rcicr", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg rcicr} is required for the 2IFC path.",
      "i" = "Install with {.code remotes::install_github(\"rdotsch/rcicr\")}."
    ))
  }
  ensure_attached(c("foreach", "tibble", "dplyr"))

  env <- new.env(parent = emptyenv())
  load(rdata, envir = env)

  required <- c("base_faces", "stimuli_params", "p")
  missing_objs <- setdiff(required, ls(env))
  if (length(missing_objs) > 0L) {
    cli::cli_abort(c(
      "Required object{?s} not found in {.path {rdata}}: {.val {missing_objs}}.",
      "i" = "Expected the output of {.fn rcicr::generateStimuli2IFC}, which saves base_faces, stimuli_params, and p."
    ))
  }
  if (!baseimage %in% names(env$base_faces)) {
    cli::cli_abort(c(
      "{.arg baseimage} = {.val {baseimage}} not in rdata.",
      "i" = "Available: {.val {names(env$base_faces)}}"
    ))
  }
  base_mat <- env$base_faces[[baseimage]]
  img_dims <- as.integer(dim(base_mat))
  n_pix    <- prod(img_dims)

  params_mat <- env$stimuli_params[[baseimage]]
  if (is.null(params_mat)) {
    cli::cli_abort(
      "{.arg baseimage} = {.val {baseimage}} has no entry in stimuli_params."
    )
  }
  n_pool <- nrow(params_mat)

  # Reconstruct the per-trial noise patterns from the basis (p) and the
  # per-trial contrast weights (stimuli_params). rcicr does not store the
  # 3D stimulus array in the .RData; it recomputes on demand.
  noise_mat <- matrix(NA_real_, nrow = n_pix, ncol = n_pool)
  for (i in seq_len(n_pool)) {
    noise_mat[, i] <- as.vector(
      rcicr::generateNoiseImage(params_mat[i, ], env$p)
    )
  }

  # CIs via rcicr.
  responses_df <- as.data.frame(responses)
  tmp_out <- tempfile()
  dir.create(tmp_out, showWarnings = FALSE, recursive = TRUE)
  cis <- rcicr::batchGenerateCI2IFC(
    data        = responses_df,
    by          = col_participant,
    stimuli     = col_stimulus,
    responses   = col_response,
    baseimage   = baseimage,
    rdata       = rdata,
    save_as_png = FALSE,
    targetpath  = tmp_out
  )

  ids <- extract_participant_ids(names(cis), baseimage, col_participant)
  signal_matrix <- vapply(
    seq_along(cis),
    function(i) as.vector(cis[[i]]$ci),
    numeric(n_pix)
  )
  colnames(signal_matrix) <- ids

  trial_counts <- compute_trial_counts(responses, col_participant, ids)
  list(
    signal_matrix = signal_matrix,
    noise_matrix  = noise_mat,
    trial_counts  = trial_counts,
    img_dims      = img_dims
  )
}

build_inputs_briefrc <- function(responses, noise_matrix,
                                 col_participant, col_stimulus, col_response) {
  noise_mat <- if (is.character(noise_matrix)) {
    read_noise_matrix(noise_matrix)
  } else if (is.matrix(noise_matrix) && is.numeric(noise_matrix)) {
    noise_matrix
  } else {
    cli::cli_abort(
      "{.arg noise_matrix} must be a path or a numeric matrix."
    )
  }

  n_pix <- nrow(noise_mat)
  side  <- as.integer(sqrt(n_pix))
  img_dims <- if (side * side == n_pix) c(side, side) else c(n_pix, 1L)

  resp_vals <- as.numeric(responses[[col_response]])
  uniq <- sort(unique(resp_vals[is.finite(resp_vals)]))
  if (!identical(uniq, c(-1, 1))) {
    cli::cli_abort(c(
      "Brief-RC {.arg col_response} must contain only {-1, 1}.",
      "*" = "Got: {.val {uniq}}"
    ))
  }

  participants <- as.character(unique(responses[[col_participant]]))
  signal_matrix <- matrix(NA_real_, nrow = n_pix, ncol = length(participants),
                          dimnames = list(NULL, participants))

  pid_vec <- as.character(responses[[col_participant]])
  stim_all <- as.integer(responses[[col_stimulus]])
  n_pool   <- ncol(noise_mat)
  if (any(stim_all < 1L | stim_all > n_pool, na.rm = TRUE)) {
    rng <- range(stim_all, na.rm = TRUE)
    cli::cli_abort(c(
      "{.arg col_stimulus} has ids outside the pool range.",
      "*" = "Range in data: [{rng[1]}, {rng[2]}]",
      "*" = "Pool size: {n_pool}"
    ))
  }

  # Schmitz 2024 genMask exactly: collapse duplicates by mean(response),
  # mask = noise[, unique_stims] %*% mean_response / n_unique_stims.
  for (pid in participants) {
    idx <- which(pid_vec == pid)
    if (length(idx) == 0L) next
    dt <- data.table::data.table(
      response = resp_vals[idx],
      stim     = stim_all[idx]
    )
    dt <- dt[, list(response = mean(.SD[[1L]])), by = "stim",
             .SDcols = "response"]
    mask_vec <- (noise_mat[, dt$stim, drop = FALSE] %*% dt$response) /
                  nrow(dt)
    signal_matrix[, pid] <- as.numeric(mask_vec)
  }

  trial_counts <- compute_trial_counts(responses, col_participant, participants)
  list(
    signal_matrix = signal_matrix,
    noise_matrix  = noise_mat,
    trial_counts  = trial_counts,
    img_dims      = img_dims
  )
}

compute_trial_counts <- function(responses, col_participant, ids) {
  pid_vec <- as.character(responses[[col_participant]])
  counts <- as.integer(table(pid_vec)[ids])
  names(counts) <- ids
  counts
}

# Resolve a face_mask spec into a logical vector of length n_pixels.
resolve_face_mask <- function(spec, img_dims, n_pixels) {
  if (is.null(spec)) return(NULL)
  if (identical(spec, "auto")) {
    return(face_mask(img_dims))
  }
  if (is.logical(spec)) {
    if (length(spec) != n_pixels) {
      cli::cli_abort(
        "{.arg face_mask} logical vector length \\
         {length(spec)} != n_pixels {n_pixels}."
      )
    }
    return(as.logical(spec))
  }
  if (is.matrix(spec)) {
    if (length(spec) != n_pixels) {
      cli::cli_abort(
        "{.arg face_mask} matrix length {length(spec)} != n_pixels {n_pixels}."
      )
    }
    return(as.vector(spec) > 0.5)
  }
  if (is.character(spec) && length(spec) == 1L) {
    out <- load_face_mask(spec)
    if (length(out) != n_pixels) {
      cli::cli_abort(c(
        "Loaded mask has wrong pixel count.",
        "*" = "Mask: {length(out)}",
        "*" = "Image: {n_pixels}"
      ))
    }
    return(out)
  }
  cli::cli_abort(
    "{.arg face_mask} must be \"auto\", NULL, a logical vector, a matrix, or a path."
  )
}

# Random-responder z-score: simulate a single random producer at n_trials,
# compute its Frobenius norm via the same genMask-style construction, then
# z-score against the reference distribution at that trial count.
random_responder_calibration <- function(noise_matrix, n_trials, mask,
                                         reference_norms,
                                         with_replacement = "auto",
                                         seed = NULL) {
  norm_obs <- with_seed(seed, {
    n_pool <- ncol(noise_matrix)
    use_replace <- if (identical(with_replacement, "auto")) {
      n_trials > n_pool
    } else {
      isTRUE(with_replacement)
    }
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
    mvec <- noise_matrix[, uniq, drop = FALSE] %*% wts / length(uniq)
    if (!is.null(mask)) mvec <- mvec[mask]
    sqrt(sum(mvec * mvec))
  })
  (norm_obs - stats::median(reference_norms)) /
    stats::mad(reference_norms)
}

# Group-mean CI z: reduce signal_matrix to a single column-mean mask, build
# a reference distribution of group-mean norms by averaging N random
# producer masks (matched to the actual trial counts), and z-score.
group_mean_z <- function(signal_matrix, noise_matrix, trial_counts, iter,
                         mask = NULL, with_replacement = "auto",
                         seed = NULL, progress = TRUE) {
  grp <- rowMeans(signal_matrix)
  if (!is.null(mask)) grp <- grp[mask]
  norm_obs <- sqrt(sum(grp * grp))

  ref <- numeric(iter)
  pid <- progress_start(iter, "group-mean reference", show = progress)
  on.exit(progress_done(pid), add = TRUE)
  with_seed(seed, {
    n_pool <- ncol(noise_matrix)
    n_pix  <- nrow(noise_matrix)
    resolve_use_replace <- function(n_t) {
      if (identical(with_replacement, "auto")) n_t > n_pool
      else isTRUE(with_replacement)
    }
    for (k in seq_len(iter)) {
      acc <- numeric(n_pix)
      for (n_t in trial_counts) {
        use_replace <- resolve_use_replace(n_t)
        stim <- sample.int(n_pool, n_t, replace = use_replace)
        resp <- sample(c(-1, 1), n_t, replace = TRUE)
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
        acc <- acc + as.numeric(
          noise_matrix[, uniq, drop = FALSE] %*% wts / length(uniq)
        )
      }
      grp_sim <- acc / length(trial_counts)
      if (!is.null(mask)) grp_sim <- grp_sim[mask]
      ref[k] <- sqrt(sum(grp_sim * grp_sim))
      progress_tick(pid)
    }
  })
  (norm_obs - stats::median(ref)) / stats::mad(ref)
}

tally_z <- function(z) {
  c(
    `< -1.96`            = sum(z < -1.96, na.rm = TRUE),
    `[-1.96, 0)`         = sum(z >= -1.96 & z < 0, na.rm = TRUE),
    `[0, 1.96)`          = sum(z >= 0 & z < 1.96, na.rm = TRUE),
    above_1.96           = sum(z >= 1.96, na.rm = TRUE)
  )
}

# Status: a healthy diagnostic has |random_z| < 2 (calibration ok) AND
# group-mean z >= 1.96 in at least one of unmasked / masked.
decide_status <- function(random_z, grp_unmasked, grp_masked) {
  if (!is.finite(random_z) || abs(random_z) > 2) return("fail")
  best_grp <- max(c(grp_unmasked, grp_masked), na.rm = TRUE)
  if (!is.finite(best_grp))                      return("warn")
  if (best_grp >= 1.96 && abs(random_z) < 1)     return("pass")
  if (best_grp >= 1.96)                          return("warn")
  "warn"
}

# Human-readable bullet list. Rule engine, not a model -- keep it simple
# and faithful to the numbers.
interpret_infoval <- function(random_z, iv_unmasked, iv_masked,
                              grp_z_unmasked, grp_z_masked, tally) {
  out <- character()

  if (abs(random_z) < 1) {
    out <- c(out, sprintf(
      "Reference calibration looks correct (random producer z = %+.2f).",
      random_z
    ))
  } else if (abs(random_z) <= 2) {
    out <- c(out, sprintf(
      "Reference calibration is within tolerance but noisy (z = %+.2f); consider raising iter.",
      random_z
    ))
  } else {
    out <- c(out, sprintf(
      "Reference calibration FAILED: random producer z = %+.2f. The reference distribution and observed-mask construction are not aligned. Investigate before trusting any z-score below.",
      random_z
    ))
  }

  best_grp <- max(c(grp_z_unmasked, grp_z_masked), na.rm = TRUE)
  if (is.finite(best_grp) && best_grp >= 1.96) {
    out <- c(out, sprintf(
      "Group-mean CI is informative (z = %+.2f); this is the number to report in a methods section.",
      best_grp
    ))
  } else if (is.finite(best_grp)) {
    out <- c(out, sprintf(
      "Group-mean CI is below z = 1.96 (best %+.2f); consider whether trial count, producer count, or sampling strategy needs revision.",
      best_grp
    ))
  }

  med_z <- if (!is.null(iv_masked)) stats::median(iv_masked$infoval) else
             stats::median(iv_unmasked$infoval)
  if (med_z < 1.96) {
    out <- c(out, sprintf(
      "Per-producer z is below threshold (median %+.2f); %d / %d individuals exceed z = 1.96. Whether this is expected depends on paradigm and target -- Brinkman (2019) reports ~54-68%% clearance on 2IFC gender, Schmitz (2024) reports all Brief-RC conditions below 1.96.",
      med_z, tally[["above_1.96"]], sum(tally)
    ))
  }

  if (!is.null(iv_masked)) {
    lift <- stats::median(iv_masked$infoval) -
              stats::median(iv_unmasked$infoval)
    if (is.finite(lift)) {
      out <- c(out, sprintf(
        "Face-mask z-lift = %+.2f (masked - unmasked, median across producers).",
        lift
      ))
    }
  }

  n_low <- tally[["< -1.96"]]
  if (n_low > 0L) {
    out <- c(out, sprintf(
      "%d producer%s z < -1.96. InfoVal is direction-agnostic (Frobenius norm has no sign), so negative z does not imply anti-signal; it is geometrically consistent with a low-rank mask, but this interpretation is not established in the literature. Inspect the producer mask%s before deciding.",
      n_low,
      if (n_low == 1L) " has" else "s have",
      if (n_low == 1L) "" else "s"
    ))
  }

  out
}
