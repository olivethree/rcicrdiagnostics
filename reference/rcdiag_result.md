# Construct an `rcdiag_result` object

Every diagnostic function in the package returns an object of class
`"rcdiag_result"`. This constructor is the single source of truth for
the result shape.

## Usage

``` r
rcdiag_result(status, label, detail, data = list())
```

## Arguments

- status:

  One of `"pass"`, `"warn"`, `"fail"`, or `"skip"`.

- label:

  Short (one-line) description of the check.

- detail:

  Human-readable explanation of the result. Multiple lines allowed.

- data:

  Optional list of supporting data (data frames, flagged participant
  ids, summary statistics). Defaults to an empty list.

## Value

An object of class `"rcdiag_result"`: a list with elements `status`,
`label`, `detail`, and `data`.

## Examples

``` r
rcdiag_result("pass", "Response coding", "All responses coded {-1, 1}.")
#> [PASS] Response coding
#>   All responses coded {-1, 1}.
```
