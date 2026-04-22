test_that("passes on clean data", {
  df <- data.frame(
    participant_id = rep(1:3, each = 10),
    stimulus = rep(1:10, 3),
    response = sample(c(-1, 1), 30, replace = TRUE)
  )
  r <- check_duplicates(df)
  expect_equal(r$status, "pass")
})

test_that("warns on a single fully duplicated row", {
  df <- data.frame(
    participant_id = c(1, 1, 2),
    stimulus       = c(1, 1, 2),
    response       = c(1, 1, -1)
  )
  r <- check_duplicates(df)
  expect_equal(r$status, "warn")
  expect_equal(nrow(r$data$full_duplicates), 1L)
})

test_that("warns on (participant, stimulus) pair duplicates with differing response", {
  df <- data.frame(
    participant_id = c(1, 1, 2),
    stimulus       = c(1, 1, 2),
    response       = c(1, -1, -1)
  )
  r <- check_duplicates(df)
  expect_equal(r$status, "warn")
  expect_equal(nrow(r$data$full_duplicates), 0L)
  expect_gt(nrow(r$data$pair_duplicates), 0L)
})

test_that("fails when fully duplicated rows exceed 5%", {
  df <- data.frame(
    participant_id = rep(1, 20),
    stimulus       = c(rep(1:10, 2)),
    response       = rep(1, 20)
  )
  r <- check_duplicates(df)
  expect_equal(r$status, "fail")
})

test_that("aborts on missing column", {
  expect_error(check_duplicates(data.frame(foo = 1)), "Missing column")
})
