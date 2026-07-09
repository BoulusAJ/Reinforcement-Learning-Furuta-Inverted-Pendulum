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

## Planned Run 4 - 1d Near-Upright Scratch With I_meas

Prepared config:

```text
scripts/makeFurutaDetailed1d500HzNearUprightImeasScratchTD3Config.m
```

Prepared launcher:

```text
scripts/trainFurutaDetailed1d500HzNearUprightImeasScratch.m
```

Purpose:

This run tests the measured-current observation idea without network surgery.
It trains from scratch on the `1d` detailed model using an 8-element
observation vector:

```text
sin(theta1Error)
cos(theta1Error)
sin(theta2Error)
cos(theta2Error)
omega1Error
omega2Error
previousAction
I_meas
```

Initial plan:

| Setting | Value |
| --- | --- |
| Training model | `inv_rot_pen_RL_cntr_simscape_sim_1d_train` |
| Analysis model | `inv_rot_pen_RL_cntr_simscape_sim_1d_analysis` |
| Agent rate | 500 Hz |
| Initial agent | none, train from scratch |
| Episodes | 1500 |
| Reset theta1 error | `[-5, 5] deg` |
| Reset theta2 error | `[-5, 5] deg` |
| Reset omega1/omega2 error | `[-1, 1] rad/s` |
| Pendulum travel termination | enabled, `3*pi` rad from episode start |
| Upright timeout | enabled, terminate at `1.0 s` if not currently near upright |
| Upright reach tolerance | `15 deg` |

This is intentionally an upright-balance diagnostic, not the next long
swing-up run. If this cannot learn stable near-upright behavior, training a
long full swing-up policy on the same setup is unlikely to be useful.

## Run 4 - 1d Near-Upright Scratch With I_meas Results

Two 1d near-upright scratch attempts were run with the prepared `I_meas`
observation setup:

```text
results/TD3/run_20260706_102951_td3_mathworks_style_pi_current_1d_500hz_near_upright_imeas_scratch
results/TD3/run_20260706_155021_td3_mathworks_style_pi_current_1d_500hz_near_upright_imeas_scratch
```

Both used:

| Setting | Value |
| --- | --- |
| Training model | `inv_rot_pen_RL_cntr_simscape_sim_1d_train` |
| Analysis model | `inv_rot_pen_RL_cntr_simscape_sim_1d_analysis` |
| Agent rate | 500 Hz |
| Initial agent | none, train from scratch |
| Episodes | 1500 |
| Observation dimension | 8 |
| Added observation | `I_meas` |
| Reset theta1 error | `[-5, 5] deg` |
| Reset theta2 error | `[-5, 5] deg` |
| Reset omega1/omega2 error | `[-1, 1] rad/s` |
| Pendulum travel termination | enabled, `3*pi` rad from episode start |
| Upright timeout | enabled, terminate at `1.0 s` if not currently near upright |
| Upright tolerance | `15 deg` |
| Domain randomization | disabled |

Fixed-evaluation results:

| Run | Eval | FailureRate | MeanFinalTheta2MAE | MeanTheta2IAE | MeanElectricalAbsEnergy | MeanActionDiffRMS | Score |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `20260706_102951` | short_final | 1.000 | 2.164 rad | 1.810 | 0.599 | 0.027 | -1000 |
| `20260706_102951` | full_final | 1.000 | 2.208 rad | 2.015 | 3.078 | 0.069 | -1000 |
| `20260706_155021` | short_final | 1.000 | 1.426 rad | 0.624 | 0.228 | 0.016 | -1000 |
| `20260706_155021` | full_final | 1.000 | 1.683 rad | 0.540 | 0.313 | 0.014 | -1000 |

Interpretation:

The 1d `I_meas` scratch setup did not learn a usable near-upright balance
policy under the current reset and termination setup. The second attempt had
smaller theta2 error metrics than the first, but both failed all fixed
evaluation cases. This does not yet prove that `I_meas` is unhelpful; it may
instead mean that the scratch setup, reward, timeout, or reset distribution is
too harsh for learning useful upright stabilization from nothing.

## Hardware/Simulation Offset Observation

Across several detailed-model tests with the original `500Hz_long` agent, the
policy often appeared to settle with the arm away from zero:

```text
theta1 roughly 27 deg when current is scaled down
theta1 roughly 31.5 deg when current is not scaled down
```

