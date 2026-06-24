# Weinmann Meeting Prep - Furuta Inverted Pendulum

Date prepared: 2026-06-23  
Meeting focus: current Furuta RL status, hardware transfer, and next technical decisions.

## Who We Are Meeting

Dr. Thomas Oskar Weinmann is at ZHAW School of Engineering in the research focus area Scientific Computing and Algorithmics. His listed work/research foci are Machine Learning, Optimization, and Visual Computing, and he teaches machine learning at bachelor, master, and PhD level. His current listed projects include Raman for Process Analytics and Target Recognition using Artificial Intelligence (TRAI), and his project history includes Bayesian online regression on embedded systems, adaptive correction of magnetic scale distortion, and machine learning for NMR spectroscopy. Source: ZHAW profile, accessed 2026-06-23, https://www.zhaw.ch/de/ueber-uns/person/weto/.

Why this matters for the talk: he is likely strong on applied machine learning, optimization, embedded/algorithmic thinking, and the practical boundary between model detail and learned approximation. The best framing is not only "look, RL works", but "here is the evidence, here is the model mismatch, here is the decision we need help with."

## One-Minute Project Story

We are controlling a Furuta inverted pendulum with a TD3 actor trained in simulation. The action is a normalized scalar in [-1, 1]. For the hardware-oriented PI/current runs, that action maps to current command, not torque command, so the current path is:

```text
a_rl -> current scaling/clamp -> UART/SLDRT -> uC current PI loop -> motor
```

The best current practical result is that a simulation-trained 500 Hz PI/current TD3 policy was deployed on hardware and attempted lift-up. That is an important transfer result: signs, wrapping, observation scaling, and gross dynamics are not completely wrong. The remaining pain is upright jitter/current chatter and mismatch around real friction, dead zones, actuator limits, and possibly backlash-like effects.

## Current Controller Setup

Observation vector:

```text
1 sin(theta1Error)
2 cos(theta1Error)
3 sin(theta2Error)
4 cos(theta2Error)
5 omega1Error
6 omega2Error
7 previousAction
```

The angle sine/cosine representation avoids feeding a discontinuous wrapped scalar directly into the network. The scalar theta2 error is still used for reward/evaluation diagnostics.

Main deployed/compared runs:

| Run | Sample time | Command path | Current scale | Notes |
|---|---:|---|---:|---|
| `run_20260616_012625_td3_mathworks_style_wide` | 0.005 s / 200 Hz | PI/current or torque/current interface in original wide setup | 4 A equivalent | strongest 200 Hz baseline, full 297-case evaluation exists |
| `run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long` | 0.002 s / 500 Hz | explicit PI/current 1b path | 4 A | deployed on hardware, short eval plus debug subset committed |

Both use TD3, 64-unit default style networks, batch size 1024, two critics, target-policy smoothing, and a replay buffer. The 500 Hz long run has a larger buffer and longer training horizon.

## RL Configuration History: Before vs After MathWorks-Style

This is the compact version to remember for questions about "what exactly
changed?" The project did not only change one reward number. It changed the
task formulation, observation representation, training cadence, reset
distribution, and evaluation discipline.

### Pre-MathWorks-Style Phase 1: Near-Upright Stabilization

Representative DDPG run:

```text
results/DDPG/run_20260610_180340_upright_stabilization
```

Representative TD3 run:

```text
results/TD3/run_20260610_234307_td3_upright_stabilization
```

The early task was local stabilization around upright, not full swing-up.

| Item | Early DDPG | Early TD3 |
|---|---:|---:|
| plant sample time | 50 us / 20 kHz | 50 us / 20 kHz |
| agent sample time | 0.001 s / 1 kHz | 0.001 s / 1 kHz |
| episode duration | 1 s | 1 s |
| observation dimension | 4 | 4 |
| observation | theta1Error, theta2Error, omega1Error, omega2Error | same |
| action | normalized `a_rl` in [-1, 1] | same |
| physical scaling | 4 A or 0.39 Nm equivalent | same |
| mini-batch | 128 | 64 |
| replay buffer | 200k | 200k |
| learning frequency | 4 | 40 |
| target smooth factor | DDPG-specific | 0.005 |
| target policy noise | DDPG-specific | std 0.1, limit 0.3 |
| training mode | staged curriculum | staged curriculum |
| parallel training | false | false |
| stop criterion | average reward 450 | average reward 450 |

Early near-upright reward terms:

```text
theta2Scale      = 12 deg
theta1Scale      = 45 deg
velocityScale    = 10 rad/s
lambda_u         = 0.001
lambda_du        = 0.05
aliveBonus       = 0.1
uprightBonus     = 1.0
uprightTolerance = 5 deg
unsafePenalty    = 1000
```

Near-upright curriculum:

| Stage | Episodes | theta1 range | theta2 range | omega1 range | omega2 range | noise std |
|---|---:|---:|---:|---:|---:|---:|
| local_small_angle | 300 | 0 deg | +/-5 deg | 0 | +/-1 | 0.05 |
| medium_angle | 500 | 0 deg | +/-12 deg | 0 | +/-3 | 0.15 |
| robust_near_upright | 700 | 0 deg | +/-20 deg | 0 | +/-5 | 0.10 |

Why this was insufficient:

- the observation used raw wrapped angle errors, including the theta2 wrap
  discontinuity;
- the task was too local to become a swing-up controller;
- DDPG was fragile and produced high-frequency action patterns;
- TD3 was directionally better but still expensive/slow with the first update
  cadence;
- post-stage fixed evaluations were more revealing than training reward.

### Pre-MathWorks-Style Phase 2: Direct Swing-Up Curriculum

Representative run:

```text
results/TD3/run_20260611_163734_td3_direct_swingup
```

This was the first main direct swing-up formulation. It already contained two
important improvements that stayed later:

- the 7-dimensional sine/cosine observation;
- a normalized action with current/torque scaling outside the agent.

Direct swing-up TD3 config:

| Item | Value |
|---|---:|
| algorithm | TD3 |
| plant sample time | 50 us / 20 kHz |
| agent sample time | 0.001 s / 1 kHz |
| episode duration | 5 s |
| observation dimension | 7 |
| mini-batch | 1024 |
| replay buffer | 1e6 |
| warm start steps | 1024 |
| epochs per update | 10 |
| max mini-batches per epoch | 100 |
| policy update frequency | 2 |
| target update frequency | 2 |
| target smooth factor | 0.005 |
| target policy noise | std 0.2, limit 0.5 |
| exploration noise | std 0.5, min 0.05, decay 1e-6 |
| actor learn rate | 0.002 |
| critic learn rate | 0.005 |
| gradient threshold | 1 |
| device | GPU in saved run |
| parallel training | false |
| stop criterion | average reward 450 |

Direct swing-up observation:

```text
1 sin(theta1Error)
2 cos(theta1Error)
3 sin(theta2Error)
4 cos(theta2Error)
5 omega1Error
6 omega2Error
7 previousAction
```

Direct swing-up reward, as saved in the representative run:

```text
theta2Scale      = 45 deg
theta1Scale      = 90 deg
velocityScale    = 20 rad/s
lambda_u         = 0.001
lambda_du        = 0.03
duWarmupSteps    = 1
aliveBonus       = 0.1
uprightBonus     = 1.0
uprightTolerance = 8 deg
unsafePenalty    = 1000
```

Direct swing-up staged reset distribution:

| Stage | Episodes | theta1 range | theta2 range | omega1 range | omega2 range | noise std |
|---|---:|---:|---:|---:|---:|---:|
| near_upright_stabilization | 800 | 0 deg | +/-5 deg | 0 | +/-1 | 0.10 |
| medium_upright_recovery | 500 | +/-10 deg | +/-25 deg | +/-2 | +/-5 | 0.20 |
| large_angle_recovery | 1000 | +/-20 deg | +/-90 deg | +/-5 | +/-10 | 0.30 |
| full_swingup | 2000 | +/-45 deg | +/-180 deg | +/-8 | +/-12 | 0.35 |

Why this still struggled:

- the curriculum changed the distribution substantially between stages;
- replay and critics could carry information from a different task region;
- the reward and stop criterion were still not aligned with broad fixed-case
  swing-up quality;
- it was hard to separate "learning failed" from "training setup is too
  complicated."

### Post-MathWorks-Style Baseline: 200 Hz Wide TD3

Representative run:

```text
results/TD3/run_20260616_012625_td3_mathworks_style_wide
```

This is the first clearly useful baseline. The big conceptual changes were:

- no staged curriculum;
- one fixed random reset distribution;
- MathWorks QUBE-like TD3 structure;
- survival-style reward with a single broad objective;
- async parallel training;
- CPU learner after local CPU/GPU timing checks;
- short and full fixed evaluation after training.

Config summary:

