# Slide Bullet Points

## Slide 1 - Title

Reinforcement Learning for the Furuta Inverted Pendulum

- Goal: train and deploy an RL controller for swing-up and upright balance.
- Method: TD3, trained in Simulink/MATLAB.
- Final status: simulation-trained policy reached real hardware swing-up
  attempts; robust low-jitter balance remains open.

## Slide 2 - What Started The Project

- Start from a real Furuta inverted pendulum setup at ZHAW.
- Learn a controller that can swing up and balance the pendulum.
- Explore whether model-free or grey-box RL can reduce manual controller
  design effort.
- Build a workflow that can be handed over: configs, results, scripts,
  documentation.

## Slide 3 - System And Control Path

- Plant: rotary arm plus pendulum.
- Action: one continuous RL action in `[-1, 1]`.
- Hardware-oriented action path:

```text
a_rl -> current scaling/clamp -> SLDRT/UART -> uC current PI loop -> motor
```

- Policy rate tested: 200 Hz and 500 Hz.
- Firmware/current loop runs faster than the RL policy.

## Slide 4 - Why TD3

- Continuous action fits motor current/torque command.
- Twin critics reduce over-optimistic Q estimates.
- Delayed actor updates improve stability.
- Target-policy smoothing helps avoid sharp brittle action choices.
- Deployment only needs the actor network.

## Slide 4b - DDPG vs TD3 vs SAC vs PPO

- DDPG:
  - off-policy, deterministic continuous actor,
  - simple idea, but fragile in our early tests.
- TD3:
  - DDPG improved with twin critics, delayed actor updates, target smoothing,
  - became our main successful baseline.
- SAC:
  - off-policy, stochastic actor with entropy/exploration objective,
  - good candidate for swing-up, but changes more assumptions.
- PPO:
  - on-policy policy-gradient method,
  - useful for discrete or continuous policies; in the Brian Douglas example it
    chooses the controller mode.

## Slide 5 - Observation And Action Design

- Initial local observation:

```text
theta1Error, theta2Error, omega1Error, omega2Error
```

- Later global swing-up observation:

```text
sin(theta1Error), cos(theta1Error)
sin(theta2Error), cos(theta2Error)
omega1Error, omega2Error, previousAction
```

- Sin/cos avoids the angle wrap discontinuity.
- `previousAction` helps when action smoothness and actuator dynamics matter.

## Slide 6 - Early Attempts And Lessons

- DDPG did not reliably learn even local upright stabilization.
- Early TD3 was better but slow and fragile.
- Frequent in-episode learning made training expensive.
- Raw wrapped angle observations were not ideal for swing-up.
- Training reward alone was misleading.

## Slide 7 - Key Shift: MathWorks-Style TD3

- Changed to a simpler, cleaner training setup.
- No staged curriculum for the first strong baseline.
- Episode-end learning with `LearningFrequency = -1`.
- Larger mini-batches and fixed evaluation sets.
- 7-state sin/cos observation.
- Result: first clearly useful swing-up/stabilization policy.

## Slide 8 - Best Simple-Model Baselines

200 Hz wide baseline:

- Run: `run_20260616_012625_td3_mathworks_style_wide`
- 297-case full evaluation.
- Failure rate: `14.5%`.
- Mean final theta2 MAE: `7.23 deg`.
- Main failures: arm-limit related.

500 Hz PI/current long baseline:

- Run: `run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long`
- Corrected full fixed-workspace failure rate: `5.39%`.
- Mean final theta2 MAE: `0.063 rad`.
- Best current hardware candidate so far.

## Slide 8b - 500 Hz Long Training Config

- Model and timing:
  - simple `1b` PI/current training model,
  - plant step `5e-5 s` / 20 kHz,
  - agent step `0.002 s` / 500 Hz,
  - `5 s` episode = max `2500` agent steps.
- Training length:
  - planned `5000` episodes,
  - no average-reward stop criterion,
  - checkpoints saved when episode reward exceeded `1800`.
- TD3 learning:
  - `LearningFrequency = -1`: learn at episode end,
  - minibatch size `1024`,
  - `NumEpoch = 10`,
  - max `100` minibatches per epoch.
