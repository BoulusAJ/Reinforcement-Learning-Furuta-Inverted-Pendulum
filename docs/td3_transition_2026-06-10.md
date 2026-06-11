# TD3 Transition Notes - 2026-06-10

## Current Status

The near-upright Furuta stabilization workflow is moving from DDPG to TD3.
The latest DDPG/debug work is checkpointed in git commit:

```text
de3db62 Checkpoint DDPG stabilization diagnostics
```

Existing DDPG result folders were moved under:

```text
results/DDPG
```

New TD3 runs are configured to write under:

```text
results/TD3
```

The DDPG run to keep for later plotting and presentation inspection is:

```text
results/DDPG/run_20260610_180340_upright_stabilization
```

This run is useful because it follows the diagnostic period where the RL
action, sampled state-space controller action, and switched torque command
were being compared.

## Why DDPG Is Being Paused

DDPG did not reliably learn the local upright stabilization task even after:

- fixing the evaluation time-base issue,
- adding reward-diagnosis bus logging,
- applying initial velocity resets through `omega0`,
- increasing the normalized action scale to 4 A / 0.39 Nm,
- increasing the agent rate to 1 kHz,
- reducing Stage 1 exploration noise,
- increasing the unsafe penalty,
- adding a small alive bonus,
- reducing replay pressure for debugging.

The clearest observations were:

- Stage 1 DDPG agents still failed fixed post-stage cases.
- Some training traces showed very short episodes, then occasional longer but unstable episodes.
- The original reward could make quick failure less costly than longer unstable survival attempts.
- The DDPG policy produced a high-frequency oscillatory torque pattern, around 125 Hz in the inspected case.
- When the state-space controller drove the plant, the DDPG actor output had a similar rough shape but worse amplitude/offset behavior and drifted toward an unhelpful torque value.
- The sampled/rate-transitioned state-space controller still stabilized 5 degree errors, so the sample-rate path is not by itself fatal.

These points suggest that the plant and action path are controllable, but DDPG's actor/critic training is too fragile for this delayed, sampled, saturated unstable system.

## Why TD3 Next

TD3 keeps the deterministic continuous-action controller framing used by DDPG, but improves the weak spots that matter here:

- twin critics reduce overestimated Q-values,
- delayed actor updates reduce unstable policy-gradient updates,
- target-policy smoothing makes the critic less sensitive to narrow action spikes,
- the actor interface remains a single normalized torque/current action in `[-1, 1]`.

TD3 is therefore the most direct next comparison before trying SAC. SAC is still a good candidate later, but TD3 changes fewer experimental assumptions while addressing the main DDPG failure mode.

## Kept Changes From The DDPG Debugging Pass

These changes are intentionally kept for TD3:

```matlab
cfg.Agent.LearningFrequency = 40;
cfg.Agent.MiniBatchSize = 64;
cfg.Agent.ExperienceBufferLength = 2e5;
cfg.Agent.NumWarmStartSteps = 5000;
cfg.Training.UseParallel = false;
cfg.Reward.aliveBonus = 0.1;
cfg.Reward.unsafePenalty = 1000;
```

Also kept:

- `rewardFcnFuruta` includes the alive bonus.
- `createDDPGAgentFuruta` reads batch and replay-buffer settings from config.
- `cfg.Agent.SampleTime = 1e-3`.
- `cfg.Agent.UseDevice = "gpu"`.
- `cfg.Limits.CurrentMax = 4`.
- `cfg.Action.TorqueScale = cfg.Motor.km * cfg.Limits.CurrentMax`.
- Stage 1 exploration noise is `0.05`.

Reasoning:

- `LearningFrequency = 40`, smaller mini-batches, and a warm start reduce replay-learning pressure after MATLAB slowed down during TD3 updates.
- Serial training avoids async parallel replay/debugging ambiguity while algorithm behavior is still being validated.
- The alive bonus plus larger unsafe penalty avoids rewarding fast failure relative to longer survival attempts.
- The 4 A torque scale matches the observed state-space controller torque range better than 1 A.

## TD3 Runtime Slowdown Diagnosis

Run:

```text
results/TD3/run_20260610_225417_td3_upright_stabilization
```

showed that TD3 was directionally better but too slow with the first debug
learner settings. The saved Stage 1 file contained 21 training episodes, and
the last episode survived 977 steps out of the 1 second / 1000 step episode.
The post-stage failure rate improved to about 65.7%, compared with repeated
100% failure DDPG runs.

The slowdown is therefore likely learner-update cost, not plant simulation
cost. At `cfg.Agent.SampleTime = 1e-3`, a full episode has about 1000 agent
steps. With `cfg.Agent.LearningFrequency = 4`, TD3 can perform about 250
learning updates per full episode, each with twin critics. This explains why
free Simulink simulation remains fast while training becomes slow once the
agent starts surviving longer.

The next TD3 run uses a lighter learner cadence:

```matlab
cfg.Agent.LearningFrequency = 40;
cfg.Agent.MiniBatchSize = 64;
cfg.Agent.NumWarmStartSteps = 5000;
```

This keeps the 1 kHz control sample time but reduces full-episode learner
updates from roughly 250 to roughly 25. The warm start also prevents expensive
replay learning after only a tiny buffer has been collected.

## GPU Training

The available GPU is an NVIDIA GeForce RTX 4080 SUPER. Seeing the GPU through
`gpuDevice` is not enough for RL training; the function approximators default
to CPU unless their `UseDevice` property is set.

The config now uses:

```matlab
cfg.Agent.UseDevice = "gpu";
```

The TD3 creator applies this to:

```matlab
actor.UseDevice = cfg.Agent.UseDevice;
critic1.UseDevice = cfg.Agent.UseDevice;
critic2.UseDevice = cfg.Agent.UseDevice;
```

MATLAB handles the actor/critic learnable parameters and mini-batches after
that. We do not manually convert weights to `gpuArray`.

## Training And Evaluation Models

Training and evaluation now use separate Simulink model names:

```matlab
cfg.Model.TrainingName = "inv_rot_pen_RL_cntr_simscape_sim_train";
cfg.Model.EvaluationName = "inv_rot_pen_RL_cntr_simscape_sim";
```

Training uses the stripped model:

```text
scripts/inv_rot_pen_RL_cntr_simscape_sim_train.slx
```

Evaluation and presentation plots can use the richer model:

```text
scripts/inv_rot_pen_RL_cntr_simscape_sim.slx
```

The helper:

```matlab
prepareFurutaTrainingModel(makeFurutaConfig(), Overwrite=true)
```

refreshes the training model from the evaluation model, disables signal
logging, and removes Scope blocks. Run it only when you intentionally want to
overwrite the stripped training model from the richer evaluation model.

## Training Command

Use:

```matlab
run("scripts/trainFurutaStabilizationTD3.m")
```

The wrapper calls the shared training script, which reads:

```matlab
cfg.Agent.Algorithm = "TD3";
```

The expected stage files will be saved as:

```text
results/TD3/run_<timestamp>_td3_upright_stabilization/stages/FurutaTD3_near_upright_stage_01_local_small_angle.mat
```

## Immediate TD3 Evaluation Goal

Do not judge TD3 from training reward alone. After Stage 1, inspect:

- fixed post-stage evaluation failure rate,
- Stage-1-training-like cases,
- action versus `ss_ctrl_rate_transition`,
- whether the 125 Hz oscillatory torque behavior persists,
- whether the agent now produces the required torque offset rather than drifting to zero.
