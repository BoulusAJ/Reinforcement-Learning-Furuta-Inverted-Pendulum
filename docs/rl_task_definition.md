# RL Task Definition: Near-Upright Stabilization

This document fixes the first RL task boundary for the Furuta inverted rotary pendulum project.

The initial RL task is **near-upright stabilization only**. Swing-up, hardware deployment, and full operating-range control are separate later tasks.

## Control Story

The project should be presented as:

> RL is tested as a learned near-upright controller under safety constraints, compared against a classical baseline, with sim-to-real considerations.

This avoids making the project depend on RL solving the entire Furuta problem at once.

## First RL Objective

Train an RL policy that stabilizes the pendulum near the upright equilibrium in simulation.

The policy should:

- keep the pendulum close to upright,
- avoid excessive rotary-arm motion,
- avoid actuator saturation,
- produce smooth commands,
- terminate quickly on unsafe states,
- be evaluated against the same test cases as the classical baseline.

## Out Of Scope For The First RL Task

- Swing-up from the hanging-down position.
- Learning directly on hardware.
- Replacing all inner motor/current/speed loops before their role is understood.
- Optimizing for minimum-time recovery.
- Robust global stabilization over very large initial-angle ranges.

## Observation Vector And Angle Convention

Use the same naming convention as the Simulink material:

```matlab
obs = [theta1; theta2; omega1; omega2]
```

where:

| Variable | Meaning | Convention |
|---|---|---|
| `theta1` | Rotary arm angle | rad, viewed from above, counter-clockwise is positive. |
| `theta2` | Pendulum angle | rad, `pi` means upright. Viewed from the side where the rotary part points toward the observer, counter-clockwise is positive. |
| `omega1` | Rotary arm angular velocity | rad/s |
| `omega2` | Pendulum angular velocity | rad/s |

The scripts sometimes use `theta` and `phi` naming interchangeably. In this project, use `theta1/theta2/omega1/omega2` in documentation and project code unless an imported reference file already uses another convention.

For stabilization and reward calculations, compute the upright pendulum error explicitly:

```matlab
theta2Error = atan2(sin(theta2 - pi), cos(theta2 - pi));
```

This keeps the RL observation convention close to the Simulink model while still giving the reward and termination logic a clean near-upright error.

Known angle wrapping from the course material:

```matlab
phi2Wrapped = atan2(sin(phi2), cos(phi2));
```

Open checks:

- Confirm where angle wrapping occurs in the Simulink models.
- Confirm whether `theta2` is logged raw, wrapped, or shifted before individual controller blocks.
- Confirm whether the RL observation should include raw `theta2`, `theta2Error`, or both.

## Velocity And Encoder Fidelity

In simulation, velocity is calculated directly by the model.

On the hardware-oriented model, velocity is estimated with a low-pass differentiator:

```matlab
Tf = 1/(2*pi*100);
G_phi2omf = s / (Tf*s + 1);
```

Known encoder information:

| Encoder | Resolution |
|---|---:|
| Pendulum quadrature encoder | `1024` increments, `4*1024` counts/rev |
| Rotary motor quadrature encoder | `4096` increments |

Initial recommendation:

- Start RL training with the clean/pre-hardware-like simulation signals so the controller task can be debugged without sensor artifacts.
- Add hardware realism after the baseline and Stage 1 RL work: encoder quantization, velocity filtering, sampling, saturation, and actuator limits.
- Evaluate the trained policy against the hardware-like signal path before any hardware dry run.

This gives a staged sim-to-real path instead of making the first RL training run fight model dynamics, reward design, and sensor implementation at the same time.

## Candidate Action Interface

This is the most important unresolved design choice.

Possible RL action interfaces:

| Option | RL action means | Pros | Risks |
|---|---|---|---|
| Normalized torque/current setpoint | RL commands torque/current through the existing low-level current path | Close to the state-space controller output; physically meaningful | Needs careful current saturation and safety checks |
| Motor speed setpoint | RL commands the outer speed loop | Reuses existing low-level control; likely safer on hardware | RL action is less direct; dynamics include speed loop |
| Voltage/PWM command | RL commands actuator voltage/PWM directly | Simple in simulation | Higher hardware risk; bypasses useful protection |
| Angle-controller replacement | RL replaces only the pendulum angle controller | Good comparison against course controller | Need to preserve lower loops and sign conventions carefully |

Initial recommendation: use a **normalized torque/current-like action** in simulation, because the state-space controller for upright stabilization outputs torque. There is no need for the RL policy to learn the inner current controller. The learned action should later be mapped through existing low-level actuator protection.

