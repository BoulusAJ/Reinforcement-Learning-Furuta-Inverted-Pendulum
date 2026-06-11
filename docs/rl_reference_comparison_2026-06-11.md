# RL Reference Comparison: Furuta TD3 vs MathWorks QUBE Examples

Date: 2026-06-11

This note compares the current Furuta RL implementation against two MathWorks
references:

- local/default TD3 QUBE reference:
  `references/MATLAB-Train-Default-TD3-Agent-to-Control-Quanser-QUBE-Pendulum/TrainAgentsToControlQuanserQUBEPendulumExample.m`
- Brian Douglas / MathWorks hybrid QUBE Servo2 reference submodule:
  `references/Reinforcement-Learning-Inverted-Pendulum-with-QUBE-Servo2`

The main reason for this comparison is to understand why our direct TD3
near-upright training became slow and did not generalize well, and what should
be borrowed before the next training approach.

## Current Furuta TD3 Implementation

Relevant files:

- `scripts/makeFurutaConfig.m`
- `scripts/createTD3AgentFuruta.m`
- `scripts/trainFurutaStabilizationDDPG.m`

Current agent and training settings:

```matlab
cfg.Agent.Algorithm = "TD3";
cfg.Agent.UseDevice = "gpu";
cfg.Agent.SampleTime = 1e-3;
cfg.Agent.LearningFrequency = 40;
cfg.Agent.PolicyUpdateFrequency = 2;
cfg.Agent.TargetUpdateFrequency = 2;
cfg.Agent.MiniBatchSize = 64;
cfg.Agent.ExperienceBufferLength = 2e5;
cfg.Agent.NumWarmStartSteps = 5000;
```

The observation vector is local and near-upright:

```text
[theta1Error, theta2Error, omega1Error, omega2Error]
```

The actor is a deterministic continuous policy:

```text
obs(4) -> FC128 -> ReLU -> FC128 -> ReLU -> FC1 -> tanh -> scaling
```

Each critic has separate observation and action paths, then combines them:

```text
obs(4)    -> FC128 -> ReLU
action(1) -> FC128
add -> ReLU -> FC128 -> ReLU -> Q
```

TD3 uses two such critics. Actor and critics are explicitly assigned to GPU
when `cfg.Agent.UseDevice = "gpu"`.

## MathWorks Default TD3 QUBE Example

Relevant file:

```text
references/MATLAB-Train-Default-TD3-Agent-to-Control-Quanser-QUBE-Pendulum/TrainAgentsToControlQuanserQUBEPendulumExample.m
```

The QUBE TD3 example uses a direct TD3 controller for swing-up and stabilization.
The plant/controller sample time is:

```matlab
Ts = 0.005;   % 200 Hz RL agent
Tf = 5;       % 5 s episode
maxSteps = ceil(Tf/Ts);   % 1000 steps
```

Observation vector:

```text
[sin(theta), cos(theta), dtheta, sin(phi), cos(phi), dphi, previous_action]
```

Action:

```text
normalized voltage command in [-1, 1]
```

The example does not manually construct actor and critic layer graphs. Instead,
it asks MATLAB to generate default TD3 networks:

```matlab
initOpts = rlAgentInitializationOptions(NumHiddenUnit=64);
agent = rlTD3Agent(obsInfo, actInfo, initOpts, agentOpts);
```

Agent options:

```matlab
agentOpts = rlTD3AgentOptions( ...
    SampleTime=Ts, ...
    ExperienceBufferLength=1e6, ...
    MiniBatchSize=1024, ...
    NumEpoch=10);
```

It also switches the optimizers to SGDM:

```matlab
Actor LearnRate  = 2e-3
Critic LearnRate = 5e-3
GradientThreshold = 1
```

The example does not set `LearningFrequency`, `PolicyUpdateFrequency`, or
`TargetUpdateFrequency`. Per current MathWorks documentation for
`rlTD3AgentOptions`, the defaults are:

```text
LearningFrequency = -1
PolicyUpdateFrequency = 2
TargetUpdateFrequency = 2
NumEpoch = 1 default, overridden to 10 in the example
MaxMiniBatchPerEpoch = 100
```