- Maximum update count:
  - up to `5000 * 10 * 100 = 5,000,000` minibatch updates,
  - actor updates delayed: actor updates every 2 critic-update steps.
- Action:
  - normalized action scaled to current command,
  - `CurrentScale = 4 A`, `CurrentMax = 4 A`.

## Slide 9 - Hardware Transfer

- The 500 Hz long TD3 policy was deployed through SLDRT/current command.
- It attempted swing-up on the real Furuta hardware.
- Sign conventions and gross dynamics were correct enough to transfer.
- Main problem on hardware: jitter and current chatter near upright.
- Reduced action scaling helped:

```text
I_cmd = action * CurrentScale * 0.4
```

## Slide 10 - Hardware Data Recorded

- Saved hardware swing-up batches on 2026-07-07.
- Two main deployment conditions:
  - scale `0.4`, current clamp `+/-4 A`.
  - scale `1.0`, current clamp `+/-4 A`.
- Recorded at 500 Hz.
- Runs saved under `results/model_vs_hardware`.
- Overlay and average plots align time at motor enable.

## Slide 11 - Model vs Hardware Diagnostics

- Open-loop Test 1:

```text
I_cmd = 0.2 A
disable motor at 0.8 s
duration = 4 s
```

- Purpose: compare friction, damping, and free response.
- Broad behavior matched before disable.
- After disable, model and hardware diverged more strongly.
- Interpretation: real friction/stiction/dead-zone effects matter.

## Slide 12 - Weto Meeting Inputs

Suggestions tested or prepared:

- Smaller networks.
- Reduced observation representation.
- State-dependent reward shaping.
- More hardware-like model.
- Add actuator/controller state such as measured current or PI output.
- Domain randomization after nominal model works.

What happened:

- 1x64 actor and 1x64 critic failed.
- 1x64 actor with 2x64 critic learned, but was not better for balance.
- Pure unsigned arc-distance observation failed/interrupted.
- Detailed model was built, but nominal detailed training exposed a reward
  loophole: survival/swinging instead of capture.
- Domain randomization was delayed because the nominal detailed model still
  needs to learn capture and balance.

## Slide 12b - Why Not The Brian Douglas Hybrid SAC/PPO Route?

Reference architecture:

- classical controller for upright balance,
- SAC agent for swing-up reference/action,
- PPO agent for mode selection between swing-up and balance.

Why we did not follow it directly:

- project goal was to test a direct RL controller, not only RL-assisted
  switching around a classical stabilizer,
- adapting the hybrid QUBE/Raspberry Pi workflow to our ZHAW Furuta/uC/SLDRT
  stack would add major integration work,
- it introduces two RL agents plus a classical controller and supervisor,
  making debugging harder,
- TD3 was the closest next step after DDPG and changed fewer assumptions.

Takeaway:

- hybrid SAC/PPO remains a strong future architecture if direct TD3 capture
  remains too brittle.

## Slide 13 - Smaller Network Experiments

Symmetric actor 1x64 / critic 1x64:

- Failed to learn useful swing-up.
- Likely critic under-capacity.

Actor 1x64 / critic 2x64:

- Learned meaningful behavior.
- Not better overall than the baseline.
- Slightly fewer full-grid failures at 500 Hz, but worse balance quality,
  energy, final theta2 error, and action variation.

## Slide 14 - Reduced Observation Experiments

- Tried unsigned arc-distance observation:

```text
theta1_arc, theta2_arc, scaled omega1, scaled omega2, previousAction
```

- Training failed/interrupted with poor learning trace.
- Likely problem: removed too much directional information.
- Lesson: compact observations are attractive, but not if they break
  controllability/Markov information.

## Slide 15 - Detailed Model Work

Detailed model includes or documents:

- measured current noise and bias,
- encoder quantization,
- velocity filtering,
- current-setpoint low-pass,
- uC current PI behavior,
- static friction/current compensation,
- theta1 plant friction,
- more hardware-like sensing and actuation.

Purpose:

- reduce sim-to-real gap before domain randomization.

## Slide 16 - Detailed Model Results

Nominal detailed 1c model:

- Scratch and fine-tune runs survived long episodes.
- But they learned continuous swinging rather than capture and balance.
- In one late failure mode, the agent effectively learned to hold/hover the
  pendulum around a sideways region with jitter, instead of completing swing-up.

