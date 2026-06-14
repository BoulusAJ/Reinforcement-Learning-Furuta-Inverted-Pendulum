# Direct TD3 Stage 1 Results

Date: 2026-06-11
Branch: `dev/direct-td3-swingup`

This note records the first completed Stage 1 run for the direct TD3 swing-up
branch and the reward-scale observations from manual inspection.

## Run

Run folder:

```text
results/TD3/run_20260611_170945_td3_direct_swingup
```

Important config values:

```matlab
cfg.Agent.SampleTime = 5e-3;
cfg.Agent.LearningFrequency = -1;
cfg.Agent.MiniBatchSize = 1024;
cfg.Agent.NumEpoch = 10;
cfg.Agent.MaxMiniBatchPerEpoch = 100;
cfg.Training.EpisodeDuration = 5;
cfg.Training.StopTrainingCriteria = "AverageReward";
cfg.Training.StopTrainingValue = 450;
cfg.Reward.unsafePenalty = 10;
cfg.Reward.duWarmupSteps = 1;
```

Stage 1 curriculum:

```matlab
Theta1ErrorRange = [0 0];
Theta2ErrorRange = deg2rad([-5 5]);
Omega1ErrorRange = [0 0];
Omega2ErrorRange = [-1 1];
NoiseStd = 0.10;
MaxEpisodes = 800;
```

## Timing

File timestamps from the run folder:

| Artifact | Timestamp | Interpretation |
| --- | --- | --- |
| run folder/config | 2026-06-11 17:09 | Run setup started. |
| first saved agent, `Agent98.mat` | 2026-06-11 17:12 | Training had reached the first saved high-reward checkpoint. |
| last saved agent, `Agent234.mat` | 2026-06-11 17:32 | Training had reached the last saved checkpoint before stop/timeout. |
| Stage 1 MAT file | 2026-06-11 17:57 | Stage save completed after post-stage evaluation. |
| evaluation CSVs | 2026-06-11 17:57 | Post-stage fixed evaluation completed. |

Approximate elapsed times:

| Segment | Approx elapsed |
| --- | ---: |
| Stage 1 training from run setup to last saved agent | ~23 min |
| Post-stage evaluation over 297 broad cases | ~25 min |
| Total run folder activity | ~48 min |

The user observed MATLAB timing out around the episode-235 update. This is
consistent with the final saved checkpoint being `Agent234.mat`.

## Broad Post-Stage Evaluation

The saved post-stage summary was:

| NumCases | FailureRate | MeanFinalTheta2MAE | MaxFinalTheta2Error | MeanTheta2IAE | MeanTorqueEnergy | MeanDActionEnergy | Score |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 297 | 1.0 | 1.4067 rad | 3.1416 rad | 0.0994 | 0.00855 | 0.01706 | -1000 |

This evaluation grid is much broader than the Stage 1 reset distribution. It
includes pendulum errors from -180 deg to +180 deg, arm errors at -45/0/+45 deg,
and high initial velocities. Therefore this 100% failure rate should not be
used by itself to judge whether Stage 1 learned the small-error balance task.

## Manual Stage 1 Observations

The user manually inspected:

```matlab
theta0 = [0; pi + deg2rad(5)];
theta0 = [0; pi + deg2rad(-5)];
```

For the +5 deg case:

- `theta2` reaches upright and slightly overshoots it.
- The controller appears to attempt correction after overshoot.
- `theta1` diverges instead of returning toward zero.
- `omega1` no longer trends toward zero.
- The behavior becomes unstable from roughly 1 s onward.

For the -5 deg case:

- The reward diagnosis outputs showed very small shaped reward terms.
- At about `theta2Error = -0.02 rad`, the theta2 reward component was around
  `-0.0007`.
- Near a later upright crossing, `omega2` was about `0.14 rad/s`, while the
  velocity penalty was close to zero relative to theta and bonus terms.

## Reward-Scale Interpretation

The small theta2 reward value is mathematically consistent with the current
normalization:

```matlab
theta2Term = -(theta2Error / deg2rad(45))^2
```

For `theta2Error = -0.02 rad`, this gives approximately:

```text
-(0.02 / 0.785)^2 = -0.00065
```

The velocity term is intentionally even smaller in the current reward:

```matlab
velocityTerm = -0.01 * ((omega1Error / 20)^2 + (omega2Error / 20)^2)
```

For `omega2Error = 0.14 rad/s` and small `omega1Error`, this is only around:

```text
-0.01 * (0.14 / 20)^2 = -4.9e-7
```

So the diagnosis does not indicate a logging bug; it shows that the current
reward barely penalizes small velocities and very weakly distinguishes excellent
near-upright behavior from merely acceptable near-upright behavior.

This is probably not a numerical-precision problem for TD3. The larger concern
is signal-to-noise and credit assignment: the shaped terms can be tiny compared
with the alive bonus (`0.1`), upright bonus (`1.0`), and terminal unsafe penalty
(`10`). The agent may therefore learn survival/upright contact before it learns
arm-centering and damping.

The reduced unsafe penalty helped empirically by avoiding a huge reward
discontinuity and appears to have allowed longer episodes before episode 100.
That is a plausible effect: with `unsafePenalty = 1000`, early bad transitions
can dominate critic targets and make the value landscape harsh. With
`unsafePenalty = 10`, failures are still bad but the critic is not trained on
such extreme one-step cliffs.

## Current Assessment

Stage 1 is not a failed experiment. It shows partial learning: the agent can
move the pendulum toward upright from small offsets. The main missing behavior
is arm management and damping after the pendulum crosses upright.

The next diagnosis should not be another broad 297-case swing-up evaluation.
Run a Stage-1-specific fixed grid first:

```text
theta1Error0 = 0
theta2Error0 = [-5 -2 0 2 5] deg
omega1Error0 = 0
omega2Error0 = [-1 0 1] rad/s
```

If this local grid succeeds but the broad grid fails, continue curriculum work.
If this local grid fails after about 1 s because the arm drifts, adjust the
reward before continuing long training.

The next reward configuration has been updated to make every reward weight an
explicit config field and to increase local stabilization signal strength:

```matlab
cfg.Reward.theta2Weight = 1.0;
cfg.Reward.theta2Scale = deg2rad(15);
cfg.Reward.theta1Weight = 0.1;
cfg.Reward.theta1Scale = deg2rad(30);
cfg.Reward.omega1Weight = 0.05;
cfg.Reward.omega1Scale = 5.0;
cfg.Reward.omega2Weight = 0.02;
cfg.Reward.omega2Scale = 5.0;
cfg.Reward.aliveBonus = 0.02;
cfg.Reward.uprightBonus = 0.2;
cfg.Reward.unsafePenalty = 10.0;
```

This keeps the reduced unsafe penalty for now, lowers the alive/upright bonuses,
and makes velocity, especially arm velocity, visible to the critic.

The MathWorks QUBE TD3 example can run for 2000 episodes in one go because its
example environment, reward, and evaluation target are already internally
matched. In this Furuta branch, Stage 1 has exposed a reward/objective mismatch,
so continuing blindly is less useful than tightening the Stage 1 diagnosis and
reward scale first.
