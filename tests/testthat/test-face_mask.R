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

test_that("plot_face_mask renders for vector + img_dims", {
  m <- face_mask(c(64L, 64L), region = "eyes")
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  expect_silent(out <- plot_face_mask(m, img_dims = c(64L, 64L)))
  expect_true(is.matrix(out))
  expect_true(is.logical(out))
  expect_identical(dim(out), c(64L, 64L))
  expect_equal(sum(out), sum(m))
})

test_that("plot_face_mask accepts a logical matrix directly", {
  mat <- matrix(face_mask(c(48L, 48L)), 48L, 48L)
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  expect_silent(plot_face_mask(mat))
})

test_that("plot_face_mask requires img_dims for vector input", {
  m <- face_mask(c(32L, 32L))
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  expect_error(plot_face_mask(m), "img_dims")
})

test_that("plot_face_mask warns and drops mismatched base_image", {
  m <- face_mask(c(32L, 32L))
  bad_base <- matrix(0.5, 16L, 16L)
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  expect_warning(
    plot_face_mask(m, img_dims = c(32L, 32L), base_image = bad_base),
    "do not match"
  )
})

test_that("plot_face_mask validates alpha", {
  m <- face_mask(c(32L, 32L))
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  expect_error(plot_face_mask(m, img_dims = c(32L, 32L), alpha = 2),
               "alpha")
})
