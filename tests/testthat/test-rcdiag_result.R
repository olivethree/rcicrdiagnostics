test_that("rcdiag_result builds with required fields", {
  r <- rcdiag_result("pass", "Label", "All good.")
  expect_s3_class(r, "rcdiag_result")
  expect_equal(r$status, "pass")
  expect_equal(r$label, "Label")
  expect_equal(r$detail, "All good.")
  expect_equal(r$data, list())
})

test_that("rcdiag_result rejects invalid status", {
  expect_error(rcdiag_result("bad", "x", "y"), "one of")
})

test_that("is_rcdiag_result works", {
  expect_true(is_rcdiag_result(rcdiag_result("pass", "x", "y")))
  expect_false(is_rcdiag_result(list(status = "pass")))
  expect_false(is_rcdiag_result(NULL))
})

test_that("print method runs without error for every status", {
  for (s in c("pass", "warn", "fail", "skip")) {
    r <- rcdiag_result(s, "Label", "Detail line.")
    expect_output(print(r), "Label")
  }
})
