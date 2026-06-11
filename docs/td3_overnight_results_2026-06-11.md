# TD3 Overnight Run Results - 2026-06-11

## Run

Primary overnight TD3 run:

```text
results/TD3/run_20260610_234307_td3_upright_stabilization
```

This run used the TD3 setup with:

```matlab
cfg.Agent.SampleTime = 1e-3;
cfg.Agent.UseDevice = "gpu";
cfg.Agent.LearningFrequency = 40;
cfg.Agent.MiniBatchSize = 64;
cfg.Agent.NumWarmStartSteps = 5000;
cfg.Limits.CurrentMax = 4;
cfg.Training.EpisodeDuration = 1;
```

Training used the stripped training model:

```text
scripts/inv_rot_pen_RL_cntr_simscape_sim_train.slx
```

Post-stage evaluation used the richer evaluation/logging model:

```text
scripts/inv_rot_pen_RL_cntr_simscape_sim.slx
```

## Training Progress

The agent learned to survive training episodes, especially late in each stage.
Saved training statistics:

| Stage | Name | Episodes completed | Last episode steps | Last average reward | Mean steps over last 20 |
|---:|---|---:|---:|---:|---:|
| 1 | local_small_angle | 273 | 1000 | 506.69 | 939.1 |
| 2 | medium_angle | 90 | 1000 | 474.72 | 863.0 |
| 3 | robust_near_upright | 388 | 1000 | 480.03 | 878.0 |

The user observed MATLAB likely timed out during Stage 3 post-stage evaluation
after Stage 3 episode 388:

```text
Episode: 387/700 | Episode reward: 980.56 | Episode steps: 1000 | Average reward: 377.61
Episode: 388/700 | Episode reward: 961.61 | Episode steps: 1000 | Average reward: 480.03
Running post-stage evaluation for Stage 3: robust_near_upright
```

## Fixed Post-Stage Evaluation

Despite strong training episode survival, fixed post-stage evaluation still
failed too often.

| Stage | Name | Fixed cases | Failure rate | Mean final theta2 MAE | Max final theta2 error | Mean torque energy | Mean dAction energy |
|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | local_small_angle | 35 | 82.86% | 0.09396 rad | 0.50223 rad | 0.00246 | 0.01049 |
| 2 | medium_angle | 35 | 60.00% | 0.04848 rad | 0.36775 rad | 0.01010 | 0.04826 |
| 3 | robust_near_upright | 35 | 71.43% | 0.08733 rad | 0.53078 rad | 0.01843 | 0.08958 |

Stage 2 was the best fixed-evaluation result, but still failed 21 of 35 cases.
Stage 3 did not improve robustness; it regressed in failure rate and action
smoothness.

## Failure Modes From Metrics

Using the fixed-case metric thresholds:

```matlab
MaxAbsArmAngle = 90 deg
MaxAbsPendulumAngle = 30 deg
```

the failure indicators were:

| Stage | Failed cases | Arm-limit cases | Pendulum-limit cases | Mean max theta1 | Max theta1 | Mean max theta2 error | Max theta2 error |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 29/35 | 29 | 0 | 82.8 deg | 90.6 deg | 13.1 deg | 28.8 deg |
| 2 | 21/35 | 21 | 0 | 69.1 deg | 91.7 deg | 12.6 deg | 21.1 deg |
| 3 | 25/35 | 0 | 25 | 76.9 deg | 88.0 deg | 24.1 deg | 30.4 deg |

Interpretation:

- Stage 1 and Stage 2 mostly learned to keep the pendulum angle inside the
  30 degree safety envelope, but often by letting the rotary arm drift to the
  90 degree arm limit.
- Stage 3 did not simply fix the arm issue. It shifted toward pendulum-angle
  failures while still allowing large arm excursions.
- Strong training reward therefore did not imply a robust stabilizing
  controller on the fixed evaluation distribution.

## Manual Simulation Observations

The user manually tested:

```matlab
theta0 = [0; pi + deg2rad(5)];
theta0 = [0; pi + deg2rad(15)];
theta0 = [0; pi + deg2rad(-5)];
theta0 = [0; pi + deg2rad(-15)];
```

Observed behavior:

- `theta2` can sometimes momentarily reach upright.
- `theta1` often diverges away instead of staying managed.
- The positive and negative cases were not symmetric.
- Negative cases did not produce a better controller behavior.
- Near the end of a 1 second simulation, the action signal starts oscillating
  at about 125 Hz.
- The oscillatory action contributes to instability instead of acting like a
  smooth stabilizing torque command.

## Conclusion

This TD3 run is a useful result, not a dead end:

- TD3 is clearly better than the earlier DDPG runs.
- It can learn to survive many training episodes.
- It achieved nonzero success on fixed evaluation cases.

However, it is not yet a satisfactory near-upright stabilizer:

- fixed-case failure rate remains high,
- the arm angle is not managed reliably,
- stage progression does not monotonically improve robustness,
- the 125 Hz action oscillation remains,
- behavior is asymmetric for positive/negative initial pendulum offsets,
- training reward overestimates controller quality.

The next formulation should use the lessons from this pure-TD3 attempt rather
than simply retraining longer. The leading candidates are:

- add previous action to the observation if an action-change reward penalty is
  kept,
- consider sin/cos angle encoding for broader angle ranges,
- compare against the sampled state-space controller as a formal baseline,
- test residual RL:

```matlab
tau_cmd = tau_ss + residualScale * a_rl
```

Residual RL is attractive because the state-space controller already produces
the correct stabilizing torque trend, while pure TD3 still struggles with arm
management, action smoothness, and robust generalization.
