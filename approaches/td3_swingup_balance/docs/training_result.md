# MathWorks-Style Furuta TD3 Run

Date: 2026-06-15
Branch: `dev/direct-td3-swingup`

This is a fast-results training path that keeps the Furuta model but borrows
the successful training shape from the MathWorks Quanser QUBE direct TD3
example.

## Entry Point

Run from MATLAB:

```matlab
run("scripts/trainFurutaDirectTD3MathWorksStyle.m")
```

The run writes to:

```text
results/TD3/run_<timestamp>_td3_mathworks_style/
```

## Main Differences From Curriculum TD3

- no staged curriculum,
- one random reset distribution,
- default MATLAB TD3 networks with `NumHiddenUnit = 64`,
- CPU learner by default, based on the local CPU/GPU update benchmark,
- async parallel training enabled by default,
- no fixed-case evaluation inside the training loop,
- short fixed evaluation after training,
- full fixed evaluation after training.

## Training Defaults

```matlab
cfg.Agent.UseDevice = "cpu";
cfg.Agent.NetworkStyle = "default";
cfg.Agent.NumHiddenUnit = 64;
cfg.Agent.SampleTime = 5e-3;
cfg.Agent.MiniBatchSize = 1024;
cfg.Agent.NumEpoch = 10;
cfg.Training.MaxEpisodes = 2000;
cfg.Training.EpisodeDuration = 5;
cfg.Training.UseParallel = true;
cfg.Training.ParallelMode = "async";
cfg.Training.RequestedWorkers = 22;
```

The reset distribution is:

```matlab
Theta1ErrorRange = deg2rad([-45 45]);
Theta2ErrorRange = deg2rad([-45 45]);
Omega1ErrorRange = [0 0];
Omega2ErrorRange = [0 0];
```

## Reward

The reward mode is selected by a numeric codegen-friendly field:

```matlab
cfg.Reward.RewardMode = 2;
```

It implements the corrected MathWorks reward form:

```text
r = F - 0.1 * (
    theta2Error^2
  + theta1Error^2
  + 1e-2 * omega1Error^2
  + 1e-2 * omega2Error^2
  + u[k-1]^2
  + 0.3 * (u[k-1] - u[k-2])^2
)
```

where:

```text
F = 1 when abs(theta1Error) <= aliveTheta1Limit and abs(omega1Error) <= aliveOmega1Limit
F = 0 otherwise
```

The Simulink safety termination still uses the configured safety limits for arm
angle, pendulum angle, and angular velocities.

The gate limits are explicit config fields:

```matlab
cfg.Reward.aliveTheta1Limit = cfg.Safety.MaxAbsArmAngle;
cfg.Reward.aliveOmega1Limit = 30.0;
```

## Overnight Wide Experiment

For the next overnight run:

```matlab
run("scripts/trainFurutaDirectTD3MathWorksStyleWide.m")
```

This writes to:

```text
results/TD3/run_<timestamp>_td3_mathworks_style_wide/
```

It keeps the MathWorks-style single-run TD3 workflow, increases training to
3000 episodes, widens the initial pendulum error to +/-90 deg, and adds random
initial angular velocities in `[-2, 2]` rad/s for both joints.

## Evaluation

Short final evaluation:

```text
7 cases, theta2Error = [-45 -20 -5 0 5 20 45] deg
```

Full final evaluation:

```text
297 cases, same broad grid used by the prior direct TD3 branch
```

Both evaluations use `evaluateFurutaController` with parallel evaluation enabled
by default.

## CPU/GPU Benchmark

The benchmark script:

```matlab
run("scripts/test/benchmarkTD3DeviceUpdate.m")
```

showed that CPU was faster than GPU for 64- and 128-hidden-unit TD3-like update
loops on the current machine, so this run does not force GPU.