The important default is `LearningFrequency = -1`, which means learning occurs
at the end of each episode once enough warm-start samples have been collected.
Therefore this QUBE example is not doing small TD3 updates every environment
step. It collects an episode, then performs a larger replay-buffer learning
burst.

Official documentation checked:

- <https://www.mathworks.com/help/reinforcement-learning/ref/rl.option.rltd3agentoptions.html>

## MathWorks / Brian Douglas Hybrid QUBE Servo2 Example

Relevant files:

```text
references/Reinforcement-Learning-Inverted-Pendulum-with-QUBE-Servo2/RL/design_RL_multi_control_SAC_md.md
references/Reinforcement-Learning-Inverted-Pendulum-with-QUBE-Servo2/RL/design_RL_multi_control_PPO_md.md
```

The hybrid example does not attempt to solve all behavior with one direct RL
controller. It uses:

```text
SAC: swing-up controller
PPO: mode-selection controller
classical feedback controller: upright stabilization
```

Common timing:

```matlab
Tc = 0.005;      % feedback controller period, 200 Hz
Ts = Tc * 4;     % RL agent period, 20 ms, 50 Hz
Tf = 10;         % 10 s episode
maxSteps = floor(Tf/Ts);   % 500 RL steps
```

The RL observation is global and angle-wrap safe:

```text
[sin(motor_angle), cos(motor_angle),
 sin(pendulum_angle), cos(pendulum_angle),
 motor_speed, pendulum_speed]
```

The SAC swing-up agent uses a stochastic continuous actor and two Q critics. The
documented networks are larger than ours, with hidden layers around 400 and 300
units. SAC options include:

```matlab
SampleTime = Ts
TargetSmoothFactor = 1e-3
ExperienceBufferLength = 1e6
DiscountFactor = 0.99
MiniBatchSize = 128
UseDeterministicExploitation = true
```

The file does not set `LearningFrequency`. Per current MathWorks documentation
for `rlSACAgentOptions`, the defaults include:

```text
LearningFrequency = -1
PolicyUpdateFrequency = 1
TargetUpdateFrequency = 1
NumEpoch = 1
MaxMiniBatchPerEpoch = 100
```

Official documentation checked:

- <https://www.mathworks.com/help/reinforcement-learning/ref/rl.option.rlsacagentoptions.html>

The PPO mode-selection agent is on-policy and uses trajectory-style updates. It
sets:

```matlab
ExperienceHorizon = floor(Tf/Ts);   % 500
MiniBatchSize = floor(Tf/Ts);       % 500
```

Per current MathWorks documentation for `rlPPOAgentOptions`, PPO also defaults
to:

```text
LearningFrequency = -1
NumEpoch = 3
```

For PPO, `LearningFrequency = -1` means learning occurs at the end of each
episode once a minimum amount of data has been collected.

Official documentation checked:

- <https://www.mathworks.com/help/reinforcement-learning/ref/rl.option.rlppoagentoptions.html>

## Training Frequency Comparison

There are two different frequencies that must not be confused:

1. agent/control sample frequency: how often the policy chooses an action
2. learning frequency: how often actor/critic parameters are updated

### Agent Sample Rate

| Setup | RL sample time | RL action rate | Episode length | RL steps per episode |
| --- | ---: | ---: | ---: | ---: |
| Current Furuta TD3 | 0.001 s | 1000 Hz | 1 s | 1000 |
| MathWorks QUBE TD3 | 0.005 s | 200 Hz | 5 s | 1000 |
| Hybrid SAC/PPO | 0.020 s | 50 Hz | 10 s | 500 |

Our current agent acts much faster than both MathWorks examples.

### Learning Cadence

Current Furuta TD3:

```text
LearningFrequency = 40
```

At 1 kHz, this requests a learning iteration every:

```text
40 steps * 1 ms = 40 ms
```

That is:

```text
25 learning iterations per simulated second
```

Since our episode is 1 s and 1000 steps, that is approximately:

```text
1000 / 40 = 25 learning iterations per full episode
```

With MathWorks off-policy defaults, each learning iteration can use up to:

```text
NumEpoch * MaxMiniBatchPerEpoch
```

