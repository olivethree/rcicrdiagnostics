# Generate bogus 2IFC response data for exercising the diagnostic checks.
#
# Design
#   30 participants across three trial-count conditions (10 each): 300 / 500 / 1000
#   Stimulus pool: 300 (matches 01_generate_noise.R)
#   Response coding: {-1, 1}
#
# Archetypes (to exercise pass / warn / fail)
#   20 x signal    p(+1) ~ Uniform(0.45, 0.55) — near balanced
#    6 x biased    p(+1) ~ Uniform(0.80, 0.95) or (0.05, 0.20) — warn
#    2 x constant  responses all +1 or all -1 — fail
#    2 x inverted  signal distribution, then sign-flipped
#
# RT
#   95% of trials: shifted lognormal (median ~820 ms)
#    5% of trials: uniform(200, 400) ms — fast responders
#
# Outputs (data-raw/generated/)
#   responses_2ifc.csv             # participant_id, stimulus, response, rt
#   participants_2ifc.csv          # participant_id, trial_count, archetype (truth table)
#
# Usage
#   setwd("<repo root>")
#   source("data-raw/02_generate_bogus_2ifc.R")

# ---- configuration --------------------------------------------------------

out_dir   <- "data-raw/generated"
n_stim    <- 300L

trial_counts <- c(rep(300L, 10), rep(500L, 10), rep(1000L, 10))
archetype    <- c(
  rep("signal",   20),
  rep("biased",    6),
  rep("constant",  2),
  rep("inverted",  2)
)
stopifnot(length(trial_counts) == length(archetype))
n_participants <- length(trial_counts)

# ---- helpers --------------------------------------------------------------

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
  sample(rts)  # interleave fast and normal trials
}

# ---- main -----------------------------------------------------------------

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
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

# ---- write ----------------------------------------------------------------

resp_path <- file.path(out_dir, "responses_2ifc.csv")
part_path <- file.path(out_dir, "participants_2ifc.csv")

data.table::fwrite(responses,    resp_path)
data.table::fwrite(participants, part_path)

cat(sprintf(
  "2IFC responses: %d rows, %d participants -> %s\n",
  nrow(responses), n_participants, resp_path
))
cat("Truth table (archetype per participant) -> ", part_path, "\n", sep = "")
