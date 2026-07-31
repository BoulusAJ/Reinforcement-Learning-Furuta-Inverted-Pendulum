# Simulink Real-Time Deployment

These models run the controller on the host PC and communicate with the pendulum
firmware over USB/UART. The Nucleo continues to run the fast current loop.

## Models

- `inv_rot_pen_RL_cntr_simscape_sldrt.slx`: main host-control model.
- `inv_rot_pen_RL_cntr_simscape_sldrt_w_recording.slx`: model with recording.
- `inv_rot_pen_RL_cntr_simscape_sldrt_draft.slx`: development variant.
- `inv_rot_pen_RL_cntr_simscape_sldrt_draft_uC.slx`: onboard-policy and UART
  development variant.

The original names are retained because the model names are used inside MATLAB
initialization code and Simulink block paths.

## Initialize

```matlab
paths = startupFurutaProject();
agentFile = fullfile(paths.ProjectRoot, "approaches", ...
    "td3_swingup_balance", "agents", "FurutaTD3_500Hz_long_final.mat");

ws = initFurutaSldrtHardwareWorkspace( ...
    SerialPort="COM9", ...
    AgentFile=agentFile, ...
    OpenModel=true);
```

Change the COM port to match the machine. Check the current limit, enable
signal, encoder signs, and emergency stop before enabling the motor.

## Support Files

`support/` contains only the MATLAB helpers needed by these models: UART stream
handling, filter design, and the original pendulum initialization files. They
came from the checked-in `drehpendel` reference tree.

See `docs/model_vs_hardware_workflow.md` for recording and comparison steps.
