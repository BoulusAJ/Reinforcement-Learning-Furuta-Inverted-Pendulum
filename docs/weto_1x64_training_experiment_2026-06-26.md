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
