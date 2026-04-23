# 02b_bogus_responses_briefrc12.R -------------------------------------------
# Generate a synthetic Brief-RC 12-alternative response dataset following the
# convention of Schmitz, Rougier, & Yzerbyt (2024, EJSP).
#
# Per-trial structure: 12 noisy faces are shown (6 oriented + 6 inverted,
# drawn from the same noise pool). The participant picks one. The row
# records the pool id of the chosen face and whether the chosen face
# was oriented (+1) or inverted (-1).
#
# Outputs (written to OUTPUT_DIR):
#   responses_briefrc12.csv       # participant_id, trial, stimulus, response, rt
#   participants_briefrc12.csv    # truth table incl. prefer_sign for biased

if (!exists("OUTPUT_DIR")) {
  OUTPUT_DIR <- file.path(tempdir(), "rcicrdiagnostics-examples")
}
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- design ----------------------------------------------------------------

n_stim         <- 300L
n_alternatives <- 12L
n_oriented     <- n_alternatives / 2L
n_inverted     <- n_alternatives - n_oriented

trial_counts <- c(rep(300L, 10), rep(500L, 10), rep(1000L, 10))
archetype    <- c(
  rep("signal",   20),
  rep("biased",    6),
  rep("constant",  2),
  rep("inverted",  2)
)
stopifnot(length(trial_counts) == length(archetype))
n_participants <- length(trial_counts)

# ---- helpers ---------------------------------------------------------------

sample_shown <- function() {
  ids   <- sample.int(n_stim, n_alternatives)
  signs <- sample(c(rep(1L, n_oriented), rep(-1L, n_inverted)))
  data.frame(id = ids, sign = signs)
}

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
  if (runif(1) < 0.05) runif(1, 200, 400)
  else                 exp(rnorm(1, mean = 6.7, sd = 0.4)) + 100
}

# ---- generate --------------------------------------------------------------

set.seed(22L)
participant_ids <- sprintf("P%02d", seq_len(n_participants))
prefer_signs    <- ifelse(seq_len(n_participants) %% 2L == 0L, 1L, -1L)

rows <- vector("list", n_participants)
for (i in seq_len(n_participants)) {
  nt  <- trial_counts[i]
  pid <- participant_ids[i]
  arc <- archetype[i]
  ps  <- prefer_signs[i]

  stim_col <- integer(nt)
  resp_col <- integer(nt)
  rt_col   <- numeric(nt)

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

# ---- write -----------------------------------------------------------------

if (!requireNamespace("data.table", quietly = TRUE)) {
  stop("Please install 'data.table'.")
}
resp_path <- file.path(OUTPUT_DIR, "responses_briefrc12.csv")
part_path <- file.path(OUTPUT_DIR, "participants_briefrc12.csv")
data.table::fwrite(responses,    resp_path)
data.table::fwrite(participants, part_path)

message(sprintf(
  "Brief-RC 12 responses: %d rows, %d participants, %d trials total -> %s\nTruth table -> %s",
  nrow(responses), n_participants, sum(trial_counts), resp_path, part_path
))