| Item | Value |
|---|---:|
| algorithm | TD3 |
| network style | default MATLAB TD3, 64 hidden units |
| plant sample time | 50 us / 20 kHz |
| agent sample time | 0.005 s / 200 Hz |
| episode duration | 5 s |
| max episodes | 3000 |
| observation dimension | 7 |
| action range | normalized [-1, 1] |
| action interface | torque_or_current |
| current scale | 4 A |
| torque scale | 0.39 Nm |
| mini-batch | 1024 |
| replay buffer | 1e6 |
| warm start steps | 1024 |
| epochs per update | 10 |
| max mini-batches per epoch | 100 |
| policy update frequency | 2 |
| target update frequency | 2 |
| target smooth factor | 0.005 |
| target policy noise | std 0.2, limit 0.5 |
| exploration noise | std 0.5, min 0.05, decay 1e-6 |
| actor learn rate | 0.002 |
| critic learn rate | 0.005 |
| gradient threshold | 1 |
| device | CPU |
| parallel training | true, async |
| requested workers | 22 |
| steps until data sent | 1000 |
| stop criterion | none |
| save agent criterion | episode reward >= 700 |

Wide single-run reset distribution:

```text
theta1Error0 in +/-45 deg
theta2Error0 in +/-90 deg
omega1Error0 in [-2, 2] rad/s
omega2Error0 in [-2, 2] rad/s
```

MathWorks-style reward mode:

```text
RewardMode             = 2
theta2Weight           = 1.0
theta2Scale            = 15 deg
theta1Weight           = 0.1
theta1Scale            = 30 deg
omega1Weight           = 0.05
omega1Scale            = 5 rad/s
omega2Weight           = 0.02
omega2Scale            = 5 rad/s
lambda_u               = 0.001
lambda_du              = 0.03
aliveReward            = 1.0
costWeight             = 0.1
angularVelocityWeight  = 0.01
actionSmoothnessWeight = 0.3
aliveTheta1Limit       = 90 deg
aliveOmega1Limit       = 30 rad/s
uprightBonus           = 0.2
uprightTolerance       = 8 deg
unsafePenalty          = 10
```

In simplified form, the intended reward shape is:

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

where `F` is the survival term. This made learning much more stable, but small
near-upright oscillations were still cheap relative to survival.

### Post-MathWorks-Style Hardware-Oriented Variant: 500 Hz PI/Current Long

Representative run:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

This keeps the successful MathWorks-style wide idea but makes it closer to the
hardware interface:

- explicit PI/current 1b Simulink model path;
- 500 Hz agent sample time;
- current command as the physical interface;
- longer run and larger replay buffer.

Config summary:

| Item | Value |
|---|---:|
| algorithm | TD3 |
| network style | default MATLAB TD3, 64 hidden units |
| plant sample time | 50 us / 20 kHz |
| agent sample time | 0.002 s / 500 Hz |
| episode duration | 5 s |
| max episodes | 5000 |
| observation dimension | 7 |
| action range | normalized [-1, 1] |
| action interface | current |
| current scale | 4 A |
| torque scale | 0.39 Nm |
| mini-batch | 1024 |
| replay buffer | 2.5e6 |
| warm start steps | 2500 |
| epochs per update | 10 |
| max mini-batches per epoch | 100 |
| policy update frequency | 2 |
| target update frequency | 2 |
| target smooth factor | 0.005 |
| target policy noise | std 0.2, limit 0.5 |
| exploration noise | std 0.5, min 0.05, decay 1e-6 |
| actor learn rate | 0.002 |
| critic learn rate | 0.005 |
| gradient threshold | 1 |
| device | CPU |
| parallel training | true, async |
| requested workers | 22 |
| steps until data sent | 2500 |
| stop criterion | none |
| save agent criterion | episode reward >= 1800 |

The reset distribution and reward weights are intentionally the same family as
the 200 Hz wide baseline:

```text
theta1Error0 in +/-45 deg
theta2Error0 in +/-90 deg
omega1Error0 in [-2, 2] rad/s
omega2Error0 in [-2, 2] rad/s
```

The important hardware-scaling interpretation:

```text
a_rl in [-1, 1]
I_cmd = 4 A * a_rl
```

Then `I_cmd` should still pass through the hardware safety clamp. If a smaller
current limit such as +/-0.5 A is used during hardware testing, that is a
deployment safety modification unless the same limit is included during
training or evaluation.

### Clean Summary Of What Changed

