# Detailed Model Training Results - 2026-07-05

This note records the first completed 500 Hz TD3 training attempts on the
new detailed `1c` model path on PC `5011`.

The goal was to understand the nominal detailed model before adding domain
randomization.

## Setup

Config:

```text
scripts/makeFurutaMathWorksStylePICurrent1c500HzLongDetailedTD3Config.m
```

Launcher:

```text
scripts/trainFurutaDirectTD3MathWorksStylePICurrent1c500HzLongDetailed.m
```

Models:

```text
training: scripts/inv_rot_pen_RL_cntr_simscape_sim_1c_train.slx
analysis: scripts/inv_rot_pen_RL_cntr_simscape_sim_1c_analysis.slx
```

Domain randomization was disabled:

```matlab
cfg.DomainRandomization.Enabled = false;
```

The first run trained from scratch. The second run fine-tuned from the original
deployed 500 Hz long final agent:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

## Run 1 - Detailed Model From Scratch

Run:

```text
results/TD3/run_20260703_230817_td3_mathworks_style_pi_current_1c_500hz_long_detailed
```

Training:

| Metric | Value |
| --- | ---: |
| Initial agent | no |
| Episodes | 5000 / 5000 |
| Final episode reward | 1250.57 |
| Final episode steps | 2500 |
| Final average reward | 1278.94 |
| Mean episode steps | 1804.84 |
| Median episode steps | 2500 |
| First full-length episode | 747 |
| Best average reward | 1357.31 at episode 4982 |
| Last 1000 mean reward | 1211.43 |
| Last 1000 mean steps | 2497.09 |
| Last 800 mean reward | 1210.26 |
| Last 800 mean steps | 2496.36 |

Timestamp-derived wall-clock:

```text
run folder/config creation: 2026-07-03 23:08
training log final write:   2026-07-04 01:55
approximate elapsed:        2 h 47 min
```

Evaluation:

| Eval | FailureRate | MeanFinalTheta2MAE | MeanTheta2IAE | MeanElectricalAbsEnergy | MeanActionDiffRMS | Score |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| short_final | 0.000 | 1.317 rad | 6.372 | 79.12 | 0.173 | -55.38 |
| full_final | 0.010 | 1.325 rad | 6.742 | 75.81 | 0.171 | -65.70 |

Interpretation:

The run learned to survive full-length episodes, but the fixed evaluation shows
it did not learn clean upright balance. The large `MeanFinalTheta2MAE` around
`1.3 rad` means the policy gets reward mainly by staying alive while repeatedly
swinging rather than capturing and stabilizing upright.

## Run 2 - Fine-Tune From Original 500 Hz Long Agent

Run:

```text
results/TD3/run_20260704_015559_td3_mathworks_style_pi_current_1c_500hz_long_detailed
```

Training:

| Metric | Value |
| --- | ---: |
| Initial agent | original 500 Hz long final agent |
| Episodes | 5000 / 5000 |
| Final episode reward | 1210.93 |
| Final episode steps | 2500 |
| Final average reward | 1252.48 |
| Mean episode steps | 2313.97 |
| Median episode steps | 2500 |
| First full-length episode | 2 |
| Best average reward | 1612.32 at episode 11 |
| Last 1000 mean reward | 1267.64 |
| Last 1000 mean steps | 2499.22 |
| Last 800 mean reward | 1277.00 |
| Last 800 mean steps | 2499.02 |

Timestamp-derived wall-clock:

```text
run folder/config creation: 2026-07-04 01:56
training log final write:   2026-07-05 08:57
approximate elapsed:        31 h 01 min
```

This timestamp-derived duration may include idle, sleep, or waiting time. The
observed active training time may have been closer to the user's estimate of
several hours. The log itself does not contain per-line timestamps, so this is
the closest available timing from files.

Evaluation:

| Eval | FailureRate | MeanFinalTheta2MAE | MeanTheta2IAE | MeanElectricalAbsEnergy | MeanActionDiffRMS | Score |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| short_final | 0.000 | 1.378 rad | 6.606 | 116.12 | 0.229 | -57.03 |
| full_final | 0.000 | 1.355 rad | 6.895 | 104.48 | 0.212 | -57.15 |

Interpretation:

Fine-tuning from the original 500 Hz long final agent did not solve the
detailed-model problem. It survived essentially all episodes and had full-grid
`FailureRate = 0`, but the final pendulum error remained very large. It also
used more electrical effort and action variation than the from-scratch detailed
run.

## Main Finding

Both runs plateaued in the final training phase:

- the final 800-1000 episodes were mostly full-length,
- average reward remained around `1200-1300`,
- fixed evaluation still showed large final theta2 error,
- qualitative inspection indicated continuous swinging rather than proper
  swing-up capture and balance.

The current detailed-model reward/training setup therefore appears to have a
bad local solution:

```text
survive by continuously swinging the pendulum
```

rather than:

```text
swing up, capture upright, and stabilize.
```

The alive/survival reward is likely too easy to exploit on the detailed model,
or the detailed dynamics make the previous reward balance insufficient.

## Run 3 - Near-Upright Fine-Tune With Extra Termination

Run:

```text
results/TD3/run_20260705_221352_td3_mathworks_style_pi_current_1c_500hz_long_detailed_near_upright
```

Config:

