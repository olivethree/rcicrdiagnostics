# Tests for the in-package infoval() and supporting machinery. These do not
# require rcicr (Brief-RC path is pure R).

# Build a synthetic Brief-RC random-responder dataset for use across tests.
# n_trials < n_pool with without-replacement sampling matches the
# reference distribution's assumed sampling regime.
make_random_signal <- function(n_pix = 256L, n_pool = 200L,
                               n_trials = 100L, n_prod = 10L,
                               seed = 1L, sd = 0.05) {
  set.seed(seed)
  noise <- matrix(stats::rnorm(n_pix * n_pool, sd = sd), n_pix, n_pool)
  signal <- vapply(seq_len(n_prod), function(j) {
    stim <- sample.int(n_pool, n_trials, replace = FALSE)
    resp <- sample(c(-1, 1), n_trials, replace = TRUE)
    ord  <- order(stim)
    stims_sorted <- stim[ord]
    wts <- resp[ord]
    as.numeric(noise[, stims_sorted, drop = FALSE] %*% wts /
                 length(stims_sorted))
  }, numeric(n_pix))
  colnames(signal) <- sprintf("p%02d", seq_len(n_prod))
  list(signal = signal, noise = noise,
       trial_counts = stats::setNames(rep(n_trials, n_prod), colnames(signal)))
}

test_that("infoval() returns the expected shape", {
  d <- make_random_signal()
  res <- infoval(d$signal, d$noise, d$trial_counts,
                 iter = 200L, seed = 42L, progress = FALSE)
  expect_s3_class(res, "rcdiag_infoval")
  expect_length(res$infoval, ncol(d$signal))
  expect_length(res$norms,   ncol(d$signal))
  expect_named(res$infoval, colnames(d$signal))
  expect_true(all(is.finite(res$infoval)))
})

test_that("infoval() reference is calibrated (random producers near z=0)", {
  # Bigger n to stabilise the median.
  d <- make_random_signal(n_prod = 30L, n_trials = 150L, seed = 7L)
  res <- infoval(d$signal, d$noise, d$trial_counts,
                 iter = 500L, seed = 1L, progress = FALSE)
  med <- stats::median(res$infoval)
  expect_lt(abs(med), 0.7)
})

test_that("infoval() respects a logical mask (norm uses fewer pixels)", {
  d <- make_random_signal(n_pix = 256L)
  mask <- rep(c(TRUE, FALSE), length.out = 256L)
  with_mask <- infoval(d$signal, d$noise, d$trial_counts,
                       iter = 100L, mask = mask, seed = 1L, progress = FALSE)
  no_mask  <- infoval(d$signal, d$noise, d$trial_counts,
                      iter = 100L, mask = NULL, seed = 1L, progress = FALSE)
  # Masked observed norms should be smaller (sum over fewer pixels).
  expect_true(all(with_mask$norms <= no_mask$norms + 1e-9))
})

test_that("infoval() rejects mismatched signal/noise pixel counts", {
  d <- make_random_signal()
  bad_noise <- d$noise[1:50, ]
  expect_error(
    infoval(d$signal, bad_noise, d$trial_counts,
            iter = 100L, progress = FALSE),
    "pixels"
  )
})

test_that("infoval() rejects unnamed trial_counts", {
  d <- make_random_signal()
  unnamed <- unname(d$trial_counts)
  expect_error(
    infoval(d$signal, d$noise, unnamed, iter = 100L, progress = FALSE),
    "named integer vector"
  )
})

test_that("infoval() warns at very low iter", {
  d <- make_random_signal()
  expect_warning(
    infoval(d$signal, d$noise, d$trial_counts,
            iter = 50L, seed = 1L, progress = FALSE),
    "very low"
  )
})

test_that("infoval() respects an explicit with_replacement override", {
  d <- make_random_signal(n_trials = 100L, n_pool = 200L, n_prod = 8L)
  # n_trials < n_pool, so "auto" picks without-replacement. The two
  # resolved regimes (FALSE vs TRUE) must produce different reference
  # norm distributions.
  no_repl <- infoval(d$signal, d$noise, d$trial_counts,
                     iter = 200L, with_replacement = FALSE,
                     seed = 1L, progress = FALSE)
  with_repl <- infoval(d$signal, d$noise, d$trial_counts,
                       iter = 200L, with_replacement = TRUE,
                       seed = 1L, progress = FALSE)
  expect_false(identical(no_repl$reference, with_repl$reference))
})

test_that("infoval() errors when sampling without replacement is impossible", {
  # Construct a tiny signal/noise pair and claim n_trials > n_pool.
  set.seed(1)
  n_pix  <- 64L
  n_pool <- 30L
  signal <- matrix(stats::rnorm(n_pix * 4L), n_pix, 4L,
                   dimnames = list(NULL, paste0("p", 1:4)))
  noise  <- matrix(stats::rnorm(n_pix * n_pool, sd = 0.05), n_pix, n_pool)
  tc <- stats::setNames(rep(60L, 4L), colnames(signal))  # > n_pool
  expect_error(
    infoval(signal, noise, tc,
            iter = 100L, with_replacement = FALSE,
            seed = 1L, progress = FALSE),
    "without replacement"
  )
})

test_that("infoval() rejects a malformed with_replacement value", {
  d <- make_random_signal(n_prod = 4L)
  expect_error(
    infoval(d$signal, d$noise, d$trial_counts,
            iter = 100L, with_replacement = "yes",
            seed = 1L, progress = FALSE),
    "auto"
  )
  expect_error(
    infoval(d$signal, d$noise, d$trial_counts,
            iter = 100L, with_replacement = c(TRUE, FALSE),
            seed = 1L, progress = FALSE),
    "auto"
  )
})
