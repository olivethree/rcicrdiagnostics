# Validate a Brief-RC noise matrix

Runs basic sanity checks on a noise matrix: numeric, finite, expected
dimensions. Returns an
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
with status `"pass"`, `"warn"`, or `"fail"` rather than aborting,
because users typically want to see all problems at once, not just the
first.

## Usage

``` r
validate_noise_matrix(mat, expected_pixels = NULL, expected_stimuli = NULL)
```

## Arguments

- mat:

  A numeric matrix, as returned by
  [`read_noise_matrix()`](https://olivethree.github.io/rcicrdiagnostics/reference/read_noise_matrix.md).

- expected_pixels:

  Optional integer. If supplied, checks that
  `nrow(mat) == expected_pixels`. For example, 128\*128 = 16384.

- expected_stimuli:

  Optional integer. If supplied, checks that
  `ncol(mat) == expected_stimuli`.

## Value

An object of class `"rcdiag_result"`.

## Examples

``` r
mat <- matrix(rnorm(16384 * 10, sd = 0.05), nrow = 16384, ncol = 10)
validate_noise_matrix(mat, expected_pixels = 16384, expected_stimuli = 10)
#> [PASS] Noise matrix
#>   16384 pixels x 10 stimuli, all finite. Range: [-0.244, 0.233].
```
