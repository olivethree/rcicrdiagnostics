test_that("face_mask returns a logical vector of the right length", {
  m <- face_mask(c(64L, 64L))
  expect_type(m, "logical")
  expect_length(m, 64L * 64L)
})

test_that("face_mask 'full' covers ~half the image at default geometry", {
  m <- face_mask(c(128L, 128L))
  cov <- mean(m)
  # Default oval has hw=0.35, hh=0.45, area = pi*hw*hh ~= 0.495
  expect_gt(cov, 0.40)
  expect_lt(cov, 0.55)
})

test_that("face_mask sub-regions are subsets of the full oval", {
  full <- face_mask(c(128L, 128L), region = "full")
  for (region in c("eyes", "nose", "mouth", "upper_face", "lower_face")) {
    sub <- face_mask(c(128L, 128L), region = region)
    expect_true(all(sub <= full),
                info = sprintf("region=%s leaks outside full oval", region))
    expect_true(any(sub),
                info = sprintf("region=%s is empty", region))
  }
})

test_that("face_mask accepts a single integer for square images", {
  expect_identical(
    face_mask(64L),
    face_mask(c(64L, 64L))
  )
})

test_that("face_mask rejects bad img_dims", {
  expect_error(face_mask(c(0L, 64L)), "positive")
  expect_error(face_mask(c(64L, 64L, 64L)), "positive")
})
