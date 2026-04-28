# Plot a face mask for visual verification

Renders a face mask so you can confirm it covers the region you intended
before passing it to
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
or
[`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md).
Accepts the same input forms the diagnostics accept: a logical or
numeric vector (column-major, with `img_dims` supplied), a
logical/numeric matrix, or a path to a PNG/JPEG mask file.

## Usage

``` r
plot_face_mask(
  mask,
  img_dims = NULL,
  base_image = NULL,
  alpha = 0.5,
  col = "red",
  threshold = 0.5,
  main = NULL,
  ...
)
```

## Arguments

- mask:

  One of: a logical or numeric vector of length `prod(img_dims)`
  (column-major, as returned by
  [`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md)
  or
  [`load_face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/load_face_mask.md));
  a logical or numeric matrix; or a path to a PNG/JPEG mask file.

- img_dims:

  Integer `c(nrow, ncol)`, or a single integer for a square image.
  Required when `mask` is a vector; ignored otherwise.

- base_image:

  Optional path to a PNG or JPEG base face. When supplied, the mask is
  rendered as a translucent overlay on top.

- alpha:

  Numeric in `[0, 1]`. Overlay opacity. Default `0.5`.

- col:

  Highlight colour for the masked region. Default `"red"`.

- threshold:

  When `mask` is a numeric matrix or image path, pixels strictly above
  this value are treated as inside the mask. Default `0.5`. Ignored for
  logical input.

- main:

  Optional plot title.

- ...:

  Reserved for future use.

## Value

Invisibly returns the resolved logical matrix (`nrow` x `ncol`, top-left
origin).

## Details

If `base_image` is supplied, the mask is drawn as a translucent overlay
on top of the base face — the most useful view for verifying that the
mask aligns with eyes, nose, mouth, etc. The base image must have the
same dimensions as the mask; otherwise the base is dropped with a
warning.

## See also

[`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md),
[`load_face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/load_face_mask.md),
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md).

## Examples

``` r
m <- face_mask(c(128L, 128L), region = "eyes")
plot_face_mask(m, img_dims = c(128L, 128L), main = "eyes region")

```
