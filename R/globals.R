utils::globalVariables(c(".N", ".SD", "n"))

# Tell data.table this package uses its NSE (.N, .SD, etc.). Without this,
# data.table's [.data.table method falls back to [.data.frame and NSE tokens
# like .N look up as regular variables and error at runtime.
# Reference: ?data.table::cedta
.datatable.aware <- TRUE