This suggests that the deployed policy's practical upright operating region on
the detailed plant is not centered at `theta1 = 0`. The offset may be caused by
static friction, friction compensation, current scaling differences, actuator
dead zones, or the policy using arm angle bias to hold the pendulum upright.

For the next optimized retraining attempts, a more targeted reset distribution
is therefore reasonable:

```text
theta1 error:  [22, 42] deg
theta2 error:  [-5, 5] deg
omega1 error:  [-1, 1] rad/s
omega2 error:  [-1, 1] rad/s
```

This reset focuses learning near the region where the current `500Hz_long`
agent actually seems to balance on the detailed plant, rather than forcing the
first balancing experiment to also solve the theta1 centering problem.

## Next Proposed Retraining Tests

The next preferred test is to keep the original 7-observation vector with
`uPrev`, not `I_meas`, and continue from the original `500Hz_long` final agent:

```text
model: detailed 1d or latest detailed plant
agent rate: 500 Hz
initial agent: original 500Hz_long final agent
replay buffer: keep original buffer
episodes: about 2000
reset theta1 error: [22, 42] deg
reset theta2 error: [-5, 5] deg
reset omega1/omega2 error: [-1, 1] rad/s
```

Purpose:

This asks a narrow question: can the already-successful swing-up/balance agent
adapt its upright behavior to the detailed plant dynamics when started near the
region where it naturally settles?

If this improves balance, the next step is to adjust reward weighting near
upright, especially to reduce jitter and action variation. If it does not
improve much, run the same reset distribution from scratch to check whether the
detailed plant can learn balance at all under the current reward structure.

Only after these two tests should the observation be switched back to include
`I_meas`, because the 8-observation scratch attempts did not yet give a clear
positive signal.

Prepared config for this next test:

```text
scripts/makeFurutaDetailed1c500HzTheta1OffsetWarmTD3Config.m
```

Prepared launcher:

```text
scripts/trainFurutaDetailed1c500HzTheta1OffsetWarm.m
```

Important reset sign convention:

`localResetFcnFurutaCurriculum` sets `theta1_0 = -theta1Error0`. Therefore, to
start the physical arm angle near `+22..+42 deg`, the config uses:

```matlab
cfg.Training.Reset.Theta1ErrorRange = deg2rad([-42 -22]);
```

This run keeps:

```text
model: 1c detailed train/analysis files
observation dimension: 7
7th observation: previous action / uPrev
initial agent: original 500Hz_long final agent
replay buffer: kept from the loaded original agent
episodes: 2000
exploration noise std: 0.10
exploration noise min: 0.02
exploration noise decay: 2e-6
upright timeout: 1.0 s, must currently be within 15 deg of upright
```

Prepared zero-exploration smoke variant:

```text
scripts/makeFurutaDetailed1c500HzTheta1OffsetNoExploreSmokeTD3Config.m
scripts/trainFurutaDetailed1c500HzTheta1OffsetNoExploreSmoke.m
```

Purpose:

Check whether the loaded `500Hz_long` policy is already stable in the
theta1-offset reset region before allowing exploration or learning updates.

Key differences from the warm fine-tune:

```text
episodes: 100
exploration noise std/min: 0
replay buffer: reset
NumWarmStartSteps: larger than total smoke-run steps, to avoid network updates
Simulink Fast Restart: enabled for training
final evaluation: short only
```

Initial smoke-test observation:

The first attempt at this smoke test showed full 2500-step episodes for about
the first 45 episodes, then collapsed to mostly 500-step episodes. This strongly
suggested that the loaded `500Hz_long` policy was stable initially, but that
the loaded agent's saved TD3 options were still active and the config overrides
for zero exploration / huge warm-start were not being applied to the loaded
agent object.

Fix:

`trainFurutaDirectTD3WithConfig` now reapplies TD3 options from `cfg.Agent` to
loaded initial agents before training. The smoke test should print a line like:

```text
Applied TD3 options from cfg to loaded initial agent (...): ExplorationStd=0, ExplorationStdMin=0, NumWarmStartSteps=250001.
```

Rerun the smoke test after this fix. If it remains near 2500 steps throughout,
the earlier collapse was caused by training/exploration perturbing a working
policy, not by the reset region being impossible.

Follow-up gentle fine-tune prepared after the smoke test passed:

```text
scripts/makeFurutaDetailed1c500HzTheta1OffsetGentleTD3Config.m
scripts/trainFurutaDetailed1c500HzTheta1OffsetGentle.m
```

This keeps the same stable theta1-offset 1c setup but changes:

