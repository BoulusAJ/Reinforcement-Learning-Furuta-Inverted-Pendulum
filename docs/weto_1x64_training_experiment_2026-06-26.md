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
