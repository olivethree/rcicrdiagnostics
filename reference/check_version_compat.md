# Check rcicr version compatibility with a 2IFC rdata file

The `.RData` produced by
[`rcicr::generateStimuli2IFC()`](https://rdrr.io/pkg/rcicr/man/generateStimuli2IFC.html)
stores a `generator_version` field. When a different rcicr version is
used later to reconstruct CIs from that rdata, subtle numerical or API
changes may produce wrong results silently. This check compares the
generator version against the installed rcicr version and warns on
mismatch.

## Usage

``` r
check_version_compat(rdata, ...)
```

## Arguments

- rdata:

  Path to the 2IFC `.RData` file.

- ...:

  Unused.

## Value

An
[`rcdiag_result()`](https://olivethree.github.io/rcicrdiagnostics/reference/rcdiag_result.md)
object. `data` contains `generator_version` and `installed_version`.

## Details

Only applicable to the 2IFC pipeline; Brief-RC does not use a generated
`.RData` file.

## Examples

``` r
if (FALSE) { # \dontrun{
check_version_compat("stimuli.RData")
} # }
```
