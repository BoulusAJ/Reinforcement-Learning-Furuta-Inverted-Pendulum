# MathWorks-Style TD3 Run Notes

Date: 2026-06-16
Branch: `dev/direct-td3-swingup`

These notes summarize the first two no-curriculum MathWorks-style Furuta TD3
runs and the next actuator-interface diagnostic.

## Shared Setup

Both runs kept the Furuta Simulink model and the normalized action range
`[-1, 1]`, but moved training closer to the MathWorks QUBE direct-TD3 example:

- no staged curriculum,
- default MATLAB TD3 networks with `NumHiddenUnit = 64`,
- `SampleTime = 5e-3` s,
- `MiniBatchSize = 1024`,
- `NumEpoch = 10`,
- `ExperienceBufferLength = 1e6`,
- SGDM actor/critic optimizers,
- async parallel training,
- CPU learner, based on the local CPU/GPU update benchmark,
- MathWorks-style reward mode:

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

The `F` term is the MathWorks-style survival term, not the old small custom
`aliveBonus`. In this branch it is implemented as:

```matlab
cfg.Reward.aliveReward = 1.0;
cfg.Reward.costWeight = 0.1;
cfg.Reward.aliveTheta1Limit = cfg.Safety.MaxAbsArmAngle;
cfg.Reward.aliveOmega1Limit = 30.0;
```

## Run 1: Narrow Upright Randomization

Run folder:

```text
results/TD3/run_20260616_000552_td3_mathworks_style
```

Training configuration:

```text
MaxEpisodes = 2000
Theta1ErrorRange = +/-45 deg
Theta2ErrorRange = +/-45 deg
Omega1ErrorRange = [0, 0]
Omega2ErrorRange = [0, 0]
```

Automated full evaluation summary:

```text
NumCases = 297
FailureRate = 0
MeanFinalTheta2MAE = 0.5351 rad = 30.66 deg
MedianFinalTheta2MAE = 10.38 deg
MeanCaseCost = 26.16
```

What we learned:

- The MathWorks-style workflow fixed the earlier training slowdown/timeout
  problem. Training completed normally and produced full-length late episodes.
- Survival alone was not a sufficient success criterion. Automated evaluation
  showed no failures, but the controller often survived without tightly
  stabilizing the pendulum upright.
- Training reward and failure rate therefore overestimated controller quality.
  Fixed-case evaluation and manual plots are both needed.

## Run 2: Wider Reset And Longer Training

Run folder:

```text
results/TD3/run_20260616_012625_td3_mathworks_style_wide
```

Training configuration:

```text
MaxEpisodes = 3000
Theta1ErrorRange = +/-45 deg
Theta2ErrorRange = +/-90 deg
Omega1ErrorRange = [-2, 2] rad/s
Omega2ErrorRange = [-2, 2] rad/s
```

Training completed all `3000/3000` episodes. Final training snapshot:

```text
Final episode reward = 827.861
Final average reward = 740.433
Last 50 mean reward = 718.231
Last 50 full-length episodes = 43/50
```

Automated evaluation:

```text
Short eval: 7/7 passed
Short mean final theta2 MAE = 0.346 deg

Full eval: 297 cases
Full failures = 43
Full failure rate = 14.48%
Full mean final theta2 MAE = 7.226 deg
Full median final theta2 MAE = 0.346 deg
Full cases under 5 deg final theta2 MAE = 257/297
Full cases under 10 deg final theta2 MAE = 266/297
```

Where the full evaluation failed:

```text
All 43 failures were arm-angle limit failures.
0 pendulum-limit failures.
0 angular-velocity-limit failures.
```

The arm limit failures were mostly small boundary crossings:

```text
arm-limit exceedance margin:
min    0.012 deg
median 0.312 deg
max    2.277 deg
```

Manual observations from representative initial conditions:

```text
theta1_deg, theta2_deg
0, 185
0, 190
0, 200
0, 220
0, 240
0, 270
0, 360
0, 0
10, 270
45, 360
```

The agent managed swing-up where needed and stabilized the pendulum when near
upright. This made run 2 the first clearly usable direct TD3 controller in this
branch.

What we learned:

- Wider reset randomization plus longer training substantially improved
  upright accuracy.
- The controller can swing up from practical manually inspected cases.
- The main remaining automated-evaluation weakness is arm management under
  strict arm travel limits and stressful initial velocity cases.
- The final pendulum behavior still has a small upright oscillation, observed
  around `0.5 deg` amplitude and about `7 Hz`.
- The action also shows unnecessary approximately `40 Hz` oscillatory content
  during parts of swing-up, especially around `0` to `0.155` s and `0.765` to
  `0.87` s in the inspected trace.

