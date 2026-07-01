# Weto 1x64 Training Experiment - 2026-06-26

Main Weto-input progress overview:

```text
docs/weto_inputs_progress_2026-07-01.md
```

## Purpose

This experiment tests the first suggestion from Thomas Weinmann's input:
reduce the TD3 actor and critic networks to a single hidden layer with 64
neurons, while changing as little else as possible.

The immediate question is whether a smaller policy can keep the same swing-up
capability while reducing near-upright jitter and improving hardware
transferability.

## Baseline Context

The recent hardware-tested policy was:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

It used the 1b PI/current path at 500 Hz and transferred far enough to attempt
lift-up on the real system, but jittered near upright.

The older successful 200 Hz reference run was:

```text
results/TD3/run_20260616_012625_td3_mathworks_style_wide
```

That run used the same broad MathWorks-style reset/reward family, but predates
the 1b PI/current model path used for hardware transfer.

## Network Clarification

The current MathWorks-style TD3 config sets:

```matlab
cfg.Agent.NetworkStyle = "default";
cfg.Agent.NumHiddenUnit = 64;
```

So the previous MathWorks-style agents were using MATLAB's default TD3 network
initializer with 64 hidden units, not the explicit custom `2x128` network in
`createTD3AgentFuruta.m`. The custom `2x128` path only applies when
`cfg.Agent.NetworkStyle` is not `"default"` or `"custom_mlp"`.

MATLAB R2025b generated the default TD3 networks as:

```text
actor:
input -> FC(64) -> ReLU -> FC(64) -> ReLU -> FC(action) -> tanh

critic:
observation -> FC(64) ----\
                            concat -> ReLU -> FC(64) -> ReLU -> FC(Q)
action      -> FC(64) ----/
```

For this experiment, the network is made explicit:

```matlab
cfg.Agent.NetworkStyle = "custom_mlp";
cfg.Agent.ActorHiddenLayerSizes = 64;
cfg.Agent.CriticHiddenLayerSizes = 64;
```

This creates the same default-style topology with the second hidden layer
removed:

```text
actor:
input -> FC(64) -> ReLU -> FC(action) -> tanh

critic:
observation -> FC(64) ----\
                            concat -> ReLU -> FC(Q)
action      -> FC(64) ----/
```

The critic therefore keeps MATLAB's default separate observation/action
projection and concatenation structure, but removes the post-merge `FC(64) ->
ReLU` block.

## What Stays Fixed

For both rates:

- training model: `scripts/inv_rot_pen_RL_cntr_simscape_sim_1b_train.slx`,
- evaluation model: `scripts/inv_rot_pen_RL_cntr_simscape_sim_1b_analytical_active.slx`,
- action interface: normalized RL action mapped to current command,
- reset distribution and reward terms from the corresponding previous config,
- parallel training remains enabled,
- requested workers remain inherited from the previous configs, currently `22`,
- current scaling remains `cfg.Action.CurrentScale = cfg.Limits.CurrentMax`.

## Prepared Training Scripts

200 Hz, 1x64:

```matlab
scripts/trainFurutaDirectTD3MathWorksStylePICurrent1b200Hz1x64.m
```

500 Hz long, 1x64:

```matlab
scripts/trainFurutaDirectTD3MathWorksStylePICurrent1b500HzLong1x64.m
```

## Prepared Config Files

200 Hz, 1x64:

```matlab
scripts/makeFurutaMathWorksStylePICurrent1b200Hz1x64TD3Config.m
```

500 Hz long, 1x64:

```matlab
scripts/makeFurutaMathWorksStylePICurrent1b500HzLong1x64TD3Config.m
```

## Previous Limit Values

From saved result configs:

| Run | Agent Ts | CurrentMax | VoltageMax |
| --- | ---: | ---: | ---: |
| `run_20260616_012625_td3_mathworks_style_wide` | `0.005 s` / 200 Hz | `4 A` | `24 V` |
| `run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long` | `0.002 s` / 500 Hz | `4 A` | `21.84 V` |

The current base config computes:

```matlab
cfg.Limits.SupplyVoltage = 24;
cfg.Limits.PwmOffset = 0.09;
cfg.Limits.VoltageMax = cfg.Limits.SupplyVoltage * (1 - cfg.Limits.PwmOffset);
cfg.Limits.CurrentMax = 4;
```

Therefore the new 1b 200 Hz and 500 Hz 1x64 configs use:

```text
CurrentMax = 4 A
VoltageMax = 21.84 V
```

## Comparison Plan

Compare each new run against the relevant previous baseline using the existing
evaluation summaries and hardware-transfer metrics:

- swing-up success/failure rate,
- upright dwell time,
- arm-limit failures,
- final theta2 error,
- action RMS near upright,
- action-difference RMS near upright,
- current usage,
- qualitative jitter near upright.

The experiment should be treated as a controlled network-size test. Reward
shaping, domain randomization, observation changes, and friction/dead-zone
modeling should wait until after this comparison unless the 1x64 run clearly
fails to train.

## 200 Hz Result - Failed Controlled Experiment

Run:

```text
results/TD3/run_20260626_132419_td3_mathworks_style_pi_current_1b_200hz_1x64
```

Training reached the configured 3000 episodes, but the final training episodes
were still terminating very early. A 5 s episode at 200 Hz should contain about
1000 agent steps, while the final episodes were typically tens to low hundreds
of steps:

```text
Episode 2995: 125 steps
Episode 2996:  37 steps
Episode 2997: 103 steps
Episode 2998: 144 steps
Episode 2999:  54 steps
Episode 3000:  37 steps
```

This means the policy was still failing after roughly 0.185 s to 0.72 s in the
last visible episodes.

Final evaluation confirmed the training trace:

| Eval set | Cases | FailureRate | Score | MeanFinalTheta2MAE | MeanTheta2IAE |
| --- | ---: | ---: | ---: | ---: | ---: |
| short_final | 7 | 1.000 | -1000 | 1.336 rad | 0.660 |
| full_final | 297 | 1.000 | -1000 | 1.789 rad | 0.663 |

The evaluation failures also terminated early:

| Eval set | Mean SimTime | Min SimTime | Max SimTime |
| --- | ---: | ---: | ---: |
| short_final | 0.506 s | 0.465 s | 0.580 s |
| full_final | 0.379 s | 0.075 s | 1.435 s |

The interesting detail is that this failed run did not fail by applying a large,
violent command. It mostly failed while using very little control effort:

| Run / eval | FailureRate | MeanElectricalAbsEnergy | MeanDActionEnergy | MeanActionDiffRMS |
| --- | ---: | ---: | ---: | ---: |
| 200 Hz 1x64 short | 1.000 | 0.034 | 5.13e-6 | 0.0031 |
| 500 Hz PI/current short baseline | 0.000 | 0.637 | 5.01e-3 | 0.0219 |
| 500 Hz long PI/current short baseline | 0.000 | 0.718 | 6.26e-3 | 0.0300 |
| 200 Hz wide PI/current analytical short baseline | 0.000 | 0.360 | 3.35e-3 | 0.0211 |

So the symmetric reduction to actor 1x64 plus critic 1x64 appears to have
underfit or under-trained the policy. The resulting actor did not learn useful
energy injection for swing-up; it is not merely a jittery or unsafe version of a
working controller.

Conclusion:

```text
Do not spend a full 500 Hz long run on the same symmetric 1x64 actor/critic
architecture yet.
```

The next controlled variant should keep the deployment-relevant actor small but
restore critic capacity:

```text
actor: default-style 1x64
critic: MATLAB default-style 2x64
```

This tests whether the actor can be small while the critic remains expressive
enough to train the swing-up Q-function.

## Follow-Up Variant - Actor 1x64, Critic 2x64

Prepared after the symmetric 1x64 actor/critic failure.

This variant keeps the actor small:

```text
actor:
input -> FC(64) -> ReLU -> FC(action) -> tanh
```

but restores the critic to the MATLAB default-style hidden capacity:

```text
critic:
observation -> FC(64) ----\
                            concat -> ReLU -> FC(64) -> ReLU -> FC(Q)
action      -> FC(64) ----/
```

Config settings:

```matlab
cfg.Agent.NetworkStyle = "custom_mlp";
cfg.Agent.ActorHiddenLayerSizes = 64;
cfg.Agent.CriticHiddenLayerSizes = [64 64];
cfg.Agent.NetworkDescription = "custom_mlp_actor_1x64_critic_2x64";
```

Prepared 200 Hz run:

```matlab
scripts/trainFurutaDirectTD3MathWorksStylePICurrent1b200HzActor1x64Critic2x64.m
```

Prepared 500 Hz long run:

```matlab
scripts/trainFurutaDirectTD3MathWorksStylePICurrent1b500HzLongActor1x64Critic2x64.m
```

Recommended sequence:

1. Run the 200 Hz actor-small/critic-default variant first.
2. If it learns full-length episodes and gives nontrivial evaluation behavior,
   then run the 500 Hz long version.
3. If it still fails like the symmetric 1x64 run, do not spend compute on the
   500 Hz long version; move to reward/model randomization or return to the
   default actor as well.

## 200 Hz Actor 1x64 / Critic 2x64 Result

Run:

