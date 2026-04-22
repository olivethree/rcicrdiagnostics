make_df <- function(rts_per_p) {
  ids <- rep(seq_along(rts_per_p), times = vapply(rts_per_p, length, 0L))
  rts <- unlist(rts_per_p)
  data.frame(
    participant_id = ids,
    stimulus       = seq_along(ids),
    response       = 1L,
    rt             = rts
  )
}

test_that("clean data passes", {
  set.seed(1)
  df <- make_df(list(
    exp(rnorm(100, 6.7, 0.4)) + 200,
    exp(rnorm(100, 6.7, 0.4)) + 200,
    exp(rnorm(100, 6.7, 0.4)) + 200
  ))
  r <- check_rt(df)
  expect_equal(r$status, "pass")
})

test_that("fast responders warn", {
  set.seed(1)
  fast_participant <- c(rep(150, 10), exp(rnorm(90, 6.7, 0.4)) + 200)
  df <- make_df(list(
    exp(rnorm(100, 6.7, 0.4)) + 200,
    fast_participant
  ))
  r <- check_rt(df)
  expect_equal(r$status, "warn")
  expect_true(any(r$data$per_participant$is_too_fast))
})

test_that("severe fast responders fail", {
  set.seed(1)
  severe <- c(rep(150, 30), exp(rnorm(70, 6.7, 0.4)) + 200)
  df <- make_df(list(
    exp(rnorm(100, 6.7, 0.4)) + 200,
    severe
  ))
  r <- check_rt(df)
  expect_equal(r$status, "fail")
})

test_that("low CV (constant RT) warns", {
  set.seed(1)
  df <- make_df(list(
    exp(rnorm(100, 6.7, 0.4)) + 200,
    rep(800, 100)   # constant RT
  ))
  r <- check_rt(df)
  expect_equal(r$status, "warn")
  expect_true(any(r$data$per_participant$is_low_var))
})

test_that("aborts when col_rt is NULL", {
  df <- make_df(list(runif(10, 500, 1000)))
  expect_error(check_rt(df, col_rt = NULL), "required")
})