```text
replay buffer: reset
exploration noise std: 0.03
exploration noise min: 0.005
exploration noise decay: 2e-6
actor learning rate: 2e-4
critic learning rate: 5e-4
```

Purpose:

Adapt the already-stable loaded policy gently to the detailed plant's upright
friction/current behavior without immediately corrupting the working balance
policy.

## July 8 Presentation Snapshot - Recent Failed And Current Runs

This section summarizes the most recent training attempts for presentation
preparation. The main question is still:

```text
Can TD3 learn a controller that works on the more hardware-like detailed
model, especially under a 1.5 A current limit?
```

### Failed/Unsuccessful Attempts So Far

| Run | Model | Observation | Setup | Outcome |
| --- | --- | --- | --- | --- |
| `run_20260703_230817_td3_mathworks_style_pi_current_1c_500hz_long_detailed` | detailed `1c` | 7 obs, `uPrev` | 500 Hz, 5000 episodes, scratch, 4 A | Survived long episodes, but learned continuous swinging rather than clean capture/upright balance. |
| `run_20260704_015559_td3_mathworks_style_pi_current_1c_500hz_long_detailed` | detailed `1c` | 7 obs, `uPrev` | 500 Hz, 5000 episodes, fine-tuned from original `500Hz_long`, 4 A | Did not improve detailed-model behavior; fixed eval still had large final theta2 error. |
| `run_20260705_221352_td3_mathworks_style_pi_current_1c_500hz_long_detailed_near_upright` | detailed `1c` | 7 obs, `uPrev` | near-upright fine-tune from original `500Hz_long` | Initially improved, then collapsed around episodes `46-55`; final eval poor. |
| `run_20260706_102951...1d_500hz_near_upright_imeas_scratch` | detailed `1d` | 8 obs, added `I_meas` | near-upright scratch | Failed all fixed eval cases. |
| `run_20260706_155021...1d_500hz_near_upright_imeas_scratch` | detailed `1d` | 8 obs, added `I_meas` | near-upright scratch | Failed all fixed eval cases, although theta2 errors were smaller than the first 1d attempt. |
| `run_20260708_143303_td3_mathworks_style_pi_current_1c_500hz_theta1_offset_scratch` | detailed `1c` | 7 obs, `uPrev` | theta1-offset near-upright scratch, 2000 episodes, 1.5 A | Failed fixed eval; full eval `FailureRate = 1`, `MeanFinalTheta2MAE = 2.30 rad`. Training often ended around the 1 s / 500-step timeout. |
| `run_20260708_151229_td3_mathworks_style_pi_current_1b_500hz_theta1_offset_scratch_current_1p5` | simple `1b` | 7 obs, `uPrev` | theta1-offset near-upright scratch, 2000 episodes, 1.5 A | Failed fixed eval; full eval `FailureRate = 1`, `MeanFinalTheta2MAE = 1.48 rad`. The simple model looked less bad than detailed `1c`, but still not successful. |

Interpretation of the theta1-offset scratch failures:

- The 1 s upright timeout was probably too ambiguous for scratch learning.
  It is too harsh for recovery/swing-up behavior, but too lenient if the goal
  is pure local balance.
- With a 1.5 A current cap, the policy has much less authority than the
  original `500Hz_long` 4 A training setup.
- The inherited exploration noise was still large for a near-upright balance
  task:

  ```matlab
  cfg.Agent.ExplorationNoiseStd = 0.5;
  cfg.Agent.ExplorationNoiseStdMin = 0.05;
  ```

  At a 1.5 A action scale, this corresponds to roughly `0.75 A` standard
  deviation at the beginning of training.
- These failures do not prove that the detailed model is impossible. They show
  that the particular combination of scratch training, near-upright reset,
  strong exploration, current cap, and timeout was not a good learning setup.

### Current Long Scratch Attempts

Two longer scratch attempts were prepared to answer a simpler question:

```text
If we remove the special near-upright timeout and let TD3 train for much
longer, can it eventually learn useful behavior on the detailed model at
1.5 A?
```

#### Current Run A - Detailed 1c, 7 Observations

Prepared config:

```text
scripts/makeFurutaDetailed1c500HzLongScratch7000TD3Config.m
scripts/trainFurutaDetailed1c500HzLongScratch7000.m
```

Setup:

