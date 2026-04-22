test_that("read_noise_matrix round-trips a small matrix", {
  tmp <- withr::local_tempfile(fileext = ".txt")
  set.seed(1)
  original <- matrix(rnorm(50), nrow = 10, ncol = 5)
  utils::write.table(
    original, tmp,
    row.names = FALSE, col.names = FALSE
  )
  mat <- read_noise_matrix(tmp, header = FALSE)
  expect_equal(dim(mat), c(10L, 5L))
  expect_equal(mat, original, ignore_attr = TRUE)
})

test_that("validate_noise_matrix passes clean data", {
  mat <- matrix(rnorm(100), nrow = 20, ncol = 5)
  r <- validate_noise_matrix(mat)
  expect_equal(r$status, "pass")
})

test_that("validate_noise_matrix fails on wrong dimensions", {
  mat <- matrix(rnorm(100), nrow = 20, ncol = 5)
  r <- validate_noise_matrix(mat, expected_pixels = 16384)
  expect_equal(r$status, "fail")
})

test_that("validate_noise_matrix fails on non-finite entries", {
  mat <- matrix(c(rnorm(99), NA), nrow = 20, ncol = 5)
  r <- validate_noise_matrix(mat)
  expect_equal(r$status, "fail")
})

test_that("validate_noise_matrix fails on non-matrix input", {
  r <- validate_noise_matrix(1:10)
  expect_equal(r$status, "fail")
})