Do not train with a direct hardware voltage/PWM interpretation unless there is a strong reason.

## Initial Safety Limits

Reference values from the ZHAW material:

| Quantity | Value | Source |
|---|---:|---|
| Sample/PWM frequency | `20e3 Hz` | `rotary_pendulum_ini_corrected.m` |
| Voltage limit | `24 V` | `rotary_pendulum_ini_corrected.m` |
| Current limit | `1 A` | course safety setting |
| Motor speed limit | `200 rad/s` | course safety setting |
| Pendulum angle limit | `30 deg` | course safety setting |
| Enable/disable angle thresholds | `10 deg` inner, `30 deg` outer after normalization | course material uses hysteresis logic |

For the first RL simulation task, start with conservative termination:

```matlab
abs(theta2Error) > deg2rad(30)
abs(theta1) > deg2rad(90)
abs(omega1) > 200
abs(omega2) > 200
```

Tune these after the model signal conventions are confirmed.

The hardware-oriented model contains a one-shot hysteresis switch that takes wrapped `phi2/theta2` as input. Its role is to enable the upright controller only when the pendulum is close enough to upright and then disable/lock out after leaving the outer safe band. It is a controller enable and safety gate, not a swing-up controller.

## Reward Shape

Use a continuous control-oriented reward:

```text
r =
  - theta2_error_term
  - rotary_arm_motion_term
  - velocity_term
  - action_effort_term
  - action_smoothness_term
  + upright_bonus
  - unsafe_penalty
```

Starter interpretation:

```matlab
theta2_error_term    = (theta2Error / theta2Scale)^2
rotary_arm_term      = 0.1 * (theta1 / theta1Scale)^2
velocity_term        = 0.01 * ((omega1 / velocityScale)^2 + (omega2 / velocityScale)^2)
action_effort_term   = lambda_u * u^2
action_smoothness    = lambda_du * (u - u_prev)^2
upright_bonus        = uprightBonus * (abs(theta2Error) < uprightTolerance)
unsafe_penalty       = unsafePenalty * isUnsafe
```

The current starter implementation is in:

```text
scripts/rewardFcnFuruta.m
```

## Reset Distribution

Start with a curriculum around upright:

| Stage | Initial `theta2Error` range | Initial `omega2` range | Goal |
|---|---:|---:|---|
| 1 | `[-5, 5] deg` | `[-1, 1] rad/s` | Learn local balance |
| 2 | `[-12, 12] deg` | `[-3, 3] rad/s` | Widen recovery range |
| 3 | `[-20, 20] deg` | `[-5, 5] rad/s` | Robust near-upright stabilization |

Keep `theta1` and `omega1` near zero at first. Widen only after baseline and RL behavior are understood.

## Baseline Comparison

RL must be compared against a classical baseline before any hardware claim.

Baseline candidates from the reference material:

- LQR from `references/zhaw_rotary_pendulum_lab/lab_model/inv_rot_pen_ini.m`.
- State-space/LQR design from `references/zhaw_rotary_pendulum_lab/course_lab_p5/Matlab/rotary_pendulum_ss_speed_conotrolled.m`.
- PI/root-locus style angle control from `references/zhaw_rotary_pendulum_lab/course_lab_p5/Matlab/rotary_pendulum_ini_corrected.m`.

Evaluation cases should be identical for baseline and RL:

- same initial angle/velocity grid,
- same actuator limits,
- same termination logic,
- same disturbances if used,
- same metrics.

## Required Metrics

At minimum log:

- maximum absolute pendulum angle,
- maximum absolute arm angle,
- settling time near upright,
- RMS pendulum angle error,
- RMS actuator command,
- action saturation count/time,
- safety termination count,
- episode return,
- final state error.

## First Implementation Steps

1. Inspect the Simulink model signal names and block structure.
2. Confirm the torque/current-like action interface in the selected simulation model.
3. Adapt `makeFurutaConfig.m` to `theta1/theta2/omega1/omega2` and the chosen action interface.
4. Build a deterministic baseline simulation.
5. Make `evaluateFurutaController.m` extract real logged signals.
6. Train only Stage 1 of the upright curriculum.
7. Compare Stage 1 RL against the baseline before widening the reset distribution.

## Open Decisions

- Which Simulink model is the first RL training model: analytical, Simscape, or adapted course model?
- Should the first model expose ideal velocities, or should Stage 1 already include encoder quantization and low-pass differentiated velocity?
- Should the RL observation include raw `theta2`, computed `theta2Error`, or both?
- Should the baseline be LQR first, PI first, or both?
