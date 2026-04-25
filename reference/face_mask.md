# Oval face-region mask for a square image

Returns a logical vector of length `prod(img_dims)` marking an
elliptical face region (or sub-region) centred on the image. Pass to
[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
(and
[`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md))
via the `mask` argument to restrict both observed and reference
Frobenius norms to the masked region.

## Usage

``` r
face_mask(
  img_dims,
  region = c("full", "eyes", "nose", "mouth", "upper_face", "lower_face"),
  centre = c(0.5, 0.5),
  half_width = 0.35,
  half_height = 0.45
)
```

## Arguments

- img_dims:

  Integer `c(nrow, ncol)`, or a single integer for a square image.

- region:

  Character. One of `"full"` (default), `"eyes"`, `"nose"`, `"mouth"`,
  `"upper_face"`, `"lower_face"`.

- centre:

  Numeric `c(row, col)` in (0, 1) image-fraction coordinates. Default
  `c(0.5, 0.5)`.

- half_width:

  Full-face ellipse horizontal half-axis as a fraction of image width.
  Default `0.35`.

- half_height:

  Full-face ellipse vertical half-axis as a fraction of image height.
  Default `0.45`.

## Value

Logical vector of length `prod(img_dims)`, column-major.

## Details

Five regions are supported:

- `"full"` (default): the full face oval (Schmitz, Rougier, & Yzerbyt
  2024 geometry).

- `"eyes"`: two small ellipses at typical eye positions.

- `"nose"`: a narrow vertical ellipse along the midline.

- `"mouth"`: a wide-and-short ellipse below centre.

- `"upper_face"`, `"lower_face"`: the top and bottom halves of the full
  face oval.

All region geometries are heuristic approximations matched to a typical
centred face on a square base image (e.g., 256x256 KDEF male). For
non-default base images, tune `centre`, `half_width`, and `half_height`;
the sub-region geometries scale relative to that ellipse.

## References

Schmitz, M., Rougier, M., & Yzerbyt, V. (2024). Introducing the brief
reverse correlation: an improved tool to assess visual representations.
*European Journal of Social Psychology*.
[doi:10.1002/ejsp.3100](https://doi.org/10.1002/ejsp.3100)

## See also

[`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md),
[`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md).

## Examples

``` r
full <- face_mask(c(128L, 128L))
mean(full)              # ~0.49 of the image
#> [1] 0.4875488
eyes <- face_mask(c(128L, 128L), region = "eyes")
mean(eyes)              # ~0.02 of the image
#> [1] 0.01538086
```
