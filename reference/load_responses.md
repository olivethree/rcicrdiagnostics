# Load reverse correlation response data from a CSV file

Reads a trial-level response CSV and returns a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html).
The function validates that the required columns are present, but does
not coerce column types or change column names.

## Usage

``` r
load_responses(
  path,
  method = c("2ifc", "briefrc"),
  col_participant = "participant_id",
  col_stimulus = "stimulus",
  col_response = "response",
  col_rt = NULL
)
```

## Arguments

- path:

  Path to a CSV file.

- method:

  Either `"2ifc"` or `"briefrc"`. Currently informational only;
  downstream checks use this to select method-specific logic.

- col_participant, col_stimulus, col_response:

  Column names that must exist in the file. Default to the package-wide
  standard names.

- col_rt:

  Optional column name for response time. If provided, must exist in the
  file.

## Value

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with all columns from the CSV.

## Examples

``` r
if (FALSE) { # \dontrun{
responses <- load_responses("my_data.csv", method = "2ifc")
} # }
```
