# Changelog

## rcicrdiagnostics 0.2.1

### Metadata

- Maintainer email updated to institutional address
  (`m.j.barbosa.de.oliveira@tue.nl`).
- ORCID `0000-0002-6220-0695` added to author metadata in `DESCRIPTION`
  and `.zenodo.json`. Affiliation added to `.zenodo.json` (Eindhoven
  University of Technology).

### Documentation

- [`?infoval`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md)
  and vignette §6.9.1 now state explicitly that the reference
  simulator’s uniform 50/50 ±1 response sampling is exact under the
  standard Brief-RC trial structure (equal numbers of oriented and
  inverted faces per trial: 6/6 in Brief-RC 12, 10/10 in Brief-RC 20),
  and call out that designs with unbalanced oriented/inverted splits
  will incur a small calibration drift.
- Wording sweep: “canonical” replaced with more neutral synonyms
  (“original” for upstream-`rcicr` references; “typical”, “standard”, or
  “foundational” elsewhere) across user-facing documentation, NEWS, and
  tests.

## rcicrdiagnostics 0.2.0

### New features

- New
  [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md):
  a guided six-step diagnostic for low or negative individual infoVal
  scores. Simulates a per-trial-count reference, runs a random-responder
  calibration check, computes per-producer and group-mean z (unmasked
  and optionally masked), tallies the per-producer distribution, and
  emits interpretation bullets. Supports both 2IFC and Brief-RC
  paradigms natively.
- New
  [`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md):
  per-producer informational value with a reference distribution keyed
  on each producer’s actual trial count, closing the pool-size
  calibration gap in the original
  [`rcicr::computeInfoVal2IFC()`](https://rdrr.io/pkg/rcicr/man/computeInfoVal2IFC.html)
  for Brief-RC. Embeds the sampling-without-replacement fix from
  rcicrely v0.2.1. Exposes a `with_replacement` argument (`"auto"` /
  `TRUE` / `FALSE`) for controlling the across-trials reference sampling
  regime.
- New
  [`face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/face_mask.md):
  parametric oval face-region masks with five sub-region variants (eyes,
  nose, mouth, upper, lower). Default geometry follows Schmitz, Rougier,
  & Yzerbyt (2024).
- New
  [`load_face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/load_face_mask.md):
  reads PNG / JPEG mask images for users with hand-painted or
  webmorphR-produced masks.
- [`run_diagnostics()`](https://olivethree.github.io/rcicrdiagnostics/reference/run_diagnostics.md)
  gains `face_mask` and `with_replacement` arguments and runs
  [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
  automatically when `infoval_iter` is supplied with the relevant noise
  source.
- Brief-RC infoVal is now fully supported through
  [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
  and the in-package
  [`infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/infoval.md).
  No `rcicr` install needed for Brief-RC; the path uses an in-package
  implementation of Schmitz’s `genMask()` algebra.

### Behavior changes

- [`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md)
  no longer fails on a per-participant headcount of `z >= 1.96`. Status
  now returns `pass` when the median individual z is positive, `warn`
  otherwise. Per the published record (Brinkman 2019: mean ~3-4 on 2IFC
  gender; Schmitz 2024: Brief-RC systematically below 1.96), individual
  infoVal magnitudes are paradigm- and target-dependent, so a fail
  status from a headcount alone misclassifies many compliant studies.
- The `data$per_participant$meaningful` column produced by
  [`compute_infoval_summary()`](https://olivethree.github.io/rcicrdiagnostics/reference/compute_infoval_summary.md)
  is renamed to `above_threshold`. Code that reads the old column name
  will break and needs the rename.

### Bug fixes

- `build_inputs_2ifc()` (called from
  `diagnose_infoval(method = "2ifc")`) previously expected a `stimuli`
  3D array inside the rcicr `.RData`, which does not exist. The 2IFC
  path now reconstructs per-trial noise patterns from `stimuli_params`
  and `p` via
  [`rcicr::generateNoiseImage()`](https://rdrr.io/pkg/rcicr/man/generateNoiseImage.html).
  The 2IFC
  [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md)
  path was non-functional before this release.

### Documentation

- Major vignette overhaul. Section 3 expanded into a full
  data-preparation reference (input format, example datasets for both
  pipelines, plain-language description of every object inside the rcicr
  `.RData`, noise matrix specification, base-image preparation pipeline
  via webmorphR, three ways to obtain face-region masks). New section
  3.4.1 covers Brief-RC sampling regimes (without/with replacement) and
  their downstream effects. Section 6.9.1 rewritten with sourced
  empirical baselines from Brinkman 2019 and Schmitz 2024 replacing
  previously unsourced framing. New section 6.9.2 walks through
  [`diagnose_infoval()`](https://olivethree.github.io/rcicrdiagnostics/reference/diagnose_infoval.md).

### Internal

- Adds `jpeg` and `png` to Suggests for the optional
  [`load_face_mask()`](https://olivethree.github.io/rcicrdiagnostics/reference/load_face_mask.md)
  PNG/JPEG path. No new hard dependencies.

## rcicrdiagnostics 0.1.0

- Initial tagged release. See README.md for the full overview.
