# 02a_bogus_responses_2ifc.R -------------------------------------------------
# Generate a synthetic 2IFC response dataset that exercises every branch of
# the diagnostic checks (pass / warn / fail).
#
# Outputs (written to OUTPUT_DIR):
#   responses_2ifc.csv       # participant_id, stimulus, response, rt
#   participants_2ifc.csv    # truth table: participant_id, trial_count, archetype

if (!exists("OUTPUT_DIR")) {
  OUTPUT_DIR <- file.path(tempdir(), "rcicrdiagnostics-examples")
}
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- design ----------------------------------------------------------------
# 30 participants across three trial-count conditions.
# Archetypes are chosen so that the diagnostic battery produces
# deterministic pass / warn / fail output.

n_stim       <- 300L
trial_counts <- c(rep(300L, 10), rep(500L, 10), rep(1000L, 10))
archetype    <- c(
  rep("signal",   20),   # p(+1) ~ U(.45, .55)    - should pass
  rep("biased",    6),   # p(+1) ~ U(.80, .95)    - triggers warn
  rep("constant",  2),   # all +1 or all -1       - triggers fail
  rep("inverted",  2)    # signal then sign-flipped
)
stopifnot(length(trial_counts) == length(archetype))
n_participants <- length(trial_counts)

# ---- helpers ---------------------------------------------------------------

make_responses <- function(n, archetype) {
  p_plus <- switch(
    archetype,
    signal   = runif(1, 0.45, 0.55),
    biased   = if (runif(1) < 0.5) runif(1, 0.80, 0.95) else runif(1, 0.05, 0.20),
    constant = if (runif(1) < 0.5) 1.0 else 0.0,
    inverted = runif(1, 0.45, 0.55)
  )
  out <- sample(c(-1L, 1L), n, replace = TRUE, prob = c(1 - p_plus, p_plus))
  if (archetype == "inverted") out <- -out
  out
}

make_rts <- function(n) {
  fast_n   <- round(n * 0.05)
  normal_n <- n - fast_n
  rts <- c(
    runif(fast_n, 200, 400),
    exp(rnorm(normal_n, mean = 6.7, sd = 0.4)) + 100
  )
  sample(rts)
}

# ---- generate --------------------------------------------------------------

set.seed(11L)
rows <- vector("list", n_participants)
for (i in seq_len(n_participants)) {
  nt <- trial_counts[i]
  rows[[i]] <- data.frame(
    participant_id = sprintf("P%02d", i),
    stimulus       = sample.int(n_stim, nt, replace = TRUE),
    response       = make_responses(nt, archetype[i]),
    rt             = round(make_rts(nt), 1)
  )
}
responses <- do.call(rbind, rows)

participants <- data.frame(
  participant_id = sprintf("P%02d", seq_len(n_participants)),
  trial_count    = trial_counts,
  archetype      = archetype
)

# ---- write -----------------------------------------------------------------

if (!requireNamespace("data.table", quietly = TRUE)) {
  stop("Please install 'data.table'.")
}
resp_path <- file.path(OUTPUT_DIR, "responses_2ifc.csv")
part_path <- file.path(OUTPUT_DIR, "participants_2ifc.csv")
data.table::fwrite(responses,    resp_path)
data.table::fwrite(participants, part_path)

message(sprintf(
  "2IFC responses: %d rows, %d participants -> %s\nTruth table -> %s",
  nrow(responses), n_participants, resp_path, part_path
))