```text
results/TD3/run_20260626_152631_td3_mathworks_style_pi_current_1b_200hz_actor1x64_critic2x64
```

This run learned meaningful control, unlike the symmetric actor 1x64 / critic
1x64 run. Restoring the critic capacity fixed the "barely acts" failure mode.

Comparison target:

```text
results/TD3/run_20260616_012625_td3_mathworks_style_wide/analysis/pi_current_analytical_active
```

Short evaluation:

| Metric | Actor1x64/Critic2x64 | 200 Hz PI-current baseline | Delta |
| --- | ---: | ---: | ---: |
| FailureRate | 0.000 | 0.000 | 0.000 |
| MeanFinalTheta2MAE | 0.00523 rad | 0.00604 rad | -0.00080 rad |
| MeanTheta2IAE | 0.2566 | 0.2981 | -0.0415 |
| MeanElectricalAbsEnergy | 0.455 | 0.360 | +0.095 |
| MeanDActionEnergy | 0.00540 | 0.00335 | +0.00205 |
| MeanActionDiffRMS | 0.0278 | 0.0211 | +0.0067 |
| Score | -1.070 | -1.471 | +0.401 |

On the short near-upright evaluation set, the actor-small/critic-default policy
is slightly better in final theta2 and integrated theta2 error, but uses more
electrical energy and has more action variation.

Full evaluation:

| Metric | Actor1x64/Critic2x64 | 200 Hz PI-current baseline | Delta |
| --- | ---: | ---: | ---: |
| FailureRate | 0.269 | 0.145 | +0.125 |
| MeanFinalTheta2MAE | 0.529 rad | 0.126 rad | +0.402 rad |
| MeanTheta2IAE | 1.006 | 1.133 | -0.127 |
| MeanElectricalAbsEnergy | 2.502 | 2.566 | -0.063 |
| MeanAbsElectricalPower | 3.790 | 0.911 | +2.879 |
| MeanDActionEnergy | 0.0316 | 0.0348 | -0.0032 |
| MeanActionDiffRMS | 0.145 | 0.0815 | +0.0635 |
| MeanActionEndOscRMS | 0.118 | 0.0334 | +0.0844 |
| Score | -273.5 | -147.6 | -125.9 |

The full evaluation is worse overall. The actor-small policy fails more cases
and has much higher final-window action and theta2 oscillation in the full grid.

Failure overlap on the 297-case full evaluation:

```text
actor1x64/critic2x64 failed: 80
200 Hz PI-current baseline failed: 43
both failed: 12
new-only failures: 68
baseline-only failures: 31
both passed: 186
```

The extra failures are concentrated around the hanging/downward region and
zero pendulum velocity:

| Slice | Actor1x64/Critic2x64 failures | Baseline failures |
| --- | ---: | ---: |
| theta2Error0 = -pi | 16 / 27 | 5 / 27 |
| theta2Error0 = +pi | 16 / 27 | 5 / 27 |
| theta2Error0 = +2.356 rad | 18 / 27 | 3 / 27 |
| omega2Error0 = 0 | 40 / 99 | 10 / 99 |

Pass-only notes:

- On the 186 cases both policies pass, the baseline is still much tighter near
  upright: mean final theta2 error is about `0.0060 rad` for the baseline vs
  `0.090 rad` for the actor-small policy.
- Considering all cases where the actor-small policy passes, it sometimes
  rescues cases the baseline fails; however, this comes with weaker full-grid
  robustness and more final-window oscillation.

Conclusion:

```text
The actor 1x64 / critic 2x64 idea is viable in the sense that training works,
but the 200 Hz result is not better than the older 200 Hz PI-current baseline
on the full evaluation grid. It is promising enough to justify checking the
500 Hz long version already in progress, but not enough to replace the baseline
by itself.
```

Interpretation:

- The critic was the bottleneck in the symmetric 1x64 failure.
- A small actor can learn swing-up when trained by a stronger critic.
- The 200 Hz small actor may have insufficient policy capacity or insufficient
  action-rate authority for the wide full-grid cases, especially near the
  hanging/downward states.
- If the 500 Hz long run performs well, the higher policy rate may compensate
  for the smaller actor. If it has the same failure pattern, then the next
  experiment should move to reward/model robustness rather than further network
  shrinking.

## 500 Hz Long Actor 1x64 / Critic 2x64 Result

Run:

```text
results/TD3/run_20260629_130518_td3_mathworks_style_pi_current_1b_500hz_long_actor1x64_critic2x64
```

### Corrected Evaluation Note - 2026-06-30

The original saved 500 Hz fixed-evaluation artifacts were affected by a
parallel-worker workspace bug. The worker initialized with the generic
`makeFurutaConfig()` workspace instead of the saved run config. For 500 Hz runs
this meant the worker used the default 200 Hz agent sample time (`0.005 s`)
instead of the intended 500 Hz sample time (`0.002 s`).

