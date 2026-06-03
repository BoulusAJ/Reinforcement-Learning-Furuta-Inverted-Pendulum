# Furuta Lab Model Information Template

Fill this in when the lab-model details are available.

## Plant and Mechanics

Initial values from `references/zhaw_rotary_pendulum_lab/lab_model/get_parameter.m`.

| Item | Value | Notes |
|---|---:|---|
| Rotary arm length | `L1 = 0.0855` | m |
| Pendulum length | `L2 = 0.161` | m |
| Arm inertia | `J1zz = 11270.84e-9` | kg m^2, from CAD/comment in parameter script. |
| Pendulum inertia | `J2yy = J2zz = 1/4*m2*r2^2 + 1/12*m2*L2^2` | kg m^2 |
| Arm mass | `m1 = 0.1222` | kg |
| Pendulum mass | `m2 = 0.028` | kg |
| Damping/friction terms | `b1 = 1e-6`, `b2 = 4.4e-05` | `b1` marked TODO/measure, `b2` from measurement. |

## Motor and Course Limits

Initial values from `references/zhaw_rotary_pendulum_lab/course_lab_p5/Matlab/rotary_pendulum_ini_corrected.m`.

| Item | Value | Notes |
|---|---:|---|
| Motor resistance | `R = 4.12 * 1.1` | Ohm |
| Motor inductance | `L = 1.31e-3` | H |
| Motor torque constant | `km = 97.5e-3` | Nm/A |
| Sample/PWM frequency | `fs = 20e3` | Hz |
| Sample time | `Ts = 1/fs` | s |
| Voltage limit | `u_max = 24` | V |
| Current limit | `i_max = 1` | A, course safety setting. |
| Motor speed limit | `om_max = 200` | rad/s |
| Pendulum angle limit | `phi2_max = 30*pi/180` | rad |

## Signals

| Signal | Symbol | Units | Source/block/channel | Notes |
|---|---|---|---|---|
| Arm angle | theta | rad | TBD | Define zero and positive direction. |
| Pendulum angle | alpha | rad | TBD | Define upright convention. |
| Arm angular velocity | theta_dot | rad/s | TBD | Measured or estimated. |
| Pendulum angular velocity | alpha_dot | rad/s | TBD | Measured or estimated. |
| Actuator command | u | TBD | TBD | Voltage, torque command, PWM, or normalized command. |

## Limits

| Limit | Value | Notes |
|---|---:|---|
| Sample time | `Ts = 1/20e3` | s, from course material. |
| Min actuator command | TBD | Depends on whether RL action is voltage, current, torque, speed setpoint, or normalized command. |
| Max actuator command | TBD | Keep below hardware/course limits. |
| Max arm angle for dry run | TBD | rad or deg |
| Max pendulum angle deviation for RL enable | `30 deg` initial reference | Course material uses `phi2_enable = 30*pi/180`, `phi2_disable = 10*pi/180`. |
| Emergency stop condition | TBD | |

## Safety Fallback

- Baseline controller used as fallback: TBD.
- State range where RL is allowed to act: TBD.
- Action saturation after RL policy output: TBD.
- Termination condition in simulation: TBD.
- Termination condition on hardware: TBD.

## Open Questions

- Is the pendulum angle reported as `0` upright or downward?
- Are encoder angles wrapped, unwrapped, or limited?
- Is the actuator command torque-like, voltage-like, PWM-like, or normalized?
- Are angular velocities measured directly or estimated from position?
- What hardware interface is used from MATLAB/Simulink?
- For RL, should the action command the inner current loop, motor speed setpoint, or the angle-controller replacement?
