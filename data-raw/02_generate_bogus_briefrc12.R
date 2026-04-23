# Generate bogus Brief-RC 12-alternative response data that follows the
# Schmitz, Rougier, & Yzerbyt (2024) convention.
#
# Reference
#   Schmitz, M., Rougier, M., & Yzerbyt, V. (2024). Introducing the brief
#   reverse correlation: An improved tool to assess visual representations.
#   European Journal of Social Psychology. Advance online publication.
#   https://doi.org/10.1002/ejsp.3100
#
# Per-trial structure (from Schmitz et al., p. 6)
#   Each trial presents 12 noisy faces: 6 oriented (base + noise_i) and
#   6 inverted (base - noise_i), drawn from a shared pool of noise patterns.
#   The participant picks exactly one face.
#
# Row format (one row per trial, matching rcicr::genCI conventions)
#   participant_id, trial, stimulus, response, rt
#     stimulus : pool id of the underlying noise pattern of the chosen face
#     response : +1 if the oriented version was chosen, -1 if the inverted
#
# Design
#   30 participants across three trial-count conditions (10 each):
#     300 / 500 / 1000 trials per participant
#   Noise-pattern pool size: 300 (matches 01_generate_noise.R)
#
# Archetypes
#   20 x signal     picks uniformly at random from the 12 shown
#    6 x biased     ~80% chance of preferring the oriented (or inverted)
#                   side regardless of the noise pattern; triggers WARN
#    2 x constant   always picks an oriented face -> response is always +1;
#                   triggers FAIL in check_response_bias
#    2 x inverted   distribution like "signal" but with every response flipped
#
# Outputs (data-raw/generated/)
#   responses_briefrc12.csv        # participant_id, trial, stimulus, response, rt
#   participants_briefrc12.csv     # participant_id, trial_count, archetype,
#                                  # prefer_sign (for biased archetype)
#
# Usage
#   setwd("<repo root>")
#   source("data-raw/02_generate_bogus_briefrc12.R")

# ---- configuration --------------------------------------------------------

out_dir         <- "data-raw/generated"
n_stim          <- 300L
n_alternatives  <- 12L
n_oriented      <- n_alternatives / 2L
n_inverted      <- n_alternatives - n_oriented

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

# Draw a single trial: 12 distinct noise-pattern ids, half displayed as
# oriented (+1) and half as inverted (-1). Returns a data.frame with
# columns {id, sign}.
sample_shown <- function() {
  ids   <- sample.int(n_stim, n_alternatives)
  signs <- sample(c(rep(1L, n_oriented), rep(-1L, n_inverted)))
  data.frame(id = ids, sign = signs)
}

# Given the 12 shown faces, return the index (1..12) picked by the
# participant under the given archetype.
pick_index <- function(shown, archetype, prefer_sign) {
  n <- nrow(shown)
  switch(
    archetype,
    signal   = sample.int(n, 1L),
    biased   = {
      if (runif(1) < 0.80) {
        matches <- which(shown$sign == prefer_sign)
        if (length(matches) > 0L) sample(matches, 1L) else sample.int(n, 1L)
      } else {
        sample.int(n, 1L)
      }
    },
    constant = which(shown$sign == 1L)[1L],
    inverted = sample.int(n, 1L)
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
# Biased participants: half prefer oriented (+1), half prefer inverted (-1).
prefer_signs <- ifelse(seq_len(n_participants) %% 2L == 0L, 1L, -1L)

rows <- vector("list", n_participants)
for (i in seq_len(n_participants)) {
  nt  <- trial_counts[i]
  pid <- participant_ids[i]
  arc <- archetype[i]
  ps  <- prefer_signs[i]

  stim_col  <- integer(nt)
  resp_col  <- integer(nt)
  rt_col    <- numeric(nt)

  for (t in seq_len(nt)) {
    shown       <- sample_shown()
    chosen_idx  <- pick_index(shown, arc, ps)
    stim_col[t] <- shown$id[chosen_idx]
    resp_col[t] <- shown$sign[chosen_idx]
    rt_col[t]   <- trial_rt()
  }

  if (arc == "inverted") resp_col <- -resp_col

  rows[[i]] <- data.frame(
    participant_id = pid,
    trial          = seq_len(nt),
    stimulus       = stim_col,
    response       = resp_col,
    rt             = round(rt_col, 1)
  )
}
responses <- do.call(rbind, rows)

participants <- data.frame(
  participant_id = participant_ids,
  trial_count    = trial_counts,
  archetype      = archetype,
  prefer_sign    = ifelse(archetype == "biased", prefer_signs, NA_integer_)
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