The evaluation code was corrected so `evalCfg.WorkspaceConfig = cfg` is used by
parallel workers. A new 2% theta2 settling metric was also added:

```text
SettlingTimeTheta2      = existing strict 1 degree final settling metric
SettlingTimeTheta2Pct2  = 2% settling around upright, abs(theta2Error) <= 0.02*pi
```

Current corrected artifacts:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long/evaluation/full_fixed_workspace_metrics.csv
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long/evaluation/full_fixed_workspace_summary.csv
results/TD3/run_20260629_130518_td3_mathworks_style_pi_current_1b_500hz_long_actor1x64_critic2x64/evaluation/full_fixed_workspace_metrics.csv
results/TD3/run_20260629_130518_td3_mathworks_style_pi_current_1b_500hz_long_actor1x64_critic2x64/evaluation/full_fixed_workspace_summary.csv
```

Corrected short evaluation:

| Metric | 500 Hz long baseline | Actor1x64/Critic2x64 500 Hz long |
| --- | ---: | ---: |
| FailureRate | 0.000 | 0.000 |
| MeanFinalTheta2MAE | 3.95e-8 rad | 0.223 rad |
| MeanTheta2IAE | 0.532 | 1.493 |
| MeanElectricalAbsEnergy | 0.354 | 0.854 |
| MeanActionDiffRMS | 0.00863 | 0.0153 |
| MeanActionEndOscRMS | 1.19e-7 | 0.0204 |
| Score | -2.12 | -11.65 |

Corrected full evaluation:

| Metric | 500 Hz long baseline | Actor1x64/Critic2x64 500 Hz long |
| --- | ---: | ---: |
| FailureRate | 0.0539 | 0.0471 |
| MeanFinalTheta2MAE | 0.0632 rad | 0.395 rad |
| MeanTheta2IAE | 1.869 | 2.686 |
| MeanTheta2EndOscRMS | 0.0557 | 0.501 |
| MeanTheta2EndPeakToPeak | 0.228 | 2.442 |
| MeanElectricalAbsEnergy | 1.191 | 2.365 |
| MeanActionDiffRMS | 0.0242 | 0.0513 |
| MeanActionEndOscRMS | 0.00930 | 0.0440 |
| Score | -58.65 | -63.54 |

Failure overlap on the corrected 297-case full evaluation:

```text
500 Hz long baseline failed: 16
actor1x64/critic2x64 failed: 14
both failed: 2
actor-small only failures: 12
baseline-only failures rescued by actor-small: 14
both passed: 269
```

On the 269 cases where both policies pass, the deployed 500 Hz long baseline is
still much tighter and smoother:

| Metric on both-pass cases | 500 Hz long baseline | Actor1x64/Critic2x64 |
| --- | ---: | ---: |
| MeanFinalTheta2MAE | 6.07e-6 rad | 0.330 rad |
| MeanActionDiffRMS | 0.0205 | 0.0449 |
| MeanElectricalAbsEnergy | 1.184 | 2.457 |

Physical down start, i.e. raw initial state `theta0 = [0; 0]`,
`omega0 = [0; 0]`, equivalent to `Theta1Error0 = 0`,
`Theta2Error0 = +/-pi`, `Omega1Error0 = 0`, `Omega2Error0 = 0`:

| Metric | 500 Hz long baseline | Actor1x64/Critic2x64 500 Hz long |
| --- | ---: | ---: |
| SettlingTimeTheta2, 1 deg | 3.1366 s | 4.6052 s |
| SettlingTimeTheta2Pct2, 2% | 3.0692 s | 2.9787 s |
| FinalTheta2MAE | 1.31e-5 rad | 0.00980 rad |
| Theta2IAE | 5.039 | 4.484 |
| ElectricalAbsEnergy | 3.763 | 7.493 |
| ActionDiffRMS | 0.0786 | 0.133 |
| Failed | false | false |

Interpretation for the physical-down case:

- The actor-small policy enters and stays inside the 2% upright band slightly
  earlier than the 500 Hz long baseline.
- The baseline reaches the stricter 1 degree settling band much earlier and
  finishes far more accurately.
- The actor-small policy uses roughly twice the electrical absolute energy and
  has substantially more action variation.
- For fast swing-up alone, the actor-small policy is competitive in this one
  case. For clean upright balance, the baseline is still better.

Conclusion:

```text
The actor 1x64 / critic 2x64 500 Hz long policy slightly reduces full-grid
safety failures, but it is worse as a balancing controller. The deployed
500 Hz long baseline has far smaller final theta2 error, lower near-upright
oscillation, lower action variation, and lower electrical energy.
```

This means the smaller actor is not the next hardware candidate by itself. Its
main useful signal is that it can swing up and sometimes rescue cases the
baseline fails, but its near-upright behavior is too loose and energetic for
the current hardware-transfer concern.

Older 500 Hz eval CSV/MAT files produced before the workspace fix should remain
marked as unreliable for sample-time-sensitive comparisons.

## Reduced Observation Experiment Notes

The next Weto-inspired controlled experiment is to keep the small actor idea
but reduce the observation representation. The proposed starting point is:

```text
actor: 1x64
critic: 2x64
rate: 500 Hz long
observation: arc-distance angles plus scaled velocities plus previous action
```

Prepared run:

```text
config: scripts/makeFurutaMathWorksStylePICurrent1c500HzLongActor1x64Critic2x64ArcObsTD3Config.m
launcher: scripts/trainFurutaDirectTD3MathWorksStylePICurrent1c500HzLongActor1x64Critic2x64ArcObs.m
training model: scripts/inv_rot_pen_RL_cntr_simscape_sim_1c_train.slx
evaluation model: scripts/inv_rot_pen_RL_cntr_simscape_sim_1c_analytical_active.slx
```

Candidate observation:

```matlab
theta1_arc_norm = acos(cos(theta1Error)) / pi;
theta2_arc_norm = acos(cos(theta2Error)) / pi;
omega1_scaled_norm = min(max(omega1Error / cfg.Observation.AngularVelocityScale, -1), 1);
omega2_scaled_norm = min(max(omega2Error / cfg.Observation.AngularVelocityScale, -1), 1);
previous_action
```

The theta2 signal follows the existing upright-error convention before the arc
distance is computed:

```matlab
theta2Error = atan2(sin(theta2Rad - pi), cos(theta2Rad - pi));
theta2_arc_norm = acos(cos(theta2Error)) / pi;
```

Thus physical `theta2 = pi` is upright and maps to `theta2_arc_norm = 0`;
physical `theta2 = 0` is down and maps to `theta2_arc_norm = 1`.

The arc-distance terms avoid the wrap discontinuity of a signed wrapped angle,
but they are unsigned. Directional information then has to come from angular
velocity and previous action. This makes the experiment meaningful but not
risk-free: if swing-up gets worse, the policy may need a directional angle
encoding after all.

### Reward Parameter Compatibility

For the first arc-observation run, the reward is intentionally kept close to
`rewardFcnFuruta`. The goal is to isolate the observation representation change
before redesigning the reward structure.

For the angle terms, no retuning is required for the current reward formula.
The old sin/cos observation path decoded signed wrapped errors:

```matlab
theta1Error = atan2(sinTheta1Error, cosTheta1Error);
theta2Error = atan2(sinTheta2Error, cosTheta2Error);
```

The reward then used squared errors or absolute thresholds. The new arc
observation decodes:

```matlab
theta1ErrorAbs = theta1_arc_norm * pi;
theta2ErrorAbs = theta2_arc_norm * pi;
```

This is equivalent to the magnitude of the wrapped angle error. Therefore the
existing radian-based reward and safety parameters keep the same meaning:

```text
rewardParams.theta1Scale
rewardParams.theta2Scale
rewardParams.uprightTolerance
safetyParams.MaxAbsArmAngle
safetyParams.MaxAbsPendulumAngle
```

The only loss is sign: `+10 deg` and `-10 deg` have the same reward value. That
is acceptable for this controlled experiment because the current reward uses
squared angle costs and absolute safety checks.

Velocity needed an additional compatibility scale because the observation is no
longer in physical rad/s. The reward decodes:

```matlab
omega1Error = omega1_scaled_norm * rewardParams.AngularVelocityScale;
omega2Error = omega2_scaled_norm * rewardParams.AngularVelocityScale;
```

This keeps the existing velocity reward scales meaningful:

```text
rewardParams.omega1Scale
rewardParams.omega2Scale
safetyParams.MaxAbsAngularVelocity
```

Important caveat: because the observation velocity channels are saturated to
`[-1, 1]`, the reward cannot reconstruct angular speeds above
`cfg.Observation.AngularVelocityScale`. If omega safety should be enforced at
the full `200 rad/s` limit, the reward/isDone path should eventually receive
raw or unsaturated velocity signals instead of relying only on the observation
vector.

### Angular Velocity Scaling Note

The corrected eval files currently include one combined angular-velocity peak:

```text
MaxAbsOmegaError = max(abs([omega1Error, omega2Error]))
```

This is useful as a safety diagnostic, but it does not separate whether the
peak came from `omega1` or `omega2`. New evaluations now also include:

```text
MaxAbsOmega1Error
MaxAbsOmega2Error
```

For the corrected 500 Hz full evaluations:

| Run | Mean MaxAbsOmegaError | Median | 95th percentile | Max | Safety limit |
| --- | ---: | ---: | ---: | ---: | ---: |
| 500 Hz long baseline | 20.72 rad/s | 21.58 | 25.39 | 28.27 | 200 rad/s |
| Actor1x64/Critic2x64 | 20.23 rad/s | 20.81 | 24.22 | 27.75 | 200 rad/s |

For the physical-down start:

| Run | MaxAbsOmegaError |
| --- | ---: |
| 500 Hz long baseline | 23.48 rad/s |
| Actor1x64/Critic2x64 | 21.51 rad/s |

No corrected full-eval cases exceeded the current safety limit of `200 rad/s`.
That limit is therefore much too loose to be a useful observation scaling
factor. If velocities are divided by `200`, most observed values lie around
`0.10`, which makes the velocity channels small compared with angle or action
channels.

Recommended initial observation scaling for the reduced-observation
experiment:

```matlab
omega1_scaled = omega1 / 25;
omega2_scaled = omega2 / 25;
```

This scale should be treated as an observation normalization choice, not a
safety limit. The safety limit can remain at `200 rad/s` unless hardware or
simulation safety requirements suggest tightening it.

## 500 Hz Long Arc-Observation Result - Interrupted Failed Run

Run:

```text
results/TD3/run_20260630_183029_td3_mathworks_style_pi_current_1c_500hz_long_actor1x64_critic2x64_arcobs
```

This was the first 1c reduced-observation training attempt:

```text
actor: 1x64
critic: 2x64
rate: 500 Hz long
observation dimension: 5
observation: theta1 arc, theta2 arc, scaled omega1, scaled omega2, previous action
```

The training was interrupted before `train(...)` returned:

```text
IdleTimeout has been reached.
Parallel pool using the 'Processes' profile is shutting down.
The parallel pool has shut down. Use parpool to start a new pool.
```

No final agent or checkpoint agent was saved. The `saved_agents` directory is
empty because the run never reached the configured save criterion:

```matlab
cfg.Training.SaveAgentValue = 1800;
```

The console output was later preserved as:

```text
training_console_text.txt
training_console_parsed.csv
training_progress_interrupted_x5000.png
```

Parsed training trace:

| Metric | Value |
| --- | ---: |
| Episodes reached | 1837 / 5000 |
| Step count reached | 102386 |
| Mean episode steps | 55.7 |
| Median episode steps | 48 |
| Max episode steps | 472 |
| Last episode steps | 38 |
| Last average reward | -1073.41 |
| Best average reward in log | -400.43 |

At 500 Hz, a full 5 s episode is 2500 steps. The final visible episodes were
still only tens of steps:

```text
Episode 1836: reward -203.78, 33 steps, average reward -1067.94
Episode 1837: reward -248.67, 38 steps, average reward -1073.41
```

This means the policy was still failing after about `0.066 s` to `0.076 s` in
the last visible episodes.

Best guess for why this did not work:

- Pure unsigned arc-distance observations probably removed too much
  directional information. `+angle` and `-angle` map to the same value.
- Directional information was left mainly to angular velocity and previous
  action. That appears insufficient for this setup, especially when velocity
  can be near zero.
- The arm angle `theta1` is likely hurt strongly by losing sign, because arm
  centering and arm-limit avoidance need to know which side of zero the arm is
  on.
- The saturated velocity observation is useful for network scaling, but it
  also means reward/isDone cannot reconstruct angular velocities above the
  observation scale if only the observation vector is used.

Timing note:

- The interrupted arc-observation run folder was initialized at
  `2026-06-30 18:30`.
- The preserved console/plot files were created at about `2026-07-01 13:34` to
  `13:37`, after the interruption. This gives only an upper bound from run
  creation to log preservation; it is not the true training runtime.
- The last successful comparison run
  `run_20260629_130518_td3_mathworks_style_pi_current_1b_500hz_long_actor1x64_critic2x64`
  was initialized at `2026-06-29 13:05`, wrote its last saved-agent checkpoint
  around `16:36`, and wrote the final agent at `16:41`. That is roughly
  `3 h 31 min` of training to the last checkpoint and `3 h 36 min` to final
  save, before the later corrected fixed-workspace reevaluation on
  `2026-06-30 07:14`.

Conclusion:

```text
Do not continue the pure unsigned arc-distance observation run as-is.
```

The next reduced-observation attempt should restore at least some directional
information, with `theta1` sign being the first candidate because arm centering
is directly direction-dependent.

Candidate next variants:

```text
A: theta1 signed shortest arc + theta2 absolute arc distance
   observation = [theta1_signed_norm, theta2_arc_norm,
                  omega1_scaled_norm, omega2_scaled_norm, previous_action]