## Angle Wrapping Note

`theta2Error` is intentionally wrapped to `[-pi, pi]`, so the scalar error has a
sign discontinuity at the downward position. The agent observation avoids
feeding that discontinuity directly to the network by using:

```matlab
sin(theta2Error)
cos(theta2Error)
```

Reward diagnostics and evaluation metrics still decode a scalar error with
`atan2`. This is acceptable for the current squared-error reward because `+pi`
and `-pi` have the same cost. A future reward refinement could use a periodic
cost:

```matlab
theta2Cost = 2 * (1 - cos(theta2Error));
```

This would remove the scalar wrap discontinuity from the pendulum-angle cost
itself.

## Reward Scale And Residual Oscillation

The MathWorks-style theta2 reward term near upright is very small. For a
`0.5 deg` oscillation:

```matlab
theta2Error = deg2rad(0.5);
rewardTermTheta2Error = -0.1 * theta2Error^2;  % about -7.6e-6
```

This is not a numerical precision problem, but it means tiny residual pendulum
oscillations are almost free compared with the `F = 1` survival term. Future
polishing runs can add a near-upright precision or damping term, for example:

```matlab
uprightFineCost = double(abs(theta2Error) < deg2rad(5)) * ...
    (theta2Error / deg2rad(1))^2;

uprightDampingCost = double(abs(theta2Error) < deg2rad(5)) * omega2Error^2;
```

These should be used for polishing from the working controller, not as the first
thing to change before preserving the successful run.

## QUBE Reference Comparison

The locally trained MathWorks QUBE TD3 agent was inspected using:

```text
references/MATLAB-Train-Default-TD3-Agent-to-Control-Quanser-QUBE-Pendulum/agent_1_results_1.csv
```

Final 0.5 s summary from that CSV:

```text
theta_wrapped mean = 0.1713 rad = 9.82 deg
theta_wrapped oscillation amplitude = 0.0086 deg
phi_wrapped mean = -0.00054 deg
phi_wrapped oscillation amplitude = 0.00025 deg
act final amplitude = about 2e-6
volt final amplitude = about 2.5e-5 V
```

The QUBE example also accepts a nonzero arm offset, but it does not show the
same pendulum or action oscillations near upright.

## Collective Interpretation

The evidence now points to three separate issues:

1. The no-curriculum MathWorks-style TD3 workflow is a good baseline for this
   Furuta model. It solved the training speed/stability problem better than the
   earlier staged direct-TD3 attempt.
2. The remaining arm offset is probably reward/objective related. The QUBE
   reference also settles with arm offset, suggesting the reward tolerates it.
3. The residual pendulum/action oscillations in our Furuta controller may be
   related to the actuator interface. The current/torque path includes the PI
   current controller, saturation, and rate-transition dynamics between the
   agent action and realized torque.

## Next Diagnostic: Direct Voltage Input

The next experiment should keep the successful run-2 TD3 settings and change
only the actuator interface:

```text
Keep:
- MathWorks-style reward
- 3000 episodes
- wide reset distribution
- default 64-unit TD3 networks
- 200 Hz agent sample time
- async parallel training
- same short and full fixed evaluation

Change:
- route the normalized action to direct motor voltage instead of the
  current/torque reference path with the PI current controller
```

Interpretation of outcomes:

```text
If voltage input removes the 7 Hz theta2 oscillation and 40 Hz action chatter:
    the current-controller actuator path is probably contributing.

If voltage input still has similar oscillations:
    reward/policy/training setup is the more likely cause.

If voltage input trains worse:
    the current controller was helpful, and the next step should be smoothing or
    damping improvements around the current interface.
```

Prepared entry point:

```matlab
run("scripts/trainFurutaDirectTD3MathWorksStyleVoltage.m")
```

The voltage config currently assumes separate Simulink model names:

```matlab
TrainingName   = "inv_rot_pen_RL_cntr_simscape_sim_train_2"
EvaluationName = "inv_rot_pen_RL_cntr_simscape_sim_2"
```

Pass override options to `makeFurutaMathWorksStyleVoltageTD3Config` only if a
future voltage-model copy uses different filenames or RL Agent block paths.

## Voltage Run: Plant Model Evaluation Split

Run folder:

```text
results/TD3/run_20260616_233822_td3_mathworks_style_voltage
```

Training completed all `3000/3000` episodes. The final training episodes were
mostly full length and high reward, but there were still occasional collapses:

