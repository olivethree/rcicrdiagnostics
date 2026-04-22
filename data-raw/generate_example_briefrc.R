# Generate bogus Brief-RC example data for rcicrdiagnostics.
#
# STATUS: stub. Spec is in CLAUDE.md section "Bogus Data Generation".
#
# Target outputs under inst/extdata/:
#   - example_briefrc_responses.csv    (participant_id, stimulus, response, rt)
#   - example_noise_matrix_128.txt     (16384 rows x 300 columns, space-delimited)
#   - example_base_face_128.png        (128 x 128 synthetic face-like image)
#   - example_briefrc12_responses.csv  (12-alternative variant)
#   - example_noise_matrix_128_12.txt
#
# Requirements:
#   - 30 participants, 3 trial-count conditions (300 / 500 / 1000, 10 each).
#   - Each trial presents 6 stimuli (briefRC-6) in the primary dataset,
#     12 stimuli (briefRC-12) in the secondary dataset.
#   - Image size: 128 x 128 (noise matrix: 16384 rows).
#   - Noise matrix entries: mean ~0, sd ~0.05.
#   - Response as continuous weights (one-hot-per-trial aggregated across trials).
#   - Participant archetypes: 70% signal, 20% random, 10% inverted.
#   - Runnable end-to-end via source(); under 2 minutes wall-clock.

stop(
  "generate_example_briefrc.R is not yet implemented. ",
  "See CLAUDE.md for the full specification."
)
