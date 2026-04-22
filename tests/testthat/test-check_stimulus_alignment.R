test_that("briefRC: valid stimulus range passes", {
  mat <- matrix(rnorm(100), nrow = 20, ncol = 5)
  df <- data.frame(
    participant_id = rep(1:2, each = 20),
    stimulus       = sample.int(5, 40, replace = TRUE),
    response       = 1L
  )
  r <- check_stimulus_alignment(df, method = "briefrc", noise_matrix = mat)
  expect_equal(r$status, "pass")
})

test_that("briefRC: out-of-range stimulus fails", {
  mat <- matrix(rnorm(100), nrow = 20, ncol = 5)
  df <- data.frame(
    participant_id = 1:3,
    stimulus       = c(2L, 10L, 42L),   # 10 and 42 exceed pool of 5
    response       = 1L
  )
  r <- check_stimulus_alignment(df, method = "briefrc", noise_matrix = mat)
  expect_equal(r$status, "fail")
  expect_equal(length(r$data$out_of_range), 2L)
})

test_that("briefRC: more than 50% unused warns", {
  mat <- matrix(rnorm(20 * 10), nrow = 20, ncol = 10)
  df <- data.frame(
    participant_id = 1:3,
    stimulus       = c(1L, 2L, 3L),
    response       = 1L
  )
  r <- check_stimulus_alignment(df, method = "briefrc", noise_matrix = mat)
  expect_equal(r$status, "warn")
})

test_that("2IFC: aborts when rdata not supplied", {
  df <- data.frame(participant_id = 1, stimulus = 1, response = 1)
  expect_error(
    check_stimulus_alignment(df, method = "2ifc"),
    "required"
  )
})

test_that("briefRC: aborts when noise_matrix not supplied", {
  df <- data.frame(participant_id = 1, stimulus = 1, response = 1)
  expect_error(
    check_stimulus_alignment(df, method = "briefrc"),
    "required"
  )
})