```text
Episode 2991: reward 7.35, steps 21
Episode 2995: reward 4.30, steps 16
Episode 3000: reward 771.39, steps 1000
Final average reward = 629.95
```

The first post-training evaluation failed during metrics extraction because
the voltage model logs `voltage_command` instead of `current_command`. The
signal extractor was updated to treat either signal as the generic actuator
command and to tolerate missing current-controller-specific logs.

Two evaluations were then preserved from the same saved `Agent3000.mat`:

```text
short_simscape_model_active_*.csv
full_simscape_model_active_*.csv

short_final_*.csv
full_final_*.csv
```

The `simscape_model_active` files correspond to the evaluation model while the
Simscape Multibody model was active. The `final` files correspond to the
evaluation model after switching back to the analytical plant model, matching
the plant used during training.

Summary:

```text
Simscape-active short eval:
  NumCases = 7
  FailureRate = 0
  MeanFinalTheta2MAE = 0.01393 rad = 0.798 deg

Analytical-active short eval:
  NumCases = 7
  FailureRate = 0
  MeanFinalTheta2MAE = 2.11e-8 rad

Simscape-active full eval:
  NumCases = 297
  FailureRate = 88.55%
  MeanFinalTheta2MAE = 0.5619 rad = 32.19 deg
  MeanCaseCost = 886.01

Analytical-active full eval:
  NumCases = 297
  FailureRate = 21.21%
  MeanFinalTheta2MAE = 0.3751 rad = 21.49 deg
  MeanCaseCost = 214.73
```

The large change confirms that the voltage-run evaluation was highly sensitive
to which plant implementation was active. Since the agent was trained on the
analytical model, the analytical model should be used for policy feedback and
for the main apples-to-apples evaluation unless the agent is explicitly trained
against the Simscape-active plant.

Manual observations from the analytical-active voltage evaluation:

- Near `theta0 = [0; 0]` and `theta0 = [0; pi]`, the final upright pendulum
  oscillation is nearly absent compared with the current-controller run.
- The early swing-up action still contains oscillatory content, so that early
  chatter is not explained solely by the PI current controller.
- With the Simscape model active, odd end oscillations and plant divergence
  were observed after about `2.8 s`, even though the analytical and Simscape
  trajectories matched before that in earlier open-loop checks.

Interpretation:

- The current-controller/PI path still looks better than direct voltage when
  judged by broad automated robustness, because run 2 with the PI/current path
  had a lower full-grid failure rate (`14.48%`) than the analytical-active
  voltage run (`21.21%`).
- That statement should be treated as provisional. The voltage run also exposed
  a plant-selection confound, and the comparison is not purely actuator
  interface versus actuator interface unless both are evaluated against the
  same active plant model and logging assumptions.
- The voltage run is promising for reducing final upright theta2 oscillation,
  but it did not clearly improve broad robustness.

Practical lesson:

```text
Train and evaluate with the same plant as the feedback source.
Use Simscape visualization as a diagnostic unless the policy is trained against
that active dynamics path.
```

## Recommended Next Decision Gate

Before choosing the voltage command path or the torque/current command path for
hardware-oriented work, run a dry-run comparison matrix with saved agents and no
learning:

```text
A) PI/current-path TD3 run 2 agent
   - evaluate on analytical-active model
   - evaluate on Simscape-active model

B) Direct-voltage TD3 agent
   - evaluate on analytical-active model
   - evaluate on Simscape-active model
```

For each case, compare:

```text
- short fixed evaluation summary
- full fixed evaluation summary
- final theta2 oscillation amplitude and frequency
- theta1 offset and arm-limit margin
- action chatter frequency
- current, voltage, and torque saturation
- analytical-vs-Simscape trajectory divergence time
```

This matrix separates three questions that are currently partly tangled:

```text
1. Does the trained policy behave similarly on analytical and Simscape dynamics?
2. Are the upright oscillations caused by the actuator path, policy/reward, or
   plant mismatch?
3. Which command interface is safer and more transferable for hardware?
```

Expected interpretation:

```text
If PI/current matches Simscape better and remains more robust:
    keep PI/current as the main controller path.

If voltage removes final upright oscillation but remains less robust:
    use voltage as a diagnostic result, not yet as the main hardware path.

If both policies diverge badly when Simscape is active:
    prioritize resolving model mismatch before actuator-interface decisions.

If both policies are stable only in easy dry runs:
    hardware testing should use a narrow safety gate and no online RL learning.
```

Do not continue TD3 learning on hardware yet. The next hardware step, if any,
should be policy-only dry runs with safety fallback and full logging. Online
hardware fine-tuning should only be considered after a conservative supervisor
and actuator/state limits are defined.
