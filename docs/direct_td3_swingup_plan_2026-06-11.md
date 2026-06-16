# Direct TD3 Swing-Up Branch Plan

Date: 2026-06-11
Branch: `dev/direct-td3-swingup`

This branch keeps the goal of training one direct RL agent to swing up and
stabilize the Furuta pendulum. It intentionally moves the setup closer to the
MathWorks Quanser QUBE TD3 example while preserving lessons from this project:
fixed post-stage evaluation, staged curriculum, organized results, explicit
configuration, and reward diagnosis.

## Reference And Credit

This branch is inspired by the MathWorks example:

> Train TD3 Agent to Control Quanser QUBE Pendulum

Official MathWorks documentation:

<https://ch.mathworks.com/help/reinforcement-learning/ug/train-td3-agent-to-control-quanser-qube-pendulum.html>

Local reference copy:

```text
references/MATLAB-Train-Default-TD3-Agent-to-Control-Quanser-QUBE-Pendulum/
```

Credit: the QUBE TD3 training structure, especially the 7-element observation
style, slower RL sample time, large replay buffer, larger mini-batch, SGDM
optimizer settings, and episode-end learning pattern, comes from the MathWorks
Reinforcement Learning Toolbox example above. This project adapts those ideas
to a different Furuta model, motor/current/torque interface, reward definition,
curriculum, and evaluation workflow.

The Brian Douglas / MathWorks hybrid QUBE Servo2 repository is also included as
a submodule for comparison:

```text
references/Reinforcement-Learning-Inverted-Pendulum-with-QUBE-Servo2/
```

That repository uses a hybrid SAC/PPO/classical-control architecture. This
branch is not switching to that architecture yet; it tests whether a direct TD3
agent can work after making our setup more comparable to the successful QUBE TD3
example.

## Observation Vector

The previous near-upright branch used:

```text
[theta1Error, theta2Error, omega1Error, omega2Error]
```

That was easy to interpret, but it is not ideal for large-angle swing-up because
raw wrapped angles can create discontinuities.

This branch keeps the error-based interpretation but represents angular errors
with sine and cosine:

```text
[sin(theta1Error),
 cos(theta1Error),
 sin(theta2Error),
 cos(theta2Error),
 omega1Error,
 omega2Error,
 previousAction]
```

The target upright state is still error-to-zero:

```text
theta1Error = 0  -> sin(theta1Error) = 0, cos(theta1Error) = 1
theta2Error = 0  -> sin(theta2Error) = 0, cos(theta2Error) = 1
omega1Error = 0
omega2Error = 0
previousAction should be smooth/small when stabilized
```

This keeps the reward and diagnosis consistent with classical control while
giving the neural network a continuous representation of circular variables.

`theta2Error` keeps the hardware state-space controller convention:

```text
theta2Error = -atan2(sin(theta2 - pi), cos(theta2 - pi))
```

Important documentation/presentation point: the scalar `theta2Error` is wrapped
to `[-pi, pi]`, so the scalar signal has a sign discontinuity at the downward
position. The agent observation avoids exposing that discontinuity directly by
using `sin(theta2Error)` and `cos(theta2Error)`, which are continuous circular
features. Reward diagnostics and automated metrics still decode a scalar error
with `atan2`; this is acceptable for the current squared-error reward because
`+pi` and `-pi` have the same cost. A cleaner future reward variant would use a
periodic cost such as `2 * (1 - cos(theta2Error))`, which removes the scalar
wrap discontinuity from the pendulum-angle cost itself.

## Simulink Wiring Required

The Simulink observation bus/vector must be updated to emit exactly seven
signals in this order:

```text
1. sin(theta1Error)
2. cos(theta1Error)
3. sin(theta2Error)
4. cos(theta2Error)
5. omega1Error
6. omega2Error
7. previousAction, meaning the last applied agent action `u[k-1]`
```

The reward function has been updated to decode this vector back into wrapped
errors using `atan2`. It still accepts the legacy four-element vector during the
transition, but the training config now declares an observation dimension of 7,
so the RL Agent block must match the new convention before training.

Because the arm angle is represented with sine and cosine, the reward can only
recover the wrapped arm error. Hard arm travel safety should therefore be
enforced in Simulink from the raw arm angle or raw arm error, not only from the
decoded wrapped observation. The reward-side arm limit remains useful as a
secondary check, but the model-side `isDone`/safety path should be the authority
for physical arm travel.

The `previousAction` observation should be the last applied action, `u[k-1]`.
In the current Simulink reward path, the reward function receives delayed action
signals to avoid an algebraic loop:

```text
reward input u      = u[k-1]
reward input uPrev  = u[k-2]
```

That is fine. The observation should still use `u[k-1]`, not `u[k-2]`, so the
agent knows the action that produced the current transition/state. The
`delta_u` reward penalty should continue to use the reward function's explicit
`u` and `uPrev` inputs.

