# MATLAB analytical swing-up result

Date: 2026-07-30

## Result

The MATLAB-only analytical TD3 agent successfully performs the Furuta
pendulum swing-up and reaches the configured LQR capture region. When the
existing LQR balancing controller takes over at capture, the combined
RL-swing-up and LQR-balancing controller succeeds in simulation.

The successful combination was tested with:

- `scripts/evaluateFurutaMatlabSwingupAgent.m`
- `scripts/inv_rot_pen_RL_swingup_1_test_agent_alt.slx`
- the final agent from
  `results/TD3/run_20260728_153540_td3_matlab_analytical_100hz_fast/`

The MATLAB evaluation also exports `furutaMatlabCurrentCommand`. Replaying
this current command through the analytical Simulink plant reproduces the
successful MATLAB trajectory after configuring Simulink with a fixed
1 ms step and the `ode4` solver used to match the MATLAB RK4 implementation.

## Important observation-convention difference

The successful MATLAB agent was unintentionally trained with a convention
that differs from the older and preferred Simulink project convention.

The trained MATLAB agent expects the state signs:

```matlab
theta1Error =  atan2(sin(theta1), cos(theta1));
theta2Error =  atan2(sin(theta2 - pi), cos(theta2 - pi));
omega1Error =  omega1;
omega2Error =  omega2;
```

The established Simulink convention is reference minus measurement:

```matlab
theta1Error = 0 - theta1;
theta2Error = 0 - atan2(sin(theta2 - pi), cos(theta2 - pi));
omega1Error = 0 - omega1;
omega2Error = 0 - omega2;
```

The angular velocities are clipped to `+/-25 rad/s` and divided by 25 before
being passed to the policy. Observation element 7 is the previous normalized
agent action, not the previous current command.

To use the successful MATLAB policy in
`inv_rot_pen_RL_swingup_1_test_agent_alt.slx`, the four-element error-state
vector was multiplied by `-1` before constructing the agent observation.
This adapter is required for this particular trained policy. It should not
be treated as a change to the project-wide Simulink convention.

## MATLAB analytical plant

The normalized action is converted to current and ideal motor torque:

```matlab
iCommand = 1.5 * action;
tau = param.km * iCommand;
```

The nonlinear mechanical model is:

```matlab
M(q)*qdd + C(q,qdot)*qdot + G(q) + D*qdot = [tau; 0]
```

The successful agent runs at 100 Hz. The mechanical plant is integrated at
1 kHz with ten classical RK4 substeps per agent action. No current-controller,
motor-electrical, communication, encoder, or velocity-filter dynamics are
included in the MATLAB training plant.

## Next experiment

New MATLAB training files should preserve the established Simulink
reference-minus-measurement convention and use an `ode3`-equivalent fixed-step
integration method to align with the normal Simulink configuration. Keep the
successful legacy-sign files and agent unchanged as a reproducible baseline.

Before retraining, evaluate the current 100 Hz policy while updating it at
20 Hz and holding each normalized action/current command for 50 ms. This is
only a robustness experiment: the policy was trained with a 10 ms previous
action and state-transition interval, so success at 20 Hz is possible but is
not guaranteed.
