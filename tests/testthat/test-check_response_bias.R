test_that("passes on balanced binary responses", {
  set.seed(1)
  df <- data.frame(
    participant_id = rep(1:5, each = 100),
    stimulus       = rep(1:100, 5),
    response       = sample(c(-1, 1), 500, replace = TRUE)
  )
  r <- check_response_bias(df)
  expect_equal(r$status, "pass")
})

test_that("fails when a participant gives the same response every trial", {
  set.seed(1)
  df <- data.frame(
    participant_id = rep(1:5, each = 100),
    stimulus       = rep(1:100, 5),
    response       = c(
      sample(c(-1, 1), 100, replace = TRUE),
      sample(c(-1, 1), 100, replace = TRUE),
      rep(1, 100),
      sample(c(-1, 1), 100, replace = TRUE),
      sample(c(-1, 1), 100, replace = TRUE)
    )
  )
  r <- check_response_bias(df)
  expect_equal(r$status, "fail")
  expect_equal(sum(r$data$per_participant$constant), 1L)
})

test_that("warns on a mean-outlier participant who is not fully constant", {
  set.seed(1)
  outlier_responses <- c(rep(1, 95), rep(-1, 5))
  df <- data.frame(
    participant_id = rep(1:5, each = 100),
    stimulus       = rep(1:100, 5),
    response       = c(
      sample(c(-1, 1), 100, replace = TRUE),
      sample(c(-1, 1), 100, replace = TRUE),
      sample(c(-1, 1), 100, replace = TRUE),
      sample(c(-1, 1), 100, replace = TRUE),
      outlier_responses
    )
  )
  r <- check_response_bias(df)
  expect_equal(r$status, "warn")
})

test_that("aborts on missing column", {
  expect_error(check_response_bias(data.frame(foo = 1)), "Missing column")
})