| Aspect | Pre-MathWorks near-upright | Pre-MathWorks direct swing-up | Post-MathWorks wide / PI-current |
|---|---|---|---|
| task | local upright stabilization | staged swing-up curriculum | one broad no-curriculum task |
| observation | 4 raw errors | 7 sin/cos + velocities + previousAction | same 7-observation form |
| sample time | 1 kHz agent | 1 kHz agent | 200 Hz baseline, then 500 Hz hardware-oriented |
| episode length | 1 s | 5 s | 5 s |
| reward style | custom bonus/penalty | custom scaled swing-up reward | MathWorks-style survival minus weighted cost |
| reset design | staged local upright | staged widening swing-up | one fixed random distribution |
| evaluation lesson | post-stage eval exposed failure | fixed cases exposed fragility | short/full fixed eval became central |
| main weakness | DDPG/TD3 local fragility | curriculum/replay/reward complexity | robustness and near-upright jitter |

### LearningFrequency And Update Cadence

The switch to `LearningFrequency = -1` happened on 2026-06-11, when the project
moved from near-upright TD3 into the direct swing-up TD3 setup. This was before
the later MathWorks-style runs. The MathWorks-style runs inherited the same
episode-end learning cadence.

Evidence in the saved results:

| Phase | Representative run | LearningFrequency |
|---|---|---:|
| early DDPG | `results/DDPG/run_20260609_*_upright_stabilization` | 1 |
| later DDPG debug | `results/DDPG/run_20260610_180340_upright_stabilization` | 4 |
| early TD3 debug | `results/TD3/run_20260610_190xxx_td3_upright_stabilization` | 4 |
| later TD3 near-upright | `results/TD3/run_20260610_234307_td3_upright_stabilization` | 40 |
| direct swing-up TD3 | `results/TD3/run_20260611_121014_td3_direct_swingup` and later | -1 |
| MathWorks-style TD3 | `results/TD3/run_20260616_012625_td3_mathworks_style_wide` | -1 |
| 500 Hz PI/current long | `results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long` | -1 |

Meaning:

```text
LearningFrequency = N:
    learn every N agent steps, after warm start is satisfied

LearningFrequency = -1:
    collect the rollout, then learn at episode end
```

For Simulink/hardware-oriented training, `-1` is attractive because it avoids
interrupting the plant rollout every few simulated milliseconds. It also makes
the policy fixed during each episode, which is easier to reason about for an
unstable system.

The rough upper bound for mini-batch gradient updates is:

```text
updates per learning event = NumEpoch * MaxMiniBatchPerEpoch
```

For our direct swing-up and MathWorks-style TD3 settings:

```text
NumEpoch = 10
MaxMiniBatchPerEpoch = 100
updates per episode-end event <= 1000
```

Each update uses one mini-batch:

```text
MiniBatchSize = 1024
```

So one episode-end learning event can use up to:

```text
1000 updates * 1024 samples/update = 1,024,000 sampled transition usages
```

These are sampled transition usages, not necessarily unique transitions, because
replay-buffer sampling can reuse transitions.

For TD3, critic updates happen at each mini-batch update. The actor updates
less often:

```text
PolicyUpdateFrequency = 2
```

So, as a simple upper-bound mental model:

```text
1000 critic update steps -> about 500 actor update steps
```

#### Update Upper Bounds Before `LearningFrequency = -1`

The early high-frequency learning settings explain why training became slow
once episodes survived longer.

Early DDPG, `LearningFrequency = 1`:

```text
agent Ts = 0.001 s
episode duration = 1 s
steps per full episode = 1000
learning events per full episode ~= 1000 / 1 = 1000
```

Saved DDPG config did not use the later `NumEpoch = 10` fields in the same way,
so the practical estimate is one mini-batch update per learning event:

```text
upper-bound estimate ~= 1000 mini-batch updates per full 1 s episode
MiniBatchSize = 128
sample usages ~= 128,000 per full episode
```

Later DDPG / early TD3 debug, `LearningFrequency = 4`:

```text
agent Ts = 0.001 s
episode duration = 1 s
steps per full episode = 1000
learning events per full episode ~= 1000 / 4 = 250
```

If interpreted with one mini-batch update per event:

```text
upper-bound estimate ~= 250 mini-batch updates per full 1 s episode
MiniBatchSize = 128
sample usages ~= 32,000 per full episode
```

For TD3, the MathWorks off-policy options can also allow multiple mini-batches
per learning event. The reference-comparison note used the conservative upper
bound:

```text
learning events * NumEpoch * MaxMiniBatchPerEpoch
```

If `NumEpoch = 1` and `MaxMiniBatchPerEpoch = 100`, then the same
`LearningFrequency = 4` case could be bounded as:

