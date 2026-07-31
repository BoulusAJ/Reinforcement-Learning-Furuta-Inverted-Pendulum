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

### 20 Hz ZOH result

The existing 100 Hz policy was evaluated from the nominal hanging state at
20 Hz with a 50 ms zero-order hold. It did not succeed. The rollout terminated
on the arm-angle safety guard after 0.20 s:

```text
theta1 = 1.6067 rad (about 92.1 deg)
theta2 = -2.5521 rad
omega1 = -9.5933 rad/s
omega2 = -12.7368 rad/s
```

The arm limit is 90 degrees. This indicates that the existing policy depends
on its 100 Hz update rate and should not be deployed at 20 Hz unchanged. A
new 20 Hz policy can still be trained and evaluated as a separate experiment.

## Reduced-update student experiment

The convention-correct ODE3 run
`run_20260730_181326_td3_matlab_ode3_student_100hz` tested whether substantially
reducing TD3 learning work per episode could make training practical on an
average student laptop. It retained the 1x64 actor and 2x64 critics, but used a
smaller update budget than the successful July 28 fast baseline.

| Setting | Successful July 28 fast baseline | July 30 student run |
|---|---:|---:|
| Actor hidden layers | 1x64 | 1x64 |
| Critic hidden layers | 2x64 | 2x64 |
| Mini-batch size | 256 | 128 |
| Epochs per learning burst | 1 | 1 |
| Maximum updates per episode | 25 | 10 |
| Maximum replay samples processed per episode | 6,400 | 1,280 |
| Maximum episodes | 5,000 | 3,000 |
| Episode duration | 5 s | 3 s |
| Observation convention | Legacy positive-state signs | Simulink reference minus measurement |
| Fixed-step integration | RK4 | ODE3-equivalent |

For context, an earlier heavyweight proposal used batch size 1,024, 10 epochs,
and up to 100 mini-batches per epoch. Its theoretical maximum was 1,000 updates
and 1,024,000 replay samples per episode. Moving first to 256/25 and then to
128/10 greatly reduced the pause caused by learning after each episode.

The July 30 result does **not** show that the observation convention caused the
failure, nor that fewer updates solve the overall training-time problem. It
shows that the reduced update budget made individual episodes advance faster,
but 3,000 episodes were not enough for this run to learn a successful swing-up
policy. The reward and Q0 trends suggested that another roughly 2,000 to 3,000
episodes might have been required.

The working hypothesis is that this task needs a minimum total amount of useful
TD3 optimization before swing-up emerges. Reducing updates per episode can
therefore require proportionally more episodes and may leave total wall-clock
training time similar. This motivated the subsequent network-size experiments:
keep a more adequate update budget while reducing actor and critic computation.
Those experiments found that 1x32/2x32 could learn swing-up but was less smooth
than the successful 1x64/2x64 policy, while 1x16/2x16 was too oscillatory.

This is an empirical conclusion from a small number of runs, not proof that all
configurations require exactly the same number of updates. A controlled follow-up
should hold the plant, reward, observation convention, reset distribution, and
random seed policy constant, then compare success against cumulative gradient
updates and wall-clock time rather than episode count alone.
