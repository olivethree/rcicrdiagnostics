# 03_run_diagnostics_demo.R --------------------------------------------------
# Load the generated bogus datasets and run the diagnostic battery for each
# pipeline. Assumes 01_generate_stimuli.R and 02a/b/c_*.R have already been
# sourced (they all write into OUTPUT_DIR).

if (!exists("OUTPUT_DIR")) {
  OUTPUT_DIR <- file.path(tempdir(), "rcicrdiagnostics-examples")
}

if (!requireNamespace("rcicrdiagnostics", quietly = TRUE)) {
  stop("Please install rcicrdiagnostics first.")
}

# ---- 2IFC ------------------------------------------------------------------

message("\n==========  2IFC  ==========")
responses_2ifc <- utils::read.csv(
  file.path(OUTPUT_DIR, "responses_2ifc.csv")
)
rdata_2ifc <- file.path(OUTPUT_DIR, "rcicr_2ifc_stimuli.RData")

report_2ifc <- rcicrdiagnostics::run_diagnostics(
  responses_2ifc,
  method = "2ifc",
  rdata  = rdata_2ifc,
  col_rt = "rt"
)
print(report_2ifc)

# ---- Brief-RC 12 -----------------------------------------------------------

message("\n==========  Brief-RC 12  ==========")
responses_12 <- utils::read.csv(
  file.path(OUTPUT_DIR, "responses_briefrc12.csv")
)
noise_matrix <- file.path(OUTPUT_DIR, "noise_matrix_briefrc.txt")

report_12 <- rcicrdiagnostics::run_diagnostics(
  responses_12,
  method       = "briefrc",
  noise_matrix = noise_matrix,
  col_rt       = "rt"
)
print(report_12)

# ---- Brief-RC 20 -----------------------------------------------------------

message("\n==========  Brief-RC 20  ==========")
responses_20 <- utils::read.csv(
  file.path(OUTPUT_DIR, "responses_briefrc20.csv")
)

report_20 <- rcicrdiagnostics::run_diagnostics(
  responses_20,
  method       = "briefrc",
  noise_matrix = noise_matrix,
  col_rt       = "rt"
)
print(report_20)

message("\nDone. Compare the reports against the truth tables in ", OUTPUT_DIR)
