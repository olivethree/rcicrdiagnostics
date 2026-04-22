# Generate bogus 2IFC example data for rcicrdiagnostics.
#
# STATUS: stub. Spec is in CLAUDE.md section "Bogus Data Generation".
#
# Target outputs under inst/extdata/:
#   - example_2ifc_responses.csv   (participant_id, stimulus, response, rt)
#   - example_rcicr_stimuli.RData  (from rcicr::generateStimuli2IFC)
#   - example_base_face_256.png
#
# Requirements:
#   - 30 participants, 3 trial-count conditions (300 / 500 / 1000, 10 each).
#   - Image size: 256 x 256.
#   - Response coding {-1, 1} with archetypes: 70% signal, 20% random, 10% inverted.
#   - RT: shifted lognormal, median ~800ms; a tail of fast responders under 300ms.
#   - Runnable end-to-end via source(); under 2 minutes wall-clock.
#
# This script requires the rcicr package (GitHub: rdotsch/rcicr, ref=development)
# to produce a matching .RData file via rcicr::generateStimuli2IFC().

stop(
  "generate_example_2ifc.R is not yet implemented. ",
  "See CLAUDE.md for the full specification."
)
