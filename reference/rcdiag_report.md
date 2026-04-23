# Construct an `rcdiag_report` object

An `rcdiag_report` collects the outputs of multiple diagnostic checks
into a single printable summary, together with the method that was run
and the names of checks that were skipped because they are not yet
implemented.

## Usage

``` r
rcdiag_report(
  results,
  skipped_checks = character(),
  method = c("2ifc", "briefrc")
)
```

## Arguments

- results:

  A named list of
  [`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
  objects.

- skipped_checks:

  Character vector of check names that were not executed. Defaults to an
  empty vector.

- method:

  Either `"2ifc"` or `"briefrc"`.

## Value

An object of class `"rcdiag_report"`.

## Examples

``` r
r <- rcdiag_report(
  results = list(
    a = rcdiag_result("pass", "Check A", "Looks fine.")
  ),
  method = "2ifc"
)
print(r)
#> == Data-quality report (2ifc) ==
#> 
#> [PASS] Check A
#>   Looks fine.
#> 
#> Summary: pass=1, warn=0, fail=0, skip=0
```
