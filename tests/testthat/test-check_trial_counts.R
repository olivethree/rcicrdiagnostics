make_responses <- function(counts_per_p) {
  participants <- rep(seq_along(counts_per_p), times = counts_per_p)
  data.frame(
    participant_id = participants,
    stimulus = seq_along(participants),
    response = 1L
  )
}

test_that("passes with no expected_n", {
  r <- check_trial_counts(make_responses(c(300, 300, 300)))
  expect_equal(r$status, "pass")
})

test_that("passes when all match expected_n", {
  r <- check_trial_counts(make_responses(c(300, 300, 300)), expected_n = 300)
  expect_equal(r$status, "pass")
})

test_that("passes when all match a vector of allowed counts", {
  r <- check_trial_counts(
    make_responses(c(300, 500, 1000)),
    expected_n = c(300, 500, 1000)
  )
  expect_equal(r$status, "pass")
})

test_that("warns when a small fraction has unexpected counts", {
  r <- check_trial_counts(
    make_responses(c(300, 300, 300, 300, 300, 300, 300, 300, 300, 250)),
    expected_n = 300
  )
  expect_equal(r$status, "warn")
  expect_equal(nrow(r$data$flagged), 1L)
})

test_that("fails when more than 10% have unexpected counts", {
  r <- check_trial_counts(
    make_responses(c(300, 300, 300, 250, 250)),
    expected_n = 300
  )
  expect_equal(r$status, "fail")
})

test_that("aborts on missing column", {
  expect_error(
    check_trial_counts(data.frame(foo = 1)),
    "not found"
  )
})