Latest 1c detailed 7000-episode scratch run at 1.5 A:

- Failure rate: `0`.
- Mean final theta2 MAE: `1.645 rad`.
- Mean final theta2 peak-to-peak: `6.235 rad`.
- Smooth action, wrong behavior.

Interpretation:

- The reward can still be exploited by staying alive while swinging.

## Slide 17 - Current Technical Bottleneck

The problem is no longer just:

```text
Can RL move the pendulum?
```

It is:

```text
Can RL swing up, capture upright, and remain quiet under hardware-like dynamics?
```

Open issues:

- capture reward,
- upright damping,
- current/action jitter,
- friction and dead zones,
- preserving a working policy during fine-tuning,
- evaluating hardware-like models honestly.

## Slide 18 - Do's

- Use fixed evaluation; training reward misled us several times.
- Inspect quality metrics, not only failure rate:
  - final theta2 error,
  - end-window oscillation,
  - action variation,
  - electrical effort.
- Keep training/evaluation/deployment sample time and current scaling matched.
- Change one major thing at a time:
  - network,
  - observation,
  - reward,
  - model fidelity,
  - current limit.
- Run zero-exploration smoke tests before fine-tuning a working policy.
- Log every hardware run with metadata and plots.

## Slide 19 - Don'ts

- Do not present "survived the episode" as "balanced the pendulum."
- Do not trust old 500 Hz eval artifacts unless the fixed-workspace config was
  used.
- Do not shrink the critic just because the deployed actor should be small.
- Do not remove angle direction information just to reduce observation size.
- Do not add domain randomization before the nominal detailed model can capture.
- Do not compare hardware and simulation unless action scaling and clamps match.

## Slide 20 - Handover: Repository Structure

Important folders:

```text
docs/                  project notes and decisions
scripts/               configs, training, evaluation, analysis
scripts/analysis/      hardware/simulation save and compare tools
results/TD3/           training runs and evaluation artifacts
results/model_vs_hardware/ hardware/simulation comparison runs
outputs/               meeting/presentation prep artifacts
references/            source/reference models and docs
```

Important current docs:

```text
docs/hardware_swingup_scaled_current_tests_2026-07-07.md
docs/detailed_model_training_results_2026-07-05.md
docs/weto_inputs_progress_2026-07-01.md
docs/domain_randomization_preparation.md
```

## Slide 21 - Demo Plan

Show:

- saved hardware swing-up overlay/average plot,
- one hardware quicklook plot,
- one simulation vs hardware comparison plot,
- key result folders and docs,
- how to save a new hardware run,
- how to compare runs.

Optional live demo:

- open SLDRT Simulink model,
- show current command path and safety clamps,
- run only if hardware setup is ready and safe.

## Slide 22 - Future Work

Immediate next step:

- fix nominal detailed-model capture and balance before domain randomization.

Recommended path:

1. Capture-tune the latest detailed 1c agent with upright-region shaping.
2. Add state-dependent action/current penalties near upright.
3. Preserve old policy behavior during fine-tuning.
4. Add actuator state if needed: `I_meas`, current command, PI output.
5. Add domain randomization gradually.
6. Use hardware logs to tune randomization and residual corrections.

## Slide 22b - Sim-To-Real Research Directions

- SimOpt / adaptive domain randomization:
  - use real rollouts to adjust simulation randomization ranges.
- Residual RL:
  - keep a useful base policy and learn a correction.
- EPOpt / model ensembles:
  - train on difficult sampled model variants for robustness.
- Multi-fidelity RL:
  - move systematically from simple simulation to detailed simulation/hardware.
- Policy distillation / learning without forgetting:
  - fine-tune without destroying the old working policy.

Practical conclusion:

- do not jump straight to broad randomization,
- preserve the working `500Hz_long` behavior,
- adapt gently on the detailed model,
- use hardware logs to tune mismatch.


## Slide 23 - Final Takeaway

- TD3 worked enough to produce real hardware swing-up attempts.
- The project now has a reproducible training/evaluation/hardware logging
  workflow.
- The hard remaining part is sim-to-real robust capture and quiet balance.
- The repository is ready for continuation with clear baselines, results, and
  next experiments.
