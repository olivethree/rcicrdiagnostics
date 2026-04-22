make_responses <- function(vals) {
  data.frame(
    participant_id = seq_along(vals),
    stimulus = seq_along(vals),
    response = vals
  )
}

test_that("2IFC: all {-1, 1} passes", {
  r <- check_response_coding(
    make_responses(rep(c(-1, 1), 50)),
    method = "2ifc"
  )
  expect_equal(r$status, "pass")
})

test_that("2IFC: integer-typed {-1L, 1L} passes (regression test for fread-read data)", {
  r <- check_response_coding(
    make_responses(rep(c(-1L, 1L), 50)),
    method = "2ifc"
  )
  expect_equal(r$status, "pass")
})

test_that("2IFC: integer-typed {0L, 1L} is detected as miscoded", {
  r <- check_response_coding(
    make_responses(rep(c(0L, 1L), 50)),
    method = "2ifc"
  )
  expect_equal(r$status, "warn")
  expect_true(any(grepl("\\{0, 1\\}", r$detail)))
})

test_that("2IFC: {0, 1} miscoding warns with fix suggestion", {
  r <- check_response_coding(
    make_responses(rep(c(0, 1), 50)),
    method = "2ifc"
  )
  expect_equal(r$status, "warn")
  expect_true(any(grepl("\\{0, 1\\}", r$detail)))
  expect_true(any(grepl("Recode", r$detail)))
})

test_that("2IFC: {1, 2} miscoding warns with fix suggestion", {
  r <- check_response_coding(
    make_responses(rep(c(1, 2), 50)),
    method = "2ifc"
  )
  expect_equal(r$status, "warn")
  expect_true(any(grepl("\\{1, 2\\}", r$detail)))
})

test_that("2IFC: unexpected values fail", {
  r <- check_response_coding(
    make_responses(c(-1, 0, 1, 2)),
    method = "2ifc"
  )
  expect_equal(r$status, "fail")
})

test_that("2IFC: non-numeric fails", {
  r <- check_response_coding(
    make_responses(c("a", "b", "a", "b")),
    method = "2ifc"
  )
  expect_equal(r$status, "fail")
})

test_that("briefRC: continuous weights pass", {
  set.seed(1)
  r <- check_response_coding(
    make_responses(rnorm(100)),
    method = "briefrc"
  )
  expect_equal(r$status, "pass")
})

test_that("briefRC: NA values warn", {
  vals <- c(1, NA, -1, 1)
  r <- check_response_coding(
    make_responses(vals),
    method = "briefrc"
  )
  expect_equal(r$status, "warn")
})

test_that("aborts on missing column", {
  df <- data.frame(foo = 1)
  expect_error(check_response_coding(df), "not found")
})