B: theta1 absolute arc distance + theta2 signed shortest arc
   observation = [theta1_arc_norm, theta2_signed_norm,
                  omega1_scaled_norm, omega2_scaled_norm, previous_action]
```

Variant A is the preferred first follow-up if only one run is affordable. The
reason is that `theta1` is an arm-centering and arm-limit variable, so knowing
which side of zero the arm is on is directly useful. For `theta2`, swing-up has
more energy/phase character, so `theta2_arc_norm` plus `omega2` may still carry
enough information to attempt swing-up. This is only a hypothesis; variant B is
the natural counter-test if variant A is inconclusive.

## Observation Encoding Follow-Up - Arc Distance vs Sin/Cos

One of the next Weto-inspired ideas is to reduce the observation vector by
replacing the current trigonometric angle encoding with an arc-distance
encoding. The motivation is to make the observation smaller and avoid the
neural network having to infer angle distance from paired sine/cosine states.

There is a fundamental tradeoff when representing a full circular angle:

```text
You can choose two of these three:
1. one scalar,
2. no discontinuity,
3. directionality.
```

This is not just an implementation detail. It comes from the topology of the
circle. A full circle cannot be represented by one globally continuous signed
scalar without a jump somewhere.

### Existing Sin/Cos Encoding

The usual `sin/cos` encoding uses two scalars:

```matlab
obs = [sin(theta_error); cos(theta_error)];
```

This preserves directionality and avoids the wrap discontinuity because the
pair locates the point on the unit circle.

Numerical examples around a target angle:

| theta_error | sin(theta_error) | cos(theta_error) | Interpretation |
| ---: | ---: | ---: | --- |
| `+0.2 rad` | `+0.199` | `0.980` | small positive-side error |
| `-0.2 rad` | `-0.199` | `0.980` | small negative-side error |
| `pi rad` | `0` | `-1` | opposite side of circle |
| `2*pi - 0.1 rad` | `-0.100` | `0.995` | close to target from negative side |

The cosine mostly tells how far around the circle the point is, while the sine
sign distinguishes the two sides of the target. Together they tell the network
where the state is on the circle without a jump from `+pi` to `-pi`.

Pros:

- no angle wrap discontinuity,
- preserves directional information,
- globally identifies the angular position on the circle,
- common and robust for neural-network observations.

Cons:

- uses two observation channels per angle,
- angle error magnitude is implicit rather than directly provided,
- the network must learn how to combine sine and cosine for distance-like
  reasoning.

### Signed Shortest Arc Encoding

A one-scalar signed shortest arc can be computed as:

```matlab
theta_arc_signed = atan2(sin(theta_error), cos(theta_error));
theta_arc_signed_norm = theta_arc_signed / pi;
```

This gives a normalized range of `[-1, 1]` and keeps direction:

| theta_error | theta_arc_signed | theta_arc_signed_norm |
| ---: | ---: | ---: |
| `+0.2` | `+0.2` | `+0.064` |
| `-0.2` | `-0.2` | `-0.064` |
| `2*pi - 0.1` | `-0.1` | `-0.032` |
| `pi` | `+pi` | `+1` |
| `-pi` | `-pi` | `-1` |

Pros:

- one scalar per angle,
- directly represents signed angular error,
- easy for local linear control near the target.

Cons:

- has an unavoidable discontinuity at `+/-pi`,
- physical down can appear as either `+pi` or `-pi`,
- the discontinuity may be awkward for swing-up training from broad resets.

### Absolute Arc-Distance Encoding

The proposed reduced observation experiment uses the absolute shortest arc
distance:

```matlab
theta_error_arc = acos(cos(theta_error));
theta_error_arc_norm = theta_error_arc / pi;
```

This maps every angle error to a distance in `[0, pi]`, then normalizes to
`[0, 1]`.

For the Furuta task:

```matlab
theta1_arc_norm = acos(cos(theta1)) / pi;
theta2_arc_norm = acos(cos(theta2 - pi)) / pi;
```

Here `theta2 = pi` is upright, so `theta2_arc_norm = 0` at upright and
`theta2_arc_norm = 1` at physical down.

The reason for the `cos` then `acos` is that `cos(theta_error)` collapses
periodic equivalents on the circle, and `acos(...)` maps that value back to the
principal absolute angular distance in `[0, pi]`.

Numerical examples:

| theta_error | acos(cos(theta_error)) | normalized by pi |
| ---: | ---: | ---: |
| `0` | `0` | `0` |
| `+0.2` | `0.2` | `0.064` |
| `-0.2` | `0.2` | `0.064` |
| `pi` | `pi` | `1` |
| `-pi` | `pi` | `1` |
| `2*pi - 0.1` | `0.1` | `0.032` |

Pros:

- one scalar per angle,
- no wrap discontinuity,
- directly tells the network the distance from the target,
- normalized values are in `[0, 1]`, which is convenient for RL training.

Cons:

- loses side/direction information for the angle itself,
- `+0.2 rad` and `-0.2 rad` become identical,
- the agent must infer useful direction from `omega1`, `omega2`, and previous
  action,
- near upright with low velocity may be ambiguous because both sides of the
  target can look identical.

### Proposed Controlled Experiment - First Attempt

The cleanest next test is to keep the successful small-actor/stronger-critic
setup and change only the observation representation:

```text
actor: 1x64
critic: 2x64
agent rate: 500 Hz
reward/reset/training settings: unchanged
observation:
    theta1_arc_norm
    theta2_arc_norm
    omega1_scaled
    omega2_scaled
    previous_action
