# rcicrdiagnostics 0.2.0

## New features

* New `diagnose_infoval()`: a guided six-step diagnostic for low or
  negative individual infoVal scores. Simulates a per-trial-count
  reference, runs a random-responder calibration check, computes
  per-producer and group-mean z (unmasked and optionally masked),
  tallies the per-producer distribution, and emits interpretation
  bullets. Supports both 2IFC and Brief-RC paradigms natively.
* New `infoval()`: per-producer informational value with a reference
  distribution keyed on each producer's actual trial count, closing
  the pool-size calibration gap in the original
  `rcicr::computeInfoVal2IFC()` for Brief-RC. Embeds the
  sampling-without-replacement fix from rcicrely v0.2.1. Exposes a
  `with_replacement` argument (`"auto"` / `TRUE` / `FALSE`) for
  controlling the across-trials reference sampling regime.
* New `face_mask()`: parametric oval face-region masks with five
  sub-region variants (eyes, nose, mouth, upper, lower). Default
  geometry follows Schmitz, Rougier, & Yzerbyt (2024).
* New `load_face_mask()`: reads PNG / JPEG mask images for users
  with hand-painted or webmorphR-produced masks.
* `run_diagnostics()` gains `face_mask` and `with_replacement`
  arguments and runs `diagnose_infoval()` automatically when
  `infoval_iter` is supplied with the relevant noise source.
* Brief-RC infoVal is now fully supported through `diagnose_infoval()`
  and the in-package `infoval()`. No `rcicr` install needed for
  Brief-RC; the path uses an in-package implementation of Schmitz's
  `genMask()` algebra.

## Behavior changes

* `compute_infoval_summary()` no longer fails on a per-participant
  headcount of `z >= 1.96`. Status now returns `pass` when the median
  individual z is positive, `warn` otherwise. Per the published
  record (Brinkman 2019: median 3-4 on 2IFC gender; Schmitz 2024:
  Brief-RC systematically below 1.96), individual infoVal magnitudes
  are paradigm- and target-dependent, so a fail status from a
  headcount alone misclassifies many compliant studies.
* The `data$per_participant$meaningful` column produced by
  `compute_infoval_summary()` is renamed to `above_threshold`. Code
  that reads the old column name will break and needs the rename.

## Bug fixes

* `build_inputs_2ifc()` (called from `diagnose_infoval(method = "2ifc")`)
  previously expected a `stimuli` 3D array inside the rcicr `.RData`,
  which does not exist. The 2IFC path now reconstructs per-trial
  noise patterns from `stimuli_params` and `p` via
  `rcicr::generateNoiseImage()`. The 2IFC `diagnose_infoval()` path
  was non-functional before this release.

## Documentation

* Major vignette overhaul. Section 3 expanded into a full
  data-preparation reference (input format, example datasets for
  both pipelines, plain-language description of every object inside
  the rcicr `.RData`, noise matrix specification, base-image
  preparation pipeline via webmorphR, three ways to obtain
  face-region masks). New section 3.4.1 covers Brief-RC sampling
  regimes (without/with replacement) and their downstream effects.
  Section 6.9.1 rewritten with sourced empirical baselines from
  Brinkman 2019 and Schmitz 2024 replacing previously unsourced
  framing. New section 6.9.2 walks through `diagnose_infoval()`.

## Internal

* Adds `jpeg` and `png` to Suggests for the optional
  `load_face_mask()` PNG/JPEG path. No new hard dependencies.

# rcicrdiagnostics 0.1.0

* Initial tagged release. See README.md for the full overview.