| Setting | Value |
| --- | --- |
| Training model | `inv_rot_pen_RL_cntr_simscape_sim_1c_train` |
| Analysis model | `inv_rot_pen_RL_cntr_simscape_sim_1c_analysis` |
| Observation dimension | 7 |
| Observation state | original sin/cos angles, raw omega, `uPrev` |
| Agent rate | 500 Hz |
| Episodes | 7000 |
| Current limit | `1.5 A` |
| Initial agent | none, train from scratch |
| Parallel workers | 22 |
| Fast Restart | enabled |
| Special upright timeout | not enabled |

Run command:

```matlab
addpath(genpath("scripts"));
trainFurutaDetailed1c500HzLongScratch7000
```

#### Current Run B - Detailed 1d, 8 Observations With I_meas

Prepared config:

```text
scripts/makeFurutaDetailed1d500HzLongImeasScratch7000TD3Config.m
scripts/trainFurutaDetailed1d500HzLongImeasScratch7000.m
```

Setup:

| Setting | Value |
| --- | --- |
| Training model | `inv_rot_pen_RL_cntr_simscape_sim_1d_train` |
| Analysis model | `inv_rot_pen_RL_cntr_simscape_sim_1d_analysis` |
| Observation dimension | 8 |
| Added observation | scaled/saturated measured current `I_meas` |
| Omega observation scaling | `cfg.Observation.OmegaScale = 25` |
| Agent rate | 500 Hz |
| Episodes | 7000 |
| Current limit | `1.5 A` |
| Initial agent | none, train from scratch |
| Parallel workers | 10 |
| Fast Restart | enabled |
| Special upright timeout | not enabled |

Observation notes:

```text
omega1_obs = saturate(omega1Error / cfg.Observation.OmegaScale, -1, 1)
omega2_obs = saturate(omega2Error / cfg.Observation.OmegaScale, -1, 1)
I_meas_obs = saturate(I_meas / cfg.Limits.CurrentMax, -1, 1)
```

The reward function was updated so this `1d` run can use scaled omega
observations while still computing reward and safety with approximately raw
rad/s values:

```matlab
cfg.Reward.ObservationUsesSinCos = true;
cfg.Reward.ObservationOmegaIsScaled = true;
cfg.Reward.ObservationOmegaScale = cfg.Observation.OmegaScale;
```

`I_meas` is currently not used directly by the reward; it is only part of the
agent observation.

Run command:

```matlab
addpath(genpath("scripts"));
trainFurutaDetailed1d500HzLongImeasScratch7000
```

### Result - Detailed 1c 7000-Episode Scratch Run

Run:

```text
results/TD3/run_20260708_222715_td3_mathworks_style_pi_current_1c_500hz_long_detailed_scratch7000
```

Final agent:

```text
results/TD3/run_20260708_222715_td3_mathworks_style_pi_current_1c_500hz_long_detailed_scratch7000/FurutaTD3_mathworks_style_pi_current_1c_500hz_long_detailed_scratch7000_final.mat
```

Setup:

| Setting | Value |
| --- | --- |
| Model | detailed `1c` |
| Observation dimension | 7 |
| Added current observation | no |
| Agent rate | 500 Hz |
| Episodes | 7000 / 7000 |
| Current limit | `1.5 A` |
| Initial agent | none, train from scratch |
| Fast Restart | enabled |
| Parallel workers | 22 |
| Special upright timeout | not enabled |

Training summary:

| Metric | Value |
| --- | ---: |
| Final episode reward | 1030.51 |
| Final episode steps | 2500 |
| Final average reward | 1046.25 |
| Best episode reward | 1500.04 at episode 3377 |
| Best average reward | 1279.68 at episode 6957 |
| Full-length episodes | 3847 / 7000 |
| Last 100 mean reward | 1076.19 |
| Last 100 mean steps | 2500 |
| Last 500 mean reward | 913.78 |
| Last 500 mean steps | 2471.66 |

Training progression by episode range:

| Episodes | Mean reward | Mean steps | Full-length episodes |
| --- | ---: | ---: | ---: |
| 1-500 | 22.6 | 79.0 | 0 / 500 |
| 501-1000 | 154.5 | 607.8 | 35 / 500 |
| 1001-2000 | 382.9 | 1204.1 | 288 / 1000 |
| 2001-3000 | 791.5 | 2443.1 | 975 / 1000 |
| 3001-4000 | 967.7 | 2326.0 | 866 / 1000 |
| 4001-5000 | 489.2 | 1459.8 | 330 / 1000 |
| 5001-6000 | 535.8 | 1710.2 | 505 / 1000 |
| 6001-7000 | 844.3 | 2228.4 | 848 / 1000 |

