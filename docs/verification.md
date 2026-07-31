# Verification

Checks run on July 31, 2026 with MATLAB R2025b on Windows.

## MATLAB Environments

The following checks passed:

```text
tests/testGetFurutaPaths.m
tests/testFurutaAnalyticalSwingupEnv.m
tests/testFurutaAnalyticalSwingupOde3Env.m
```

Both analytical environments passed `validateEnvironment` and a 100-step
zero-action simulation.

## Included Agents

`examples/evaluateTd3SwingupLqrBalanceExample.m` ran from a fresh MATLAB
session. From the default initial state `[0, 0, 0, 0]`, the included 100 Hz
agent reached the LQR capture region after 0.81 s of simulated time.

`examples/evaluateTd3SwingupBalanceExample.m` loaded the included 500 Hz agent,
initialized the copied `1b` Simulink model, and completed the simulation.

## Nucleo Actor Export

The included combined agent was exported with 2,000 random observations.

```text
maximum absolute error: 1.0784e-06
mean absolute error:    8.4769e-08
tolerance:              1.0e-05
result:                 passed
```

The generated header and MAT export are under
`deployment/nucleo/generated/td3_swingup_balance/`.

## Not Checked Yet

- Training a new agent to completion from the clean tree.
- Running the SLDRT models against connected hardware.
- Building the separate Nucleo firmware repository with the generated header.
- Exporting the TD3 swing-up with LQR balance policy to the Nucleo.
