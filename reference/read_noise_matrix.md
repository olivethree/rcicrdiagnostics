# Read a Brief-RC noise matrix text file

Reads a space-delimited text file where each column is one stimulus and
each row is one pixel. For 128x128 images this produces a 16384-row
matrix; for 256x256 it produces a 65536-row matrix. Uses
[`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html)
for speed.

## Usage

``` r
read_noise_matrix(path, header = FALSE)
```

## Arguments

- path:

  Path to a space-delimited text file of floats.

- header:

  Logical. Does the file have a header row? Defaults to `FALSE`,
  matching the Schmitz et al. (2024) convention.

## Value

A numeric matrix with `n_pixels` rows and `n_stimuli` columns.

## Examples

``` r
if (FALSE) { # \dontrun{
mat <- read_noise_matrix("noise_matrix_128.txt")
dim(mat)
} # }
```
