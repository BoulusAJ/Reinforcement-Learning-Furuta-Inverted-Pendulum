# 5011 Training Handoff

Date: 2026-07-03

This note is for continuing the next training work on the PC nicknamed `5011`.
The current side branch on PC `5538` is `dev/weto-inputs-side`. It contains the
preparation work for training on the new detailed analytical model.

## Current Direction

The immediate training goal is no longer the rest of the Weto-input suggestions.
Those remain useful later, but the next priority is:

- train on the new detailed model,
- start from the final `500Hz_long` policy as the baseline initialization,
- compare the detailed-model fine-tuning result against the original
  `500Hz_long` baseline,
- then decide whether to add domain randomization,
- only return to the remaining Weto-input ideas if the detailed-model path
  behaves well.

Baseline policy/run:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

## What Was Prepared On 5538

- Detailed model documentation and future randomization notes:
  `docs/domain_randomization_preparation.md`
- Weto side workflow note:
  `docs/weto_input_side_workflow.md`
- README pointers to both the detailed-model work and Weto `1x64` experiment.
- Current-measurement noise analysis:
  `data/system_measurements/analyze_uncontrolled_current_noise.m`
- Current-noise reference data and generated analysis outputs under:
  `data/system_measurements/`
- Weto comparison helper:
  `scripts/compareWetoInputRuns.m`
- Ramp-consistent filter initial-state helper:
  `scripts/functions/rampConsistentFilterX0.m`
- Detailed/current-fidelity model work in the new/modified Simulink models,
  including the `1c` model variants and analytical-vs-detailed comparison
  models.

## Important Detailed-Model Notes

The detailed model includes or documents:

- current measurement bias/noise:
  `currentBias_A`, `currentNoiseStd_A`,
- command-side static compensation:
  `I_static_comp_A`,
- theta1 physical friction:
  `param.Friction.Theta1`,
- current best empirical friction scaling:

```matlab
tauF = viscous * 7 + coulombStatic * 2.3;
```

- encoder quantization and 680 Hz encoder notch filtering,
- ramp-consistent filter initialization to avoid false velocity spikes at reset,
- current-setpoint low-pass, current PI, PI roll-off, and voltage/PWM
  compensation details.

The friction scaling was selected from model-vs-hardware experimentation
against:

```text
results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/20260622_201704_hardware
```

Treat it as a calibration candidate, not a final physical constant.

## Suggested 5011 Next Steps

1. Merge or cherry-pick this side branch into `dev/weto-inputs`.
2. Verify the detailed model opens and simulates with the final `500Hz_long`
   agent loaded.
3. Confirm filter initial conditions behave correctly for nonzero `theta0` and
   `omega0` resets.
4. Create a training config that mirrors `500Hz_long`, but points to the new
   detailed training/evaluation model.
5. Initialize training from the final `500Hz_long` agent rather than training
   from scratch.
6. Run a short smoke training/evaluation first.
7. Compare against the original `500Hz_long` metrics before adding domain
   randomization.
8. Add domain randomization gradually, following the phased guidance in
   `docs/domain_randomization_preparation.md`.

Prepared detailed-model training scripts after merging to `dev/weto-inputs`:

```text
scripts/makeFurutaMathWorksStylePICurrent1c500HzLongDetailedTD3Config.m
scripts/trainFurutaDirectTD3MathWorksStylePICurrent1c500HzLongDetailed.m
```

The prepared config uses:

```text
training model:   scripts/inv_rot_pen_RL_cntr_simscape_sim_1c_train.slx
analysis model:   scripts/inv_rot_pen_RL_cntr_simscape_sim_1c_analysis.slx
baseline family:  500Hz_long PI/current TD3
```

The config includes but disables:

```text
cfg.Training.UseInitialAgent = false
cfg.DomainRandomization.Enabled = false
cfg.Training.UseDiary = true
```

To fine-tune from the deployed `500Hz_long` final agent, set:

```matlab
cfg.Training.UseInitialAgent = true;
```

The initial agent path is already set to:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long/FurutaTD3_mathworks_style_pi_current_1b_500hz_long_final.mat
```

Domain-randomization ranges are included for later but should stay off for the
first nominal detailed-model run.

The trainer writes `training_console.log` into the run folder when
`cfg.Training.UseDiary=true`, so terminal episode output is preserved even if a
run is interrupted.

## Detailed-Model Training Results

The first two completed nominal detailed-model runs are documented in:

```text
docs/detailed_model_training_results_2026-07-05.md
```

Short version:

- training from scratch completed 5000 episodes but learned a survival/swinging
  behavior rather than clean upright balance,
- fine-tuning from the original `500Hz_long` final agent also completed 5000
  episodes and reached full-length episodes quickly, but still failed to
  capture/balance upright in fixed evaluation,
- both runs plateaued in the final 800-1000 episodes,
- do not add domain randomization until the nominal detailed model can learn
  proper capture and balance.

Update after the near-upright diagnostic run:

- `run_20260705_221352_td3_mathworks_style_pi_current_1c_500hz_long_detailed_near_upright`
  fine-tuned from the original `500Hz_long` final agent with near-upright resets,
  reset replay buffer, pendulum travel termination, and a 3 s upright-reach
  timeout,
- reward rose strongly in the first ~20 episodes but collapsed around episodes
  `46-55` and finished on a much lower plateau,
- final fixed evaluation was poor (`full_final` failure rate about `0.859`,
  mean final theta2 error about `2.43 rad`),
- next suggested experiment is to add measured current `i_meas` to the
  observation, likely with gentler fine-tuning settings or network surgery if
  warm-starting from the old 7-observation agent.

## Caution

Keep deterministic fixed evaluations deterministic. Domain-randomized
evaluation should be a separate explicit experiment, otherwise comparisons with
the original `500Hz_long` baseline will become muddy.
