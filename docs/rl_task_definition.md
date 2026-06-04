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

Use the same naming convention as the Simulink material, but pass the **post-summation feedback-controller error signals** to the RL agent:

```matlab
obs = [theta1Error; theta2Error; omega1Error; omega2Error]
```

where:

| Variable | Meaning | Convention |
|---|---|---|
| `theta1Error` | Rotary arm angle error | rad, usually `theta1Ref - theta1` or `theta1 - theta1Ref` after the sign is matched to the baseline controller. Initial reference is `theta1Ref = 0`. |
| `theta2Error` | Pendulum upright error | rad, same error signal used by the hardware state-space controller. |
| `omega1Error` | Rotary arm angular velocity error | rad/s, same post-summation signal used by the feedback controller. Initial reference is `0`. |
| `omega2Error` | Pendulum angular velocity error | rad/s, same post-summation signal used by the feedback controller. Initial reference is `0`. |

The principle is: **the RL observation should be taken after the same summation/error blocks used by the feedback controller**. That keeps the RL agent, baseline controller, and hardware signal path aligned.

The scripts sometimes use `theta` and `phi` naming interchangeably. In this project, use `theta1/theta2/omega1/omega2` in documentation and project code unless an imported reference file already uses another convention.

Raw angle conventions:

- `theta1` is the rotary arm angle. Viewed from above, counter-clockwise is positive.
- `theta2` is the pendulum angle. `theta2 = pi` means upright. Viewed from the side where the rotary part points toward the observer, counter-clockwise is positive.

The hardware controller transforms the pendulum encoder angle into an upright error like this:

```text
theta2 [rad]
-> subtract pi
-> short angle wrap
-> subtract wrapped value from 0
```

The short angle wrap block is:

```matlab
atan2(sin(u), cos(u))
```

It maps any angle to the equivalent shortest signed angle in `[-pi, pi]`. This avoids discontinuities such as treating `2*pi - 0.01` as a huge error instead of a small negative/positive angle around the circle.

Therefore, the controller-facing pendulum error is:

```matlab
theta2WrappedFromUpright = atan2(sin(theta2 - pi), cos(theta2 - pi));
theta2Error = 0 - theta2WrappedFromUpright;
```

or equivalently:

```matlab
theta2Error = -atan2(sin(theta2 - pi), cos(theta2 - pi));
```

Initial RL recommendation: pass this same `theta2Error` signal to the RL agent instead of raw `theta2`. This keeps the RL controller aligned with the state-space baseline and with the hardware signal path.

Apply the same rule to the other observation channels: pass controller-facing `theta1Error`, `omega1Error`, and `omega2Error`, not raw measured values, unless a later experiment explicitly tests a different observation design.

Open checks:

- Confirm where angle wrapping occurs in the Simulink models.
- Confirm the `theta1Error`, `omega1Error`, and `omega2Error` signs used by the baseline controller. For reward terms only the magnitude matters, but for RL policy learning the signs must be consistent.
- Confirm whether raw `theta2` should also be logged for debugging, even if it is not part of the RL observation.

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

Initial recommendation: use a **normalized signed torque/current-like action** in simulation:

```matlab
a_rl in [-1, 1]
```

Then map the normalized action outside the agent:

```matlab
i_ref = a_rl * iMax;
```

or, if the selected simulation interface is torque:

```matlab
tau_ref = a_rl * tauMax;
```

Use `[-1, 1]`, not `[0, 1]`, because the Furuta pendulum needs bidirectional control authority. The `[-1, 1]` range also keeps the neural-network action scale simple, makes action penalties easier to tune, and lets the same policy represent "fraction of available actuator authority" if the physical current/torque limit changes later.

The state-space controller for upright stabilization outputs torque, so there is no need for the RL policy to learn the inner current controller. The learned action should later be mapped through existing low-level actuator protection.

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
abs(theta1Error) > deg2rad(90)
abs(omega1Error) > 200
abs(omega2Error) > 200
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
rotary_arm_term      = 0.1 * (theta1Error / theta1Scale)^2
velocity_term        = 0.01 * ((omega1Error / velocityScale)^2 + (omega2Error / velocityScale)^2)
action_effort_term   = lambda_u * u^2
action_smoothness    = lambda_du * (u - u_prev)^2
upright_bonus        = uprightBonus * (abs(theta2Error) < uprightTolerance)
unsafe_penalty       = unsafePenalty * isUnsafe
```

The current starter implementation is in:

```text
scripts/rewardFcnFuruta.m
```

In the starter reward, `u` is interpreted as the normalized RL action in `[-1, 1]`. Therefore `u^2 = 1` means maximum allowed normalized effort, independent of whether the downstream physical interface is current or torque.

## Reset Distribution

Start with a curriculum around upright:

| Stage | Initial `theta2Error` range | Initial `omega2Error` range | Goal |
|---|---:|---:|---|
| 1 | `[-5, 5] deg` | `[-1, 1] rad/s` | Learn local balance |
| 2 | `[-12, 12] deg` | `[-3, 3] rad/s` | Widen recovery range |
| 3 | `[-20, 20] deg` | `[-5, 5] rad/s` | Robust near-upright stabilization |

Keep `theta1Error` and `omega1Error` near zero at first. Widen only after baseline and RL behavior are understood.

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
2. Confirm the torque/current-like action scaling in the selected simulation model.
3. Adapt `makeFurutaConfig.m` to the post-summation observation vector `[theta1Error; theta2Error; omega1Error; omega2Error]` and the chosen action interface.
4. Build a deterministic baseline simulation.
5. Make `evaluateFurutaController.m` extract real logged signals.
6. Train only Stage 1 of the upright curriculum.
7. Compare Stage 1 RL against the baseline before widening the reset distribution.

## Open Decisions

- Which Simulink model is the first RL training model: analytical, Simscape, or adapted course model?
- Does the normalized action map to current setpoint or torque command in the first training model?
- Should the first model expose ideal velocities, or should Stage 1 already include encoder quantization and low-pass differentiated velocity?
- What exact `theta1Error`, `omega1Error`, and `omega2Error` signs should be used to match the baseline controller?
- Should the baseline be LQR first, PI first, or both?
