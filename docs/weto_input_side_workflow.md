# Weto Input Side Workflow

Date: 2026-07-01

This branch is for low-conflict side work while the latest unpushed training
state may still exist on another machine.

## Purpose

The main `weto-inputs` branch prepared a controlled experiment from Thomas
Weinmann's feedback:

- keep the 1b PI/current training and evaluation setup,
- replace the previous default-style `64-64` TD3 networks with explicit `1x64`
  actor and critic networks,
- compare 200 Hz and 500 Hz behavior against the existing baselines.

This side branch should avoid changing training configs, reward blocks, or
Simulink models unless those changes are intentionally moved into a new
experiment branch.

## Safe Work Here

- collect existing evaluation summary CSVs into one comparison table,
- prepare interpretation criteria for the 1x64 runs,
- add analysis scripts that can consume a run folder copied from another PC,
- write notes for the next domain-randomization experiment.

Current domain-randomization implementation notes are collected in
`docs/domain_randomization_preparation.md`.

The handoff for continuing detailed-model training on PC `5011` is in
`docs/5011_training_handoff.md`.

## Comparison Helper

Use:

```matlab
addpath(genpath("scripts"))

runDirs = [
    "results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long"
    "results/TD3/<copy_the_1x64_500hz_run_here>"
    "results/TD3/<copy_the_1x64_200hz_run_here>"
];

comparison = compareWetoInputRuns(runDirs);
```

The helper writes:

```text
results/weto_input_comparison_summary.csv
```

Missing run folders are kept as rows with `Available=false`, so the same script
can be prepared before the other machine's run folder is available.

## Decision Criteria

Treat `1x64` as useful only if it keeps enough swing-up/capture ability while
improving at least some upright smoothness metrics.

Primary checks:

- failure rate does not get materially worse,
- final theta2 error remains small,
- `MeanActionDiffRMS` decreases,
- `MeanActionEndOscRMS` or `MeanActionEndOscFreqHz` decreases,
- electrical effort does not increase substantially.

If `1x64` keeps swing-up but still jitters, the next experiment should probably
be reward/model realism rather than another network-size tweak:

- state-dependent upright jitter penalties,
- action/current RMS and action-rate penalties near upright,
- friction, damping, current-scale, delay, dead-zone, and sensor randomization,
- mirrored hardware command filtering in simulation.

If `1x64` fails to train or loses capture ability, keep the `64-64` baseline and
move to the domain-randomized robustness path described in
`docs/hardware_transfer_status_2026-06-23.md`.
