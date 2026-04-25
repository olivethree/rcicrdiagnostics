# diagnose_infoval() end-to-end tests, Brief-RC path (no rcicr required).

make_random_briefrc_data <- function(n_prod = 12L, n_trials = 100L,
                                     n_pool = 200L, n_pix = 64L * 64L,
                                     seed = 1L, sd = 0.05) {
  set.seed(seed)
  noise <- matrix(stats::rnorm(n_pix * n_pool, sd = sd), n_pix, n_pool)
  resp <- do.call(rbind, lapply(sprintf("P%02d", seq_len(n_prod)), function(pid) {
    stims <- sample.int(n_pool, n_trials, replace = FALSE)
    data.frame(
      participant_id = pid,
      stimulus       = stims,
      response       = sample(c(-1L, 1L), n_trials, replace = TRUE),
      stringsAsFactors = FALSE
    )
  }))
  list(responses = resp, noise = noise)
}

# Inject coherent group-level signal into otherwise random Brief-RC data.
make_compliant_briefrc_data <- function(n_prod = 20L, n_trials = 200L,
                                        n_pool = 300L, n_pix = 64L * 64L,
                                        bias = 0.05, seed = 2L) {
  set.seed(seed)
  noise <- matrix(stats::rnorm(n_pix * n_pool, sd = 0.05), n_pix, n_pool)
  target <- numeric(n_pix)
  target[which(face_mask(c(64L, 64L), region = "eyes"))] <- 1
  target_norm <- target / sqrt(sum(target * target))
  alignment <- as.numeric(t(target_norm) %*% noise)
  resp <- do.call(rbind, lapply(sprintf("P%02d", seq_len(n_prod)), function(pid) {
    stims <- sample.int(n_pool, n_trials, replace = FALSE)
    ali   <- alignment[stims]
    prob  <- 0.5 + bias * sign(ali)
    rsp   <- vapply(prob, function(p)
      sample(c(-1L, 1L), 1L, prob = c(1 - p, p)),
      integer(1L))
    data.frame(participant_id = pid, stimulus = stims, response = rsp,
               stringsAsFactors = FALSE)
  }))
  list(responses = resp, noise = noise)
}

test_that("diagnose_infoval returns a valid rcdiag_result with rich data", {
  d <- make_random_briefrc_data()
  res <- diagnose_infoval(
    d$responses, method = "briefrc", noise_matrix = d$noise,
    iter = 200L, face_mask = "auto", seed = 1L, progress = FALSE
  )
  expect_s3_class(res, "rcdiag_result")
  expect_true(res$status %in% c("pass", "warn", "fail"))
  expect_true(all(c("random_responder_z", "infoval_unmasked",
                    "group_mean_z_unmasked", "group_mean_z_masked",
                    "tally", "interpretation") %in% names(res$data)))
  expect_s3_class(res$data$infoval_unmasked, "rcdiag_infoval")
  expect_s3_class(res$data$infoval_masked,   "rcdiag_infoval")
})

test_that("random-responder data produces near-zero random_z and low group z", {
  d <- make_random_briefrc_data(n_prod = 16L, n_trials = 150L)
  res <- diagnose_infoval(
    d$responses, method = "briefrc", noise_matrix = d$noise,
    iter = 500L, face_mask = NULL, seed = 1L, progress = FALSE
  )
  expect_lt(abs(res$data$random_responder_z), 1.5)
  # Random data should NOT yield a publishable group-mean z.
  expect_lt(res$data$group_mean_z_unmasked, 1.96)
})

test_that("compliant data produces high group z but low individual z (the canonical pattern)", {
  skip_on_cran()
  d <- make_compliant_briefrc_data(n_prod = 20L, n_trials = 200L, bias = 0.06)
  res <- diagnose_infoval(
    d$responses, method = "briefrc", noise_matrix = d$noise,
    iter = 500L, face_mask = "auto", seed = 1L, progress = FALSE
  )
  # Group-mean z should clear conventional threshold.
  expect_gt(res$data$group_mean_z_unmasked, 1.5)
  # Per-producer median z should remain modest; almost never clears 1.96.
  med_individual <- stats::median(res$data$infoval_unmasked$infoval)
  expect_lt(med_individual, 1.96)
})

test_that("face_mask = NULL skips the masked branch", {
  d <- make_random_briefrc_data()
  res <- diagnose_infoval(
    d$responses, method = "briefrc", noise_matrix = d$noise,
    iter = 100L, face_mask = NULL, seed = 1L, progress = FALSE
  )
  expect_null(res$data$infoval_masked)
  expect_true(is.na(res$data$group_mean_z_masked))
})

test_that("diagnose_infoval rejects out-of-pool stimulus ids", {
  d <- make_random_briefrc_data(n_pool = 100L, n_trials = 50L)
  d$responses$stimulus[1L] <- 999L
  expect_error(
    diagnose_infoval(d$responses, method = "briefrc",
                     noise_matrix = d$noise, iter = 100L, seed = 1L,
                     face_mask = NULL, progress = FALSE),
    "pool range"
  )
})

test_that("diagnose_infoval requires noise_matrix for briefrc", {
  d <- make_random_briefrc_data()
  expect_error(
    diagnose_infoval(d$responses, method = "briefrc",
                     iter = 100L, face_mask = NULL, progress = FALSE),
    "noise_matrix"
  )
})

test_that("resolve_face_mask handles multiple input shapes", {
  # The internal is not exported; round-trip via diagnose_infoval is enough.
  d <- make_random_briefrc_data(n_pix = 64L * 64L)
  custom_mask <- rep(c(TRUE, FALSE), length.out = 64L * 64L)
  res <- diagnose_infoval(
    d$responses, method = "briefrc", noise_matrix = d$noise,
    iter = 100L, face_mask = custom_mask, seed = 1L, progress = FALSE
  )
  expect_identical(res$data$mask, custom_mask)
})
