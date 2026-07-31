# TD3 Swing-Up with LQR Balance

This approach splits the task between two controllers:

1. TD3 swings the pendulum toward upright.
2. The episode ends when the full state enters a conservative LQR capture
   region.
3. The LQR controller takes over and balances the pendulum.

The switch depends on arm angle, pendulum angle, both angular velocities, the
LQR Lyapunov ellipsoid, and the current limit. It is not an angle-only switch.

## Included Agent

```text
agents/FurutaTD3_swingup_100Hz_final.mat
```

This is the best agent from
`run_20260728_153540_td3_matlab_analytical_100hz_fast`. It uses a one-layer,
64-unit actor and two 64-by-64 critics.

## Training Environment

- Agent sample time: 0.01 s, or 100 Hz.
- Mechanical integration step: 0.001 s.
- Integrator in the included successful environment: RK4.
- Plant input: current command multiplied by the motor torque constant.
- Current limit: 1.5 A.
- Observation velocities: clipped to +/-25 rad/s and divided by 25.
- Training stops on capture, safety failure, or timeout.

The MATLAB environment omits current-controller dynamics. Tests showed that
removing those dynamics did not materially change inference for the policies
being evaluated, while it reduced simulation cost substantially.

## Sign Convention Warning

The included agent uses the earlier MATLAB observation convention. Its angle and
velocity signs are opposite to the standard reference-minus-measurement
convention used by the older Simulink work.

`models/inv_rot_pen_RL_swingup_1_test_agent_alt.slx` contains the tested `-1`
correction on the error vector. With that correction, the MATLAB agent worked
with the Simulink plant and the LQR controller.

Do not remove this conversion unless the agent is retrained with the standard
Simulink convention.

## Run

```matlab
startupFurutaProject();
run("examples/evaluateTd3SwingupLqrBalanceExample.m")
```

Edit the initial angles and velocities near the top of the example or the
evaluation script. It plots all four states, current command, reward, and the
time at which the LQR controller should take over.

To open and run the included Simulink evaluation model, initialize the plant,
LQR controller, reward parameters, initial state, and saved agent first:

```matlab
ws = initializeTd3SwingupLqrSimulink( ...
    InitialTheta=[0; 0], ...
    InitialOmega=[0; 0]);
```

This opens `inv_rot_pen_RL_swingup_1_test_agent_alt.slx`. The initializer also
replaces the absolute development paths stored in the saved agent configuration
with paths from the current repository. The model retains the tested `-1`
observation adapter required by the included policy.

Training:

```matlab
run("examples/trainTd3SwingupLqrBalanceExample.m")
```

The included successful agent uses the legacy MATLAB convention and RK4. The
prepared next training path uses the standard Simulink signs and an
ODE3-equivalent fixed-step integrator:

```matlab
run("approaches/td3_swingup_lqr_balance/scripts/" + ...
    "trainFurutaMatlabSwingupOde3TD3.m")
```

Capture-region check:

```matlab
run("examples/checkLqrCaptureRegionExample.m")
```

See [lqr_capture_region.md](docs/lqr_capture_region.md),
[training_result.md](docs/training_result.md), and
[network_comparison.md](docs/network_comparison.md).
