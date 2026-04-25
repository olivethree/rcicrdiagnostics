# Load a face mask from a PNG or JPEG image

Reads an image, converts to grayscale, and thresholds to a logical mask.
White-on-black masks (the typical convention) become `TRUE` inside the
face region and `FALSE` outside.

## Usage

``` r
load_face_mask(path, threshold = 0.5, invert = FALSE)
```

## Arguments

- path:

  Path to a PNG or JPEG file. Reading PNG requires the `png` package;
  reading JPEG requires `jpeg` (both Suggests).

- threshold:

  Numeric in `[0, 1]`. Pixels with grayscale value strictly greater than
  this are `TRUE`. Default `0.5`.

- invert:

  If `TRUE`, the mask is inverted (useful for black-on-white masks).
  Default `FALSE`.

## Value

Logical vector of length `prod(img_dims)`, column-major (the convention
[`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md)
also uses).

## Details

Use this when you have a hand-crafted or anatomically tuned mask and
want to feed it to
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
or
[`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md)
via the `mask` argument. For the standard Schmitz 2024 oval,
[`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md)
is faster and adds no dependencies.

## See also

[`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md),
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md).
