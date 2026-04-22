make_rdata <- function(path, version = "0.4.0") {
  generator_version <- version
  n_trials <- 100
  save(generator_version, n_trials, file = path)
}

test_that("matching versions pass", {
  skip_if_not_installed("rcicr")
  tmp <- withr::local_tempfile(fileext = ".RData")
  inst <- as.character(utils::packageVersion("rcicr"))
  make_rdata(tmp, version = inst)
  r <- check_version_compat(tmp)
  expect_equal(r$status, "pass")
})

test_that("mismatched versions warn", {
  skip_if_not_installed("rcicr")
  tmp <- withr::local_tempfile(fileext = ".RData")
  make_rdata(tmp, version = "0.0.1-fake-old-version")
  r <- check_version_compat(tmp)
  expect_equal(r$status, "warn")
})

test_that("missing generator_version warns", {
  tmp <- withr::local_tempfile(fileext = ".RData")
  x <- 1
  save(x, file = tmp)
  r <- check_version_compat(tmp)
  expect_equal(r$status, "warn")
  expect_true(any(grepl("does not store", r$detail)))
})