For our current TD3, `NumEpoch` is not overridden, so it defaults to 1, and
`MaxMiniBatchPerEpoch` defaults to 100. This means the upper bound is:

```text
25 * 1 * 100 = 2500 mini-batch gradient updates per episode
```

The actual number depends on replay-buffer state, but this upper bound explains
why training can become much slower after the buffer fills.

MathWorks QUBE TD3:

```text
LearningFrequency = -1 default
NumEpoch = 10
MaxMiniBatchPerEpoch = 100 default
```

This means learning is episode-end by default, with an upper bound:

```text
1 * 10 * 100 = 1000 mini-batch gradient updates per episode
```

The QUBE example may still perform substantial learning, but it batches that
work after the episode instead of interrupting the Simulink simulation every few
milliseconds of simulated time.

Hybrid SAC:

```text
LearningFrequency = -1 default
NumEpoch = 1 default
MaxMiniBatchPerEpoch = 100 default
MiniBatchSize = 128
```

This is also episode-end by default, and the RL agent acts only at 50 Hz.

Hybrid PPO:

```text
ExperienceHorizon = 500
MiniBatchSize = 500
LearningFrequency = -1 default
NumEpoch = 3 default
```

This is an on-policy, trajectory-style update rather than replay-buffer TD3/SAC
style learning.

## Research And Example-Level Interpretation

In common TD3 research implementations, interleaved data collection and learning
is standard:

```text
collect environment interaction(s)
store in replay buffer
sample mini-batches
update critics
update actor less often than critics
```

The TD3 paper's key stability idea is delayed actor updates: the actor and
target networks update less frequently than the critics. Spinning Up summarizes
the recommendation as one policy update for every two Q-function updates, and
uses `policy_delay = 2`.

Spinning Up TD3 and Stable-Baselines3 TD3 both use step/chunk-based updates.
Stable-Baselines3 defaults are:

```text
train_freq = 1
gradient_steps = 1
policy_delay = 2
```

References:

- <https://spinningup.openai.com/en/latest/algorithms/td3.html>
- <https://stable-baselines3.readthedocs.io/en/master/modules/td3.html>

However, the MathWorks Simulink examples favor slower RL sample rates and
episode-end learning defaults. This is probably not accidental. In Simulink and
hardware-oriented workflows, frequent in-episode network updates can:

- interrupt simulation repeatedly,
- make timing behavior harder to diagnose,
- make training slower as the replay buffer grows,
- change the policy during a single rollout of an unstable physical system.

For Gym-style software environments, interleaved TD3 updates are normal. For
Simulink/hardware control, especially an unstable rotary pendulum, the MathWorks
examples suggest a more practical pattern:

```text
slower RL policy rate
fast low-level plant/controller rate underneath
larger replay-buffer update bursts between episodes
```

## Practical Conclusions For This Project

The current Furuta TD3 setup has three main mismatches relative to the
references:

1. The RL action rate is high: 1000 Hz versus 200 Hz in QUBE TD3 and 50 Hz in
   the hybrid example.
2. Learning occurs repeatedly inside each episode, while the MathWorks examples
   keep the default episode-end learning cadence.
3. The observation vector is local and near-upright, while both MathWorks
   examples use sin/cos angle representations for global angle continuity. The
   TD3 QUBE example also includes previous action.

The network size is probably not the first issue. Our 128/128 TD3 networks are
not smaller than the default QUBE TD3 hidden size of 64. The bigger issues are
observation design, training cadence, policy sample time, and architecture
choice.

Recommended next direction:

```text
For residual/near-upright RL:
    use a slower RL sample time, likely 5 ms
    use a Markov-compatible observation including previous action if delta_u is penalized
    consider LearningFrequency = -1 or a much larger chunk frequency
    explicitly set MaxMiniBatchPerEpoch to bound training cost

For swing-up:
    do not extend the current local-error TD3 setup directly
    use sin/cos observations
    use a separate swing-up policy/controller or hybrid supervisor architecture
    consider SAC for swing-up, following the hybrid MathWorks pattern
```

For hardware later, episode-end or between-trial learning is the cleaner and
safer pattern. It avoids changing the policy repeatedly during a single unstable
rollout and makes failures easier to classify from fixed-case evaluation.
