# Observation Conventions

Two sign conventions exist in the project. Mixing them can make a working agent
fail immediately.

## Standard Simulink Convention

The older Simulink controller work uses reference minus measurement:

```matlab
theta1Error = 0 - theta1;
theta2Error = 0 - atan2(sin(theta2 - pi), cos(theta2 - pi));
omega1Error = 0 - omega1;
omega2Error = 0 - omega2;
```

The TD3 swing-up-and-balance agent uses this convention.

## Included MATLAB Swing-Up Agent

The successful 100 Hz MATLAB swing-up agent was trained with the opposite state
signs in its observation builder. The Simulink test model
`inv_rot_pen_RL_swingup_1_test_agent_alt.slx` multiplies the error vector by
`-1` before it reaches the agent.

That conversion was tested successfully with the Simulink plant and LQR
controller. A future retraining run should use the standard convention directly
and remove the conversion only after fixed-case comparison.

## Seven-Element Observation

Both TD3 approaches use sine/cosine angle encoding, two angular velocities, and
the previous normalized action:

```text
[sin(theta1_error), cos(theta1_error),
 sin(theta2_error), cos(theta2_error),
 omega1, omega2, previous_action]
```

For the MATLAB swing-up environment, angular velocities are clipped to +/-25
rad/s and divided by 25.
