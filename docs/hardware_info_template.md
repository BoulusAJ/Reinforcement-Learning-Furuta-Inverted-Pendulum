# Furuta Lab Model Information Template

Fill this in when the lab-model details are available.

## Plant and Mechanics

| Item | Value | Notes |
|---|---:|---|
| Rotary arm length | TBD | m |
| Pendulum length | TBD | m |
| Arm inertia | TBD | kg m^2 |
| Pendulum inertia | TBD | kg m^2 |
| Arm mass | TBD | kg |
| Pendulum mass | TBD | kg |
| Damping/friction terms | TBD | Identify from documentation or experiments. |

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
| Sample time | TBD | s |
| Min actuator command | TBD | |
| Max actuator command | TBD | |
| Max arm angle for dry run | TBD | rad or deg |
| Max pendulum angle deviation for RL enable | TBD | rad or deg |
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
