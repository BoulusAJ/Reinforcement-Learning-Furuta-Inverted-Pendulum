# Weto Inputs Side Branch Archive

Branch: `dev/weto-inputs-side`

This was a short-lived, low-conflict preparation branch used while current
training work and unpushed results could still exist on another PC. It supported
the main `weto-inputs` experiment branch and was merged into it on July 3, 2026.

## Purpose

The main `weto-inputs` branch was applying suggestions from Thomas Weinmann
(ZHAW), initially through controlled network-size and observation experiments.
This side branch allowed model-fidelity analysis and detailed-plant preparation
to continue without disturbing those runs or their training configuration.

Its work had two stages:

1. Prepare the explicit 1x64 TD3 actor/critic experiment and comparison notes.
2. Prepare the more detailed `1c` plant, measurements, analysis tools, and a
   handoff for training on a second PC.

## Work Done Here

- Added the initial 200 Hz and 500 Hz 1x64 TD3 configurations and training
  scripts. The completed run results and conclusions were later committed on
  `weto-inputs`.
- Analyzed uncontrolled current measurements, including bias, noise
  distribution, spectrum, and possible mains harmonics.
- Prepared the first detailed `1c` analytical-plant, training, analysis, and
  model-vs-hardware Simulink variants.
- Added current, friction, encoder, filtering, and communication-fidelity notes
  for later model calibration and domain randomization.
- Added ramp-consistent state initialization for the velocity filters.
- Added `compareWetoInputRuns.m` for comparing result folders produced on
  another machine.
- Wrote the `5011` handoff for detailed-model fine-tuning from the working
  `500Hz_long` policy.

This branch prepared the detailed-model path; it did not contain the later
completed detailed training campaign or establish that the approach worked.

## Outcome

The preparation was successfully merged into `weto-inputs`. Subsequent work on
that branch showed that the detailed plant was useful for evaluating existing
agents and exposing model-to-hardware mismatches, but the tested scratch and
fine-tuning runs did not produce a reliable new swing-up-and-balance policy.

The side branch should therefore be read as an engineering handoff and model
preparation checkpoint, not as a separate successful controller result.

## Key Files

- [`docs/weto_input_side_workflow.md`](docs/weto_input_side_workflow.md)
- [`docs/5011_training_handoff.md`](docs/5011_training_handoff.md)
- [`docs/domain_randomization_preparation.md`](docs/domain_randomization_preparation.md)
- [`docs/weto_1x64_training_experiment_2026-06-26.md`](docs/weto_1x64_training_experiment_2026-06-26.md)
- [`scripts/compareWetoInputRuns.m`](scripts/compareWetoInputRuns.m)
- [`scripts/functions/rampConsistentFilterX0.m`](scripts/functions/rampConsistentFilterX0.m)
- `scripts/inv_rot_pen_RL_cntr_simscape_sim_1c*.slx`
- `data/system_measurements/`

## Relationship to `weto-inputs`

`dev/weto-inputs-side` was merged into `weto-inputs` in commit `a56a612`.
Consequently, the final `weto-inputs` branch contains the files prepared here as
well as the later training results, hardware comparisons, `1d` work, and July 9
presentation material. Use the `weto-inputs` README for the complete outcome.

## Archive Decision

Keep this branch as a compact record of where the detailed-model preparation
originated. Do not merge it separately into the final main branch because its
useful content is already present in `weto-inputs`. Select only maintained
model-fidelity documentation or helpers needed by the final project.
