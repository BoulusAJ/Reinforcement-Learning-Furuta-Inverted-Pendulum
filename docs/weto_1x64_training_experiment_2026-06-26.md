# Weto 1x64 Training Experiment - 2026-06-26

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

Comparison targets:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long/evaluation
results/TD3/run_20260618_121014_td3_mathworks_style_pi_current_1b_500hz/evaluation
```

The previous 500 Hz long run only has short final evaluation artifacts in the
tracked result folder, so full-grid comparisons use the earlier 500 Hz
PI-current run.

Short evaluation:

| Metric | Actor1x64/Critic2x64 500 Hz long | 500 Hz long baseline | 500 Hz baseline |
| --- | ---: | ---: | ---: |
| FailureRate | 0.000 | 0.000 | 0.000 |
| MeanFinalTheta2MAE | 0.277 rad | 6.61e-8 rad | 1.56e-8 rad |
| MeanTheta2IAE | 1.583 | 0.532 | 0.559 |
| MeanElectricalAbsEnergy | 4.166 | 0.718 | 0.637 |
| MeanDActionEnergy | 0.0405 | 0.00626 | 0.00501 |
| MeanActionDiffRMS | 0.0643 | 0.0300 | 0.0219 |
| MeanActionEndOscRMS | 0.0645 | 2.85e-7 | 9.86e-8 |
| Score | -13.26 | -2.13 | -1.37 |

Important detail: the short-set `FailureRate = 0` is not enough to say the
policy captured upright. Two short cases survive the full 5 s but end far from
upright:

| Case | theta2Error0 | FinalTheta2MAE | Theta2EndPeakToPeak | MeanAbsElectricalPower |
| ---: | ---: | ---: | ---: | ---: |
| 2 | -0.349 rad | 0.794 rad | 6.282 | 2.843 |
| 7 | +0.785 rad | 1.145 rad | 6.283 | 2.322 |

So the actor-small 500 Hz policy is not a clean upright balancer on the short
set even though it avoids safety termination.

Full evaluation against the earlier 500 Hz PI-current baseline:

| Metric | Actor1x64/Critic2x64 500 Hz long | 500 Hz baseline | Delta |
| --- | ---: | ---: | ---: |
| FailureRate | 0.047 | 0.118 | -0.071 |
| MeanFinalTheta2MAE | 0.576 rad | 0.095 rad | +0.481 rad |
| MeanTheta2IAE | 3.152 | 2.262 | +0.891 |
| MeanElectricalAbsEnergy | 8.972 | 1.869 | +7.102 |
| MeanAbsElectricalPower | 2.289 | 1.090 | +1.199 |
| MeanDActionEnergy | 0.0877 | 0.00970 | +0.0780 |
| MeanActionDiffRMS | 0.122 | 0.0546 | +0.0669 |
| MeanActionEndOscRMS | 0.124 | 0.0342 | +0.0896 |
| Score | -70.70 | -122.51 | +51.81 |

Failure overlap on the 297-case full evaluation:

```text
actor1x64/critic2x64 failed: 14
500 Hz baseline failed: 35
both failed: 2
new-only failures: 12
baseline-only failures rescued by new policy: 33
both passed: 250
```

This looks good if only safety termination is counted. However, on the 250 cases
where both policies pass, the older 500 Hz baseline is dramatically tighter and
smoother:

| Metric on both-pass cases | Actor1x64/Critic2x64 | 500 Hz baseline |
| --- | ---: | ---: |
| MeanFinalTheta2MAE | 0.479 rad | 5.28e-5 rad |
| MeanTheta2IAE | 3.118 | 2.389 |
| MeanTheta2EndOscRMS | 0.631 | 0.000397 |
| MeanTheta2EndPeakToPeak | 2.915 | 0.00149 |
| MeanActionDiffRMS | 0.106 | 0.0297 |
| MeanActionEndOscRMS | 0.104 | 4.26e-5 |
| MeanElectricalAbsEnergy | 8.522 | 1.689 |

Conclusion:

```text
The 500 Hz actor1x64/critic2x64 policy is more likely to avoid safety
termination across the full grid, but it is much worse as an upright balancing
controller. It uses far more current/energy, has much larger action variation,
and often survives without settling upright.
```

Interpretation:

- Higher policy rate did compensate for some safety failures from the 200 Hz
  small-actor version.
- The small actor still appears to lack the fine near-upright control quality
  of the default MathWorks-style policy.
- This is not a good hardware candidate as-is because the symptom is exactly
  the hardware concern: large action variation and poor final-window settling.
- The next step should not be further network shrinking. The next useful
  experiments are reward/model robustness changes: upright-gated jitter/current
  penalties, actuator/sensor imperfections, and parameter randomization.
