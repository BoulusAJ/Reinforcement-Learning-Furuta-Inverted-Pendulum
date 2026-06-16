# RL Project Lessons From Setup

These notes summarize the main things learned so far while preparing the Furuta inverted rotary pendulum RL project.

## Project Framing

The strongest project story is not "RL solves the Furuta pendulum." A better framing is:

> RL is tested as a learned near-upright controller under safety constraints, compared against a classical baseline, with sim-to-real considerations.

This makes the project scientifically stronger because it includes a baseline, fixed evaluation cases, safety limits, and hardware realism.

## Task Scope

The first RL task should be **near-upright stabilization only**.

Out of scope for the first training phase:

- swing-up from the downward position,
- direct hardware learning,
- replacing all low-level motor/current control,
- full-range robust stabilization.

The initial goal is to stabilize around the upright equilibrium and compare performance against the state-space or PI baseline.

## Observation Design

The RL observation should use the same post-summation feedback-controller error signals used by the Simulink controller:

```matlab
obs = [theta1Error; theta2Error; omega1Error; omega2Error]
```

This is better than giving raw angles because the agent sees the same meaningful control errors as the baseline controller.

The pendulum upright error follows the hardware controller convention:

```matlab
theta2WrappedFromUpright = atan2(sin(theta2 - pi), cos(theta2 - pi));
theta2Error = 0 - theta2WrappedFromUpright;
```

or:

```matlab
theta2Error = -atan2(sin(theta2 - pi), cos(theta2 - pi));
```

The short-angle wrap block:

```matlab
atan2(sin(u), cos(u))
```

maps any angle to the shortest equivalent signed angle in `[-pi, pi]`.

Documentation/presentation note: this scalar wrapped `theta2Error` has an
unavoidable sign discontinuity at the downward position (`+pi` and `-pi` are
the same physical angle but different scalar values). In the later direct-TD3
swing-up setup, the agent observation avoids exposing this discontinuity
directly by using circular features:

```matlab
[sin(theta1Error);
 cos(theta1Error);
 sin(theta2Error);
 cos(theta2Error);
 omega1Error;
 omega2Error;
 previousAction]
```

Reward diagnostics and evaluation metrics still decode a scalar wrapped error
with `atan2`. This is acceptable for the current squared-error reward because
`+pi` and `-pi` have the same cost. A cleaner future reward variant would use a
periodic pendulum cost such as:

```matlab
theta2Cost = 2 * (1 - cos(theta2Error));
```

That would remove the scalar wrap discontinuity from the pendulum-angle reward
cost itself.

## Action Design

The RL action should be normalized and signed:

```matlab
a_rl in [-1, 1]
```

This is better than `[0, 1]` because the Furuta pendulum needs bidirectional control.

The normalized action can later be mapped to current or torque:

```matlab
i_ref = a_rl * iMax;
tau_ref = a_rl * tauMax;
```

This keeps the neural-network output scale simple and makes the same policy easier to reuse if actuator limits change.

## Sample Times

The plant and the agent should use separate sample times:

```matlab
cfg.Model.PlantSampleTime = 1/20e3;
cfg.Agent.SampleTime = 5e-3;   % or 1e-2 for faster training
cfg.Agent.LearningFrequency = 1;
```

The plant/current-loop model can remain fast and hardware-like, while the RL policy acts at a slower outer-loop rate.

Important lesson: `1e-3` agent sample time was expensive. `1e-2` was much faster, and `5e-3` may be a useful compromise.

## Initialization

Running the full reference script directly is risky because it has side effects such as clearing variables, linearizing models, and plotting.

Instead, the project uses a wrapper:

```matlab
initFurutaModelWorkspace(cfg)
```

This keeps the Simulink variable names expected by the model, such as:

```matlab
theta0
param
Kp_i
Tn_i
K_oben
K_unten
Tf
```

while reusing the reference `get_parameter()` function.

## Training And Learning Frequency

For DDPG, learning uses a replay buffer. The agent does not update only from the last episode.

Important options:

```matlab
MiniBatchSize = 256
LearningFrequency = 1
```

`LearningFrequency = 1` means the agent updates from the replay buffer every agent step once enough experience is available. This is more explicit than relying on the toolbox default and is a good first choice for the short early-terminated episodes in this project.

If training becomes too slow, compare:

```matlab
LearningFrequency = 1
LearningFrequency = 4
LearningFrequency = 10
```

## Parallel Training

Parallel training can speed up data collection, but the update timing depends on the mode.

Parallel off:

```text
episodes run sequentially
learning happens after each episode when LearningFrequency = -1
```

Parallel sync:

```text
workers run synchronized batches
learning happens after the batch returns
```

Parallel async:

```text
workers send experience as it arrives
learner updates from the central replay buffer while workers continue
```

DDPG can handle async experience because it is off-policy, but evaluation during training becomes harder to interpret.

## Evaluation Lesson From Water Tank Project

MATLAB's default evaluator can be misleading because random initial conditions make the result depend heavily on where the episode started.

A better evaluation method is fixed-case post-stage evaluation:

- define a fixed grid of initial conditions,
- run the same cases for every controller,
- compute case-level metrics,
- summarize performance after each stage,
- compare RL and baseline on identical cases.

For Furuta, the fixed evaluation cases should vary:

```matlab
theta2Error0
omega2Error0
```

and later also:

```matlab
theta1Error0
omega1Error0
```

## Logged Signals For Evaluation

The current Simulink model logs:

```text
action
observations
current_command
current
torque
omega1
omega2
theta1
theta2
voltage
torque_command
errors
isDone
reward
```

Expected vector order:

```matlab
errors       = [theta1Error; theta2Error; omega1Error; omega2Error]
observations = [theta1Error; theta2Error; omega1Error; omega2Error]
```

Useful interpretation:

- `errors`: pre-ZOH controller error at plant sample time,
- `observations`: post-ZOH agent observation,
- `action`: normalized policy output before rate adjustment,
- `torque_command`: post-rate-adjustment and gain scaling,
- `torque`: realized torque after PI/current-loop dynamics.

## Important Practical Issues

Fast Restart did not give a large speedup because most time is spent in RL block/policy execution and training overhead, not model compilation.

Simulink Data Inspector warnings can appear during training, especially in Live Editor. Closing and clearing SDI helped:

```matlab
close all
Simulink.sdi.close
Simulink.sdi.clear
```

For timing/debug runs:

```matlab
Plots = "none"
Verbose = false
StopTrainingCriteria = "EpisodeCount"
```

## Current Direction

The next important step is to test the fixed-case evaluation layer after a tiny training run or with a zero-action agent. After that, the project can move toward real curriculum training with post-stage evaluation.
