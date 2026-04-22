# Generate bogus Brief-RC 12-alternative response data for the diagnostics.
#
# Design (matches CLAUDE.md spec)
#   30 participants across three trial-count conditions (10 each): 300 / 500 / 1000
#   Stimulus pool: 300 (matches 01_generate_noise.R)
#   12 noisy faces presented per trial, participant picks one.
#
# Row format (expanded — one row per stimulus shown per trial)
#   participant_id, trial, stimulus, response, rt
#   For an honest trial: the chosen stimulus has response = 1, each of the
#   other 11 has response = -1/11. Per-trial response sum is 0.
#
# Archetypes
#   20 x signal     picks uniformly at random from the 12 shown
#    6 x biased     picks a fixed favourite stimulus when it happens to be shown,
#                   otherwise uniform random
#    2 x constant   every row has response = 1 (corrupt data) — triggers fail
#    2 x inverted   picks the last shown instead of a random one
#
# Outputs (data-raw/generated/)
#   responses_briefrc12.csv        # participant_id, trial, stimulus, response, rt
#   participants_briefrc12.csv     # participant_id, trial_count, archetype
#
# Usage
#   setwd("<repo root>")
#   source("data-raw/02_generate_bogus_briefrc12.R")

# ---- configuration --------------------------------------------------------

out_dir        <- "data-raw/generated"
n_stim         <- 300L
n_alternatives <- 12L

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

pick_choice <- function(shown, archetype, favourite) {
  switch(
    archetype,
    signal   = sample(shown, 1L),
    biased   = if (favourite %in% shown) favourite else sample(shown, 1L),
    constant = sample(shown, 1L),  # choice does not matter; see override below
    inverted = shown[length(shown)]
  )
}

trial_rt <- function() {
  if (runif(1) < 0.05) {
    runif(1, 200, 400)
  } else {
    exp(rnorm(1, mean = 6.7, sd = 0.4)) + 100
  }
}

# ---- main -----------------------------------------------------------------

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
set.seed(22L)

participant_ids <- sprintf("P%02d", seq_len(n_participants))
favourites      <- sample.int(n_stim, n_participants, replace = TRUE)

# Pre-allocate per participant (12 rows per trial x trial_counts[i]).
rows <- vector("list", n_participants)
for (i in seq_len(n_participants)) {
  nt <- trial_counts[i]
  total <- nt * n_alternatives

  pid_col      <- rep(participant_ids[i], total)
  trial_col    <- rep(seq_len(nt), each = n_alternatives)
  stim_col     <- integer(total)
  response_col <- numeric(total)
  rt_col       <- numeric(total)

  for (t in seq_len(nt)) {
    shown  <- sample.int(n_stim, n_alternatives)
    chosen <- pick_choice(shown, archetype[i], favourites[i])
    rt     <- trial_rt()
    idx    <- ((t - 1L) * n_alternatives + 1L):(t * n_alternatives)
    stim_col[idx]     <- shown
    response_col[idx] <- ifelse(shown == chosen, 1, -1 / (n_alternatives - 1))
    rt_col[idx]       <- rt
  }

  if (archetype[i] == "constant") response_col <- rep(1, total)

  rows[[i]] <- data.frame(
    participant_id = pid_col,
    trial          = trial_col,
    stimulus       = stim_col,
    response       = response_col,
    rt             = round(rt_col, 1)
  )
}
responses <- do.call(rbind, rows)

participants <- data.frame(
  participant_id = participant_ids,
  trial_count    = trial_counts,
  archetype      = archetype,
  favourite      = favourites
)

# ---- write ----------------------------------------------------------------

resp_path <- file.path(out_dir, "responses_briefrc12.csv")
part_path <- file.path(out_dir, "participants_briefrc12.csv")

data.table::fwrite(responses,    resp_path)
data.table::fwrite(participants, part_path)

cat(sprintf(
  "Brief-RC 12 responses: %d rows, %d participants, %d trials -> %s\n",
  nrow(responses), n_participants, sum(trial_counts), resp_path
))
cat("Truth table -> ", part_path, "\n", sep = "")