```text
scripts/makeFurutaDetailed1c500HzNearUprightTD3Config.m
```

Purpose:

This was a shorter diagnostic run to check whether the detailed `1c` model can
be recovered from near-upright initial conditions before trying another full
swing-up training run.

Setup:

| Setting | Value |
| --- | --- |
| Model | detailed `1c` |
| Agent rate | 500 Hz |
| Initial agent | original `500Hz_long` final agent |
| Initial replay buffer | reset before training |
| Episodes | 1000 |
| Reset theta1 error | `[-5, 5] deg` |
| Reset theta2 error | `[-5, 5] deg` |
| Reset omega1/omega2 error | `[-1, 1] rad/s` |
| Pendulum travel termination | enabled, `3*pi` rad from episode start |
| Upright reach timeout | enabled, terminate if upright not reached by `3.0 s` |
| Upright reach tolerance | `15 deg` |

Training behavior:

- The loaded policy initially looked promising: episode reward rose from about
  `569` on episode 1 to `1800+` by around episode 20.
- Around episodes `46-55`, the reward collapsed sharply into short,
  low-reward episodes.
- The run later recovered only to a much lower plateau, mostly in the
  `400-600` reward range near the end.
- The final episode reward was `529.14`, with `2500` steps and final average
  reward `443.52`.

Evaluation:

| Eval | FailureRate | MeanFinalTheta2MAE | MeanTheta2IAE | MeanElectricalAbsEnergy | MeanActionDiffRMS | Score |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| short_final | 0.429 | 2.383 rad | 8.117 | 165.96 | 0.347 | -478.56 |
| full_final | 0.859 | 2.432 rad | 7.382 | 135.69 | 0.362 | -871.47 |

Interpretation:

This run did not produce a usable near-upright stabilizer. It is still useful
because it shows that direct fine-tuning from the old `500Hz_long` policy can
damage the initially good behavior under the detailed model. The early reward
rise followed by collapse suggests the loaded policy is not being adapted
gently enough, or that the current observation/reward still hides important
actuator state.

The result supports trying measured current in the observation:

```text
i_meas
```

The detailed model has current-loop filtering, saturation, measurement noise,
and actuator dynamics. The old observation uses previous action, but that may
not be enough Markov information for the detailed plant. Adding `i_meas` may
help the policy and critic distinguish commanded effort from delivered current.

Important caveat:

Adding `i_meas` changes the observation dimension. The original `500Hz_long`
agent cannot be loaded directly into the new observation shape without either
training from scratch or doing network surgery to copy the old 7-input weights
and initialize the new current input.

## Current Concerns

The detailed-model path failed more strongly than expected. Possible reasons:

- the detailed actuator/sensor dynamics changed the task enough that the old
  reward no longer guides capture,
- the alive reward allows a swinging survival behavior to plateau,
- delayed/current-loop dynamics may make `uPrev` insufficient for Markov state,
- the observation may need measured current `i_meas`, current command, or both,
- the network may need more capacity for the detailed model, although reward
  and state issues should be checked before increasing network size,
- the current velocity scaling/observation scaling may be poorly matched to
  the detailed measured-velocity path.

## Candidate Next Steps

Do not add domain randomization yet. First make the nominal detailed model
learn the intended task.

Possible next experiments:

1. Remove or rethink the alive reward.

   The current runs show the agent can become satisfied with staying alive
   while swinging. A reward variant should put stronger pressure on upright
   capture and final stabilization.

2. Add measured current to the observation.

   Candidate observation additions:

   ```text
   i_meas
   current command / u
   both i_meas and u
   ```

   This may improve Markov state under current-loop dynamics, delays, and
   actuator filtering.

3. Add a rotation-count termination condition.

   Terminate if the pendulum makes unreasonable repeated rotations, for
   example beyond `1.5` full rotations. A stricter alternative is to terminate
   after crossing beyond `+/-pi`, but this may be too harsh for swing-up.

   These rotation-count variables do not necessarily need to be part of the
   agent observation. They can be safety/isDone diagnostics.

4. Run a shorter upright-balance-only test.

   Train or fine-tune for about `1000` episodes from near upright. This checks
   whether the detailed model can learn balance at all before asking it to
   learn swing-up.

5. Revisit velocity scaling.

   Scale measured velocities in the observation so they usually lie near
   `[-1, 1]`. The detailed model's measured velocity path may have different
   statistics from the previous ideal/analytical path.

6. Consider network size only after reward/state checks.

   A larger network may be necessary for the detailed model, but increasing
   capacity before fixing the alive-reward loophole may simply learn the same
   swinging behavior more strongly.

7. Add measured current to the observation, with gentler fine-tuning.

   The near-upright fine-tune suggests the old policy can be degraded quickly
   when adapted to the detailed model. A next controlled attempt should include
   `i_meas` as an additional observation, likely together with lower
   fine-tuning learning rates and reduced exploration noise. If warm-starting
   from the old agent is desired, network surgery is needed because the
   observation dimension changes.

## Recommendation

Before domain randomization, run a controlled nominal detailed-model follow-up:

```text
500 Hz detailed 1c model
same baseline actor/critic initially
reward adjusted to prevent alive-only swinging
optionally add i_meas and/or current command to observation
short upright-balance-only sanity run first
then full swing-up training
```

Only after the nominal detailed model learns proper capture and balance should
domain randomization be added gradually.
