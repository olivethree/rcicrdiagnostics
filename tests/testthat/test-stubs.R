test_that("stub functions error informatively", {
  stubs <- list(
    check_response_inversion,
    check_stimulus_alignment,
    check_rt,
    check_version_compat,
    compute_infoval_summary,
    cross_validate_rt_infoval
  )
  for (fn in stubs) {
    expect_error(fn(), "not yet implemented")
  }
})
