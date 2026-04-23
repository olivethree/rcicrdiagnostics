# Check that response values use the expected coding

For the 2IFC pipeline, responses must be coded as `{-1, 1}`. Common
miscodings (`{0, 1}` or `{1, 2}`) produce classification images that
look plausible but are shifted or inverted. This check detects the
common miscodings explicitly and returns a status with a fix suggestion.

## Usage

``` r
check_response_coding(
  responses,
  method = c("2ifc", "briefrc"),
  col_response = "response",
  ...
)
```

## Arguments

- responses:

  A data frame of trial-level responses.

- method:

  Either `"2ifc"` or `"briefrc"`.

- col_response:

  Name of the column holding response values. Defaults to `"response"`.

- ...:

  Unused. Reserved for consistency with other check functions.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
object.

## Details

For the Brief-RC pipeline, responses may be binary `{-1, 1}` or
continuous weights. Anything numeric and finite is accepted.

## Examples

``` r
responses <- data.frame(
  participant_id = rep(1, 10),
  stimulus       = 1:10,
  response       = sample(c(-1, 1), 10, replace = TRUE)
)
check_response_coding(responses, method = "2ifc")
#> [PASS] Response coding
#>   All 10 responses coded as {-1, 1}.
```