Because the reward path uses consecutive delay blocks for `u` and `uPrev`, the
reward function can see an artificial startup `delta_u` jump. Debugging the
direct-TD3 wiring showed that skipping one reward step is sufficient, so the
active config uses `cfg.Reward.duWarmupSteps = 1`. This is not intended to hide
physical startup transients; it prevents an artificial reward jump introduced by
the delay-block initialization used to avoid algebraic loops in Simulink.

## TD3 Configuration

The active config in `scripts/makeFurutaConfig.m` now uses:

```matlab
cfg.Agent.SampleTime = 5e-3;
cfg.Agent.LearningFrequency = -1;
cfg.Agent.PolicyUpdateFrequency = 2;
cfg.Agent.TargetUpdateFrequency = 2;
cfg.Agent.MiniBatchSize = 1024;
cfg.Agent.ExperienceBufferLength = 1e6;
cfg.Agent.NumWarmStartSteps = 1024;
cfg.Agent.NumEpoch = 10;
cfg.Agent.MaxMiniBatchPerEpoch = 100;
```

The TD3 optimizer/noise settings are also QUBE-like:

```matlab
Actor optimizer:  SGDM, learn rate 2e-3, gradient threshold 1
Critic optimizer: SGDM, learn rate 5e-3, gradient threshold 1
Exploration std:  0.50, decay 1e-6, min 0.05
Target policy noise std: 0.20, limit 0.50
```

The main differences from the previous branch are:

- RL policy rate changed from 1 kHz to 200 Hz.
- Learning changed from in-episode updates every 40 agent steps to
  episode-end learning with `LearningFrequency = -1`.
- Mini-batch and replay buffer were increased.
- The observation changed from local raw errors to error-based sin/cos plus
  previous action.

## Curriculum

The branch uses four stages:

| Stage | Name | Max Episodes | Initial Condition Focus |
| --- | --- | ---: | --- |
| 1 | `near_upright_stabilization` | 300 | small upright errors |
| 2 | `medium_upright_recovery` | 500 | moderate upright recovery |
| 3 | `large_angle_recovery` | 1000 | large but not full swing-up errors |
| 4 | `full_swingup` | 2000 | broad pendulum range including hanging/downward cases |

All stages keep the same observation/action interface and the same network
architecture, so training can continue stage-to-stage without rewiring or
changing the saved-agent structure.

## Reward

The reward remains error-based. The reward function decodes the new sin/cos
observation into:

```text
theta1Error = atan2(sinTheta1Error, cosTheta1Error)
theta2Error = atan2(sinTheta2Error, cosTheta2Error)
```

Then it applies the same style of terms:

```text
alive bonus
- theta2 error cost
- theta1 error cost
- velocity cost
- effort cost
- action-change cost, after the initial delta-u warmup steps
+ upright bonus
- unsafe penalty
```

All reward weights and scales are explicit config fields, not hidden constants
inside `rewardFcnFuruta.m`. After the first Stage 1 direct-TD3 run, the active
reward settings were tightened for local stabilization:

```matlab
cfg.Reward.theta2Weight = 1.0;
cfg.Reward.theta2Scale = deg2rad(15);
cfg.Reward.theta1Weight = 0.1;
cfg.Reward.theta1Scale = deg2rad(30);
cfg.Reward.omega1Weight = 0.05;
cfg.Reward.omega1Scale = 5.0;
cfg.Reward.omega2Weight = 0.02;
cfg.Reward.omega2Scale = 5.0;
cfg.Reward.lambda_u = 1e-3;
cfg.Reward.lambda_du = 3e-2;
cfg.Reward.duWarmupSteps = 1;
cfg.Reward.aliveBonus = 0.02;
cfg.Reward.uprightBonus = 0.2;
cfg.Reward.uprightTolerance = deg2rad(8);
cfg.Reward.unsafePenalty = 10.0;
```

The intent is to make arm centering and damping visible earlier, while keeping
the lower unsafe penalty that empirically avoided harsh critic targets during
early learning.

For swing-up, the pendulum angle is no longer terminated at +/-30 deg. The
pendulum safety limit is now `pi` radians so the agent can explore the full
pendulum rotation. Arm angle and angular velocity safety limits still terminate
unsafe episodes.

## Expected Use

Before running:

1. Update or duplicate the Simulink training model so the RL Agent observation
   input is 7 elements in the order listed above.
2. Confirm the previous-action signal used in the observation is the same
   previous action used by the reward/action-rate path.
3. Run a short zero-agent or random-agent smoke test to confirm dimensions and
   reward diagnosis logging.
4. Start training with `trainFurutaStabilizationTD3`.

The first training run should be treated as a comparability experiment, not as a
final controller. Fixed post-stage evaluation should decide whether this direct
TD3 path remains promising.
