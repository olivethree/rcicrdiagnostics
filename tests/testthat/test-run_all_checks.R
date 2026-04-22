make_responses <- function(n_p = 3, n_trials = 100) {
  data.frame(
    participant_id = rep(seq_len(n_p), each = n_trials),
    stimulus       = rep(seq_len(n_trials), n_p),
    response       = sample(c(-1, 1), n_p * n_trials, replace = TRUE)
  )
}

test_that("run_all_checks returns an rcdiag_report", {
  r <- run_all_checks(make_responses(), method = "2ifc")
  expect_s3_class(r, "rcdiag_report")
  expect_true(length(r$results) >= 4L)
  expect_true(all(vapply(r$results, is_rcdiag_result, logical(1L))))
})

test_that("run_all_checks auto-detects 2ifc from rdata arg", {
  skip_if_not_installed("withr")
  tmp <- withr::local_tempfile(fileext = ".RData")
  saveRDS(NULL, tmp)
  r <- run_all_checks(make_responses(), rdata = tmp)
  expect_equal(r$method, "2ifc")
})

test_that("run_all_checks requires method if no hint is given", {
  expect_error(run_all_checks(make_responses()), "Cannot auto-detect")
})

test_that("print works without error", {
  r <- run_all_checks(make_responses(), method = "2ifc")
  expect_output(print(r), "Data-quality report")
  expect_output(print(r), "Not yet implemented")
})

test_that("summary returns a data frame", {
  r <- run_all_checks(make_responses(), method = "2ifc")
  s <- summary(r)
  expect_s3_class(s, "data.frame")
  expect_true(all(c("check", "status", "label") %in% names(s)))
})