Evaluation:

| Eval | FailureRate | MeanFinalTheta2MAE | MeanTheta2IAE | MeanTheta2EndPeakToPeak | MeanActionDiffRMS | MeanElectricalAbsEnergy | Score |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| short_final | 0.000 | 1.563 rad | 7.861 | 6.256 rad | 0.0098 | 0.495 | -65.04 |
| full_final | 0.000 | 1.645 rad | 8.684 | 6.235 rad | 0.0096 | 0.512 | -68.37 |

Interpretation:

The run learned swing-up-like energy injection and survival, but not upright
capture and balance. From visual inspection, the policy appears able to swing
the pendulum up, but then it does not settle at the upright equilibrium.
Instead it continues into large oscillatory swings.

The fixed-evaluation metrics support that observation. The policy has
`FailureRate = 0`, so it stays inside the broad safety limits, but this is not
the same as balancing. The end-window peak-to-peak theta2 motion is almost one
full revolution:

```text
MeanTheta2EndPeakToPeak ~= 6.24 rad ~= 2*pi
```

That is consistent with repeated oscillatory swinging rather than stable
upright balance.

The low action-difference metric shows the final policy is relatively smooth:

```text
MeanActionDiffRMS ~= 0.0096
```

However, it is smoothly producing the wrong behavior. It learned a viable
low-current swinging strategy under the `1.5 A` cap, but the current reward
does not create enough pressure to capture and remain near upright after the
swing-up.

No intermediate checkpoint agents were saved because the config still used:

```matlab
cfg.Training.SaveAgentCriteria = "EpisodeReward";
cfg.Training.SaveAgentValue = 1800;
```

The best episode reward was `1500.04`, so only the final agent file exists.

Main takeaway:

```text
The detailed 1c model at 1.5 A can learn to swing up / keep the pendulum moving,
but the current training setup still fails at the balance-capture part.
```

### Planned Follow-Up - Capture Tune From Latest 1c Agent

Prepared config:

```text
scripts/makeFurutaDetailed1c500HzCaptureTuneFromScratch7000TD3Config.m
```

Prepared launcher:

```text
scripts/trainFurutaDetailed1c500HzCaptureTuneFromScratch7000.m
```

Purpose:

Continue from the latest detailed `1c` scratch7000 final agent and modify the
reward only enough to make upright capture and damping more valuable. The
starting agent already learned swing-up-like behavior, so this run should test
whether reward shaping can teach it to catch and stabilize instead of
continuing to oscillate.

Setup:

| Setting | Value |
| --- | --- |
| Initial agent | `run_20260708_222715...scratch7000` final agent |
| Model | detailed `1c` |
| Observation dimension | 7 |
| Current limit | `1.5 A` |
| Episodes | 2000 |
| Replay buffer | reset before fine-tuning |
| Exploration noise std/min | `0.08 / 0.01` |
| Actor/Critic learn rate | `2e-4 / 5e-4` |
| Fast Restart | enabled |
| Parallel workers | inherited from scratch7000 config, currently `22` |

Reward-shaping additions are opt-in through `cfg.Reward` fields so previous
runs keep their old reward behavior:

```matlab
cfg.Reward.EnableUprightCaptureShaping = true;
cfg.Reward.UprightCaptureAngle = deg2rad(25);
cfg.Reward.UprightCaptureTheta2Scale = deg2rad(10);
cfg.Reward.UprightCaptureOmega1Scale = 5;
cfg.Reward.UprightCaptureOmega2Scale = 5;
cfg.Reward.UprightCaptureBonusWeight = 0.8;
cfg.Reward.UprightCaptureTheta2Weight = 0.8;
cfg.Reward.UprightCaptureOmega1Weight = 0.05;
cfg.Reward.UprightCaptureOmega2Weight = 0.25;
cfg.Reward.UprightCaptureSmoothnessWeight = 0.1;
```

The added term uses a smooth upright-region weighting. It gives extra reward
near upright, but subtracts local theta2 error, omega2, omega1, and delta-action
costs. This is intended to preserve the learned swing-up behavior while making
the capture region more attractive than continuous oscillation.

Run command:

```matlab
addpath(genpath("scripts"));
trainFurutaDetailed1c500HzCaptureTuneFromScratch7000
```

### Working Hypotheses For The Presentation

- The original `500Hz_long` policy proves that TD3 can solve the simpler
  model/hardware-rate task, but the detailed model changes the learning
  landscape significantly.