```

Using normalized arc distances is preferred over physical arc lengths for the
first RL experiment:

```matlab
theta1_arc_norm = acos(cos(theta1)) / pi;
theta2_arc_norm = acos(cos(theta2 - pi)) / pi;
```

Both angle-distance observations then lie in `[0, 1]`, independent of physical
link length. This keeps the observation scale simple and comparable to the
previous `sin/cos` channels. Physical arc lengths in meters could be tested
later, but they add scale choices before we know whether the representation
itself helps.

The main question for this experiment:

```text
Can the agent recover enough directionality from angular velocities and
previous action while benefiting from a smaller, no-wrap angle-distance
observation?
```

The first pure unsigned arc-distance attempt did not answer this positively:
after 1837 episodes it was still terminating after tens of steps, with no saved
agent checkpoint. The likely issue is that the observation removed too much
directional information.

Follow-up variants should restore one signed angle channel at a time:

```text
A: signed theta1, unsigned theta2 arc distance
B: unsigned theta1 arc distance, signed theta2
```

Variant A is the preferred next diagnostic because arm centering and arm-limit
avoidance are directly side-dependent.

Evaluation should focus on:

- swing-up success and failure rate,
- physical-down `SettlingTimeTheta2Pct2`,
- final theta2 MAE,
- near-upright oscillation and action jitter,
- electrical energy and action-difference RMS.

### Angular Velocity Scaling Note

The corrected eval files currently include one combined angular-velocity peak:

```text
MaxAbsOmegaError = max(abs([omega1Error, omega2Error]))
```

This is useful as a safety diagnostic, but it does not separate whether the
peak came from `omega1` or `omega2`.

For the corrected 500 Hz full evaluations:

| Run | Mean MaxAbsOmegaError | Median | 95th percentile | Max | Safety limit |
| --- | ---: | ---: | ---: | ---: | ---: |
| 500 Hz long baseline | 20.72 rad/s | 21.58 | 25.39 | 28.27 | 200 rad/s |
| Actor1x64/Critic2x64 | 20.23 rad/s | 20.81 | 24.22 | 27.75 | 200 rad/s |

For the physical-down start:

| Run | MaxAbsOmegaError |
| --- | ---: |
| 500 Hz long baseline | 23.48 rad/s |
| Actor1x64/Critic2x64 | 21.51 rad/s |

No corrected full-eval cases exceeded the current safety limit of `200 rad/s`.
That limit is therefore much too loose to be a useful observation scaling
factor. If velocities are divided by `200`, most observed values lie around
`0.10`, which makes the velocity channels small compared with angle or action
channels.

Recommended initial observation scaling for the reduced-observation experiment:

```matlab
omega1_scaled = omega1 / 25;
omega2_scaled = omega2 / 25;
```

Rationale:

- The 95th-percentile combined peak is about `24-25 rad/s`.
- Dividing by `25` makes typical high-swing velocities order `1`.
- It keeps the velocity channels comparable to:

```matlab
theta1_arc_norm = acos(cos(theta1)) / pi;       % [0, 1]
theta2_arc_norm = acos(cos(theta2 - pi)) / pi;  % [0, 1]
previous_action                                % usually [-1, 1]
```

This scale should be treated as an observation normalization choice, not a
safety limit. The safety limit can remain at `200 rad/s` unless hardware or
simulation safety requirements suggest tightening it.

Implemented diagnostic improvement:

```text
MaxAbsOmega1Error and MaxAbsOmega2Error were added as separate eval columns.
```

This would make it easier to choose separate scaling factors if arm and
pendulum velocity ranges diverge.
