test_that("load_responses reads a CSV and validates columns", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  df <- data.frame(
    participant_id = 1:3,
    stimulus = 1:3,
    response = c(-1, 1, -1)
  )
  utils::write.csv(df, tmp, row.names = FALSE)
  out <- load_responses(tmp, method = "2ifc")
  expect_s3_class(out, "data.table")
  expect_equal(nrow(out), 3L)
})

test_that("load_responses errors on missing column", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(pid = 1:3, stim = 1:3, resp = c(-1, 1, -1)),
    tmp, row.names = FALSE
  )
  expect_error(load_responses(tmp), "missing required column")
})

test_that("load_responses errors on missing file", {
  expect_error(
    load_responses("nonexistent_file_12345.csv"),
    "File not found"
  )
})
