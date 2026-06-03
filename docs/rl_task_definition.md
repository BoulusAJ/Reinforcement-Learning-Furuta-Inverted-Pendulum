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

## Candidate Observation Vector

Initial convention:

```matlab
obs = [theta; alpha; theta_dot; alpha_dot]
```

where:

| Variable | Meaning | Initial convention |
|---|---|---|
| `theta` | Rotary arm angle | rad |
| `alpha` | Pendulum angle error from upright | rad, `0` means upright for RL |
| `theta_dot` | Rotary arm angular velocity | rad/s |
| `alpha_dot` | Pendulum angular velocity | rad/s |

Open checks:

- Confirm whether the lab model reports pendulum angle as `0` down and `pi` up, or directly as upright error.
- Confirm angle wrapping convention. Course notes mention `atan2(sin(phi2), cos(phi2))`.
- Confirm whether velocities are measured directly or estimated.

## Candidate Action Interface

This is the most important unresolved design choice.

Possible RL action interfaces:

| Option | RL action means | Pros | Risks |
|---|---|---|---|
| Normalized current setpoint | RL commands motor current through existing current loop | Close to torque control; physically meaningful | Needs careful current saturation and safety checks |
| Motor speed setpoint | RL commands the outer speed loop | Reuses existing low-level control; likely safer on hardware | RL action is less direct; dynamics include speed loop |
| Voltage/PWM command | RL commands actuator voltage/PWM directly | Simple in simulation | Higher hardware risk; bypasses useful protection |
| Angle-controller replacement | RL replaces only the pendulum angle controller | Good comparison against course controller | Need to preserve lower loops and sign conventions carefully |

Initial recommendation: use a **normalized action** in simulation, then map it to the safest available low-level interface once the Simulink model is inspected. Do not train with a direct hardware voltage/PWM interpretation unless there is a strong reason.

## Initial Safety Limits

Reference values from the ZHAW material:

| Quantity | Value | Source |
|---|---:|---|
| Sample/PWM frequency | `20e3 Hz` | `rotary_pendulum_ini_corrected.m` |
| Voltage limit | `24 V` | `rotary_pendulum_ini_corrected.m` |
| Current limit | `1 A` | course safety setting |
| Motor speed limit | `200 rad/s` | course safety setting |
| Pendulum angle limit | `30 deg` | course safety setting |
| Enable angle | `30 deg` | course material |
| Disable angle | `10 deg` | course material |

For the first RL simulation task, start with conservative termination:

```matlab
abs(alpha) > deg2rad(30)
abs(theta) > deg2rad(90)
abs(theta_dot) > 200
abs(alpha_dot) > 200
```

Tune these after the model signal conventions are confirmed.

## Reward Shape

Use a continuous control-oriented reward:

```text
r =
  - alpha_error_term
  - rotary_arm_motion_term
  - velocity_term
  - action_effort_term
  - action_smoothness_term
  + upright_bonus
  - unsafe_penalty
```

Starter interpretation:

```matlab
alpha_error_term     = (alpha / alphaScale)^2
rotary_arm_term      = 0.1 * (theta / thetaScale)^2
velocity_term        = 0.01 * ((theta_dot / velocityScale)^2 + (alpha_dot / velocityScale)^2)
action_effort_term   = lambda_u * u^2
action_smoothness    = lambda_du * (u - u_prev)^2
upright_bonus        = uprightBonus * (abs(alpha) < uprightTolerance)
unsafe_penalty       = unsafePenalty * isUnsafe
```

The current starter implementation is in:

```text
scripts/rewardFcnFuruta.m
```

## Reset Distribution

Start with a curriculum around upright:

| Stage | Initial pendulum angle range | Initial angular velocity range | Goal |
|---|---:|---:|---|
| 1 | `[-5, 5] deg` | `[-1, 1] rad/s` | Learn local balance |
| 2 | `[-12, 12] deg` | `[-3, 3] rad/s` | Widen recovery range |
| 3 | `[-20, 20] deg` | `[-5, 5] rad/s` | Robust near-upright stabilization |

Keep rotary arm initial angle and velocity near zero at first. Widen only after baseline and RL behavior are understood.

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
2. Decide the RL action interface.
3. Adapt `makeFurutaConfig.m` to the chosen model/action interface.
4. Build a deterministic baseline simulation.
5. Make `evaluateFurutaController.m` extract real logged signals.
6. Train only Stage 1 of the upright curriculum.
7. Compare Stage 1 RL against the baseline before widening the reset distribution.

## Open Decisions

- Which Simulink model is the first RL training model: analytical, Simscape, or adapted course model?
- Is the RL action current, speed setpoint, voltage/PWM, or controller replacement?
- Does the model expose full state directly, or do we need velocity estimation/observer logic?
- What exact angle convention should be used inside the RL environment?
- Should the baseline be LQR first, PI first, or both?