```text
250 events * 1 epoch * 100 mini-batches = 25,000 mini-batch updates per episode
```

This is a worst-case option-level bound, not necessarily what happened in every
saved run, but it explains why frequent in-episode TD3 learning could become
very expensive.

Later TD3 near-upright, `LearningFrequency = 40`:

```text
agent Ts = 0.001 s
episode duration = 1 s
steps per full episode = 1000
learning events per full episode ~= 1000 / 40 = 25
```

With the same option-level bound:

```text
25 events * 1 epoch * 100 mini-batches = 2500 mini-batch updates per episode
```

This is why `LearningFrequency = 40` was introduced: it reduced the in-episode
TD3 update pressure by about 10x relative to `LearningFrequency = 4`, while
keeping the controller sample time at 1 kHz.

With `LearningFrequency = -1`, the learning work is concentrated after the
episode:

```text
1 learning event per episode * 10 epochs * 100 mini-batches
= 1000 mini-batch updates per episode
```

For the 200 Hz wide run:

```text
episode duration = 5 s
agent Ts = 0.005 s
steps per full episode = 1000
max episodes = 3000
max update upper bound ~= 3000 * 1000 = 3,000,000 mini-batch updates
```

For the 500 Hz long run:

```text
episode duration = 5 s
agent Ts = 0.002 s
steps per full episode = 2500
max episodes = 5000
max update upper bound ~= 5000 * 1000 = 5,000,000 mini-batch updates
```

The first episode or early part of training may not update fully because of
warm start:

```text
200 Hz wide: NumWarmStartSteps = 1024
500 Hz long: NumWarmStartSteps = 2500
```

So these numbers are best treated as planning upper bounds, not exact update
counts.

### When The Observation Changed To Sin/Cos

The observation changed to the sine/cosine angle representation on 2026-06-11
with the direct swing-up TD3 formulation. This was also before the later
MathWorks-style runs.

Before that, the near-upright DDPG/TD3 configs used four raw local errors:

```text
theta1Error
theta2Error
omega1Error
omega2Error
```

The direct swing-up branch changed the observation to:

```text
sin(theta1Error)
cos(theta1Error)
sin(theta2Error)
cos(theta2Error)
omega1Error
omega2Error
previousAction
```

Reason:

- `theta2Error` is wrapped to `[-pi, pi]`;
- the scalar wrapped error has a discontinuity at the downward position;
- sine/cosine gives the network a continuous global angle representation;
- `previousAction` helps make the action-smoothness penalty and actuator
  dynamics more Markov-like.

## What TD3 Is, In Applied Terms

TD3 means Twin Delayed Deep Deterministic Policy Gradient. In plain language:

- it learns a deterministic actor, which maps the current observation to one continuous action,
- it learns two critics, which estimate how good an observation/action pair is,
- using two critics reduces over-optimistic value estimates,
- the actor is updated less frequently than the critics, which improves stability,
- target policy noise smooths the critic target and discourages brittle sharp action choices.

For deployment, only the actor is needed. The critics are training-only. This is why the policy can be exported as a small feedforward network and used in SLDRT or on the Nucleo.

## Why The Earlier Non-MathWorks-Style Approach Probably Failed

This is a good question for Weinmann. Our working hypothesis:

- reward scale and survival terms were too weak or inconsistent, so training reward did not guide the controller toward the desired swing-up/stabilize behavior,
- staged curriculum changes may have made replay/critic information less coherent,
- the training loop was too slow/fragile before we adopted the cleaner MathWorks-style TD3 structure,
- fixed evaluation showed that episode survival and average training reward were not enough,
- the actuator interface and model feedback path were not separated cleanly enough early on.

The MathWorks-style setup did not magically solve RL; it gave a stable baseline: no curriculum, fixed reset distribution, bigger batch, async parallel training, standard TD3 settings, and fixed-case evaluation.

## Evidence We Have Now

### 200 Hz Wide Agent

Full fixed evaluation:

| Metric | Value |
|---|---:|
| cases | 297 |
| failure rate | 14.5% |
| mean final theta2 MAE | 7.23 deg |
| max final theta2 error | 180.00 deg |
| mean theta2 IAE | 1.133 |

All 43 failures were arm-limit failures in the earlier analysis. The useful interpretation is: the controller can swing up and stabilize many cases, but it is not yet a robust control-law with clean arm management.

### 500 Hz Long PI/Current Agent

Short fixed evaluation:

| Metric | Value |
|---|---:|
| cases | 7 |
| failure rate | 0.0% |
| mean final theta2 MAE | 0.000004 deg |
| mean theta2 IAE | 0.532 |
| mean action diff RMS | 0.0300 |
| mean action end oscillation frequency | 85.8 Hz |

The short eval looks excellent at final theta2, but its theta2 IAE, action-difference energy, electrical effort, and final theta1 bias are larger than the 200 Hz short eval. That aligns with the hardware observation: the policy has authority and can lift, but it may use aggressive/high-frequency action near upright.

### 200 Hz vs 500 Hz Evidence Caveat

The committed evidence is not symmetric. The 200 Hz run has a full 297-case evaluation. The 500 Hz long run currently has the short 7-case evaluation plus a missing-cases debug subset. Therefore, we can say:

- on the shared 7 short upright cases, both pass,
- the 500 Hz long policy ends almost exactly upright in simulation but has larger transient/effort metrics,
- the exact claim "500 Hz long fails from theta = (0,0) in simulation while 200 Hz succeeds" is not fully verified by a matching committed 297-case CSV for the 500 Hz run,
- the debug subset contains 13 cases and 1 failed case(s); the failed debug case is Case 95, with theta1Error0=-45.0 deg and theta2Error0=180.0 deg.

For tomorrow: present this as an open evidence issue, not as a settled conclusion.

## Model vs Hardware Test 1

Open-loop diagnostic:

```text
I_cmd = 0.2 A
enable = 1 at start
enable = 0 at t = 0.8 s
duration = 4 s
```

Current interpretation from the quick comparison:

- signs and conventions look consistent,
- until 0.8 s, hardware and analytical model have similar general behavior,
- omega2 absolute speed is slightly higher in the model than hardware,
- omega1 also differs by roughly 1-10 percent up to the peak at 0.8 s,
- after disable, trajectories diverge more strongly, plausibly because real motor/friction/stiction/slip-ring effects are not captured well enough.

This test is useful because it separates policy quality from plant mismatch.

## Why Jitter Is Happening, Most Likely

Near-upright jitter can come from several overlapping sources:

- reward does not punish small oscillation/current chatter strongly enough near upright,
- the policy learned to use saturation because it was rewarded for capture more than smoothness,
- real static friction/dead zone creates a stick-slip behavior not seen in the model,
- current loop dynamics, filtering, and sample-rate details differ between simulation and hardware,
- previousAction and command scaling must match exactly between training and deployment,
- a limiter can reduce hardware strain but also changes the effective policy/plant pair.

The observation that scaling the 200 Hz policy by about `param.km*0.4` reduced jitter, and that limiting the 500 Hz long policy to +/-0.5 A reduced strain, suggests the learned controller has too much effective high-frequency authority near upright.

## Recommended Next Step

My recommendation remains: domain randomization first, then structured hardware data collection, then residual dynamics only if needed.

Why domain randomization first:

- it is safer than online hardware learning,
- it directly targets the mismatch problem seen in hardware,
- it forces the policy to work across a family of plants instead of memorizing one nominal model,
- it can include friction, damping, current gain, delay, low-pass frequency, sensor noise, dead zone, and encoder offset,
- it creates a clean before/after comparison for Weinmann or the thesis.

Hardware logging is still useful, but initially as evidence and model-diagnostic data, not as a replay-buffer dump. A 60-100 s disrupted hardware log can help estimate friction/dead zones, validate state coverage, and later support residual dynamics. It should be segmented by motor enable and safety state.

## What Residual Learning Would Mean Here

Residual dynamics learning does not mean "train another controller to fix the controller." It means learning the mismatch between model prediction and measured hardware transition:

```text
residual = x_next_hardware - x_next_simulation
x_next_corrected = f_model(x, u) + residual_model(x, u)
```

Then the main RL agent can be retrained or fine-tuned in the corrected simulator. This is useful after we can collect clean, synchronized, varied hardware transitions. It is probably step 2 or 3, not tomorrow's first fix.

## Demo Suggestion For Tomorrow

Best demo order:

1. show the hardware video/live short attempt if safe, especially the attempted lift-up,
2. show the model-vs-hardware Test 1 overlay to prove we are diagnosing mismatch,
3. show the 200 Hz vs 500 Hz short metrics and explain the evidence caveat,
4. show the planned next experiment: domain-randomized retraining plus conservative hardware validation.

Avoid claiming solved balance. The honest line is stronger: "we have transfer, now we need robustness and smoothness."