- On the detailed model, the existing reward can still be exploited by
  survival/swinging behavior instead of upright capture.
- Fine-tuning a good existing policy with ordinary TD3 updates can damage the
  policy quickly, suggesting that residual learning or policy-preserving
  regularization may be more appropriate.
- The 1.5 A current limit is a major change from the original 4 A training
  setup and may require different exploration, reward scaling, or curriculum.
- Adding `I_meas` may improve the Markov property of the observation because
  the detailed model includes current-loop filtering, saturation, noise, and
  actuator dynamics.
- The next decision point is empirical: if either 7000-episode long run starts
  showing real capture/upright behavior, continue refining that path; if both
  again learn only swinging/survival, the reward/curriculum should be changed
  before spending more training time.

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

## Relevant Literature For Simple-To-Detailed And Sim-To-Real Transfer

The current detailed-model failures look less like "the agent needs more raw
training time" and more like a transfer/adaptation problem: a policy that works
on the simpler `500Hz_long` model can balance in some detailed-model reset
regions, but TD3 updates can quickly corrupt that behavior. The most relevant
research directions are therefore sim-to-real adaptation, progressive model
fidelity, residual learning, and policy-preserving fine-tuning.

Suggested reading order:

1. SimOpt / adaptive domain randomization

   Paper:
   [Closing the Sim-to-Real Loop: Adapting Simulation Randomization with Real World Experience](https://arxiv.org/abs/1810.05687)

   Why it matters here:
   Instead of guessing randomization ranges forever, the simulator
   randomization distribution is adapted using real-world rollouts. This is
   close to the desired workflow of collecting Furuta hardware data, adjusting
   the detailed model/randomization, and retraining.

2. Residual reinforcement learning

   Paper:
   [Residual Reinforcement Learning for Robot Control](https://arxiv.org/abs/1812.03201)

   Why it matters here:
   The old `500Hz_long` policy already has useful behavior. A residual policy
   could learn a small correction on top of that policy, especially near
   upright, instead of allowing TD3 to overwrite the whole working controller.
   This fits the current problem where fine-tuning damages an initially stable
   policy.

3. Robust policy training over model ensembles

   Paper:
   [EPOpt: Learning Robust Neural Network Policies Using Model Ensembles](https://arxiv.org/abs/1610.01283)

   Why it matters here:
   EPOpt trains policies to work across difficult sampled model variants. This
   is relevant once the nominal detailed model can learn balance and we start
   adding friction, current scaling, dead-zone, delay, and sensor
   randomization.

4. Multi-fidelity reinforcement learning

   Paper:
   [Multi-Fidelity Reinforcement Learning with Gaussian Processes](https://arxiv.org/abs/1712.06489)

   Why it matters here:
   This directly matches the idea of moving from cheap/simple models to more
   accurate/expensive models or hardware. The exact method may not be used in
   this MATLAB TD3 workflow, but the framing is useful for structuring
   experiments across simple simulation, detailed simulation, and hardware.

5. Meta-RL for fast adaptation

   Paper:
   [Learning to Adapt in Dynamic, Real-World Environments Through Meta-Reinforcement Learning](https://arxiv.org/abs/1803.11347)

   Why it matters here:
   This is less immediate than residual learning or SimOpt, but it is relevant
   if the final goal becomes a controller that can adapt online to changing
   friction, offsets, or actuator behavior.

6. Policy distillation and preserving old behavior

   Papers:
   [Policy Distillation](https://arxiv.org/abs/1511.06295) and
   [Learning without Forgetting](https://arxiv.org/abs/1606.09282)

   Why they matter here:
   The current fine-tuning collapse suggests the new training run should not be
   allowed to freely destroy the old policy. A practical version for this
   project could be an action-deviation penalty near upright, a teacher-policy
   regularization term, or a residual-action architecture.

Useful review papers:

- [Sim-to-Real Transfer in Deep Reinforcement Learning for Robotics: a Survey](https://arxiv.org/abs/2009.13303)
- [Robot Learning from Randomized Simulations: A Review](https://arxiv.org/abs/2111.00956)

Practical implication for the next Furuta experiments:

```text
Do not jump straight to broad domain randomization.
First preserve the working 500Hz_long behavior.
Then adapt it gently on the detailed model.
Then use hardware data to tune model/randomization ranges.
```

The most promising near-term ideas are residual learning, teacher-policy
regularization/action-deviation penalties, and much more conservative
fine-tuning. Domain randomization should come after the nominal detailed model
and reward structure produce clean upright balance.
