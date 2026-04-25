# End-to-end infoval sweep against the real 2IFC bogus dataset in
# data-raw/generated/. These tests are skipped when rcicr is not
# installed or when the generated assets have not been produced yet.

skip_if_no_rcicr_assets <- function() {
  skip_if_not_installed("rcicr")
  skip_if_not_installed("tibble")
  skip_if_not_installed("dplyr")
  skip_if_not_installed("foreach")
  rdata_path <- "../../data-raw/generated/rcicr_2ifc_stimuli.RData"
  resp_path  <- "../../data-raw/generated/responses_2ifc.csv"
  if (!file.exists(rdata_path) || !file.exists(resp_path)) {
    testthat::skip(
      "data-raw/generated/ not populated; run 01_generate_noise.R first"
    )
  }
  list(rdata = normalizePath(rdata_path), resp = normalizePath(resp_path))
}

test_that("compute_infoval_summary returns a tidy per-participant data frame", {
  paths <- skip_if_no_rcicr_assets()
  skip_on_ci()
  resp <- data.table::fread(paths$resp)
  # Use a small participant subset to keep the test fast
  sub <- as.data.frame(resp[resp$participant_id %in% c("P01", "P02", "P27"), ])

  result <- compute_infoval_summary(
    sub, method = "2ifc", rdata = paths$rdata, baseimage = "base",
    iter = 1000L
  )
  expect_s3_class(result, "rcdiag_result")
  expect_true(nrow(result$data$per_participant) == 3L)
  expect_true(all(c("participant_id", "infoval", "above_threshold")
                  %in% names(result$data$per_participant)))
})

test_that("compute_infoval_summary errors cleanly when rcicr is absent", {
  skip_if(requireNamespace("rcicr", quietly = TRUE))
  df <- data.frame(
    participant_id = 1, stimulus = 1, response = 1
  )
  expect_error(
    compute_infoval_summary(df, method = "2ifc", rdata = tempfile()),
    "rcicr"
  )
})
