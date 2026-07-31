# Model vs Hardware Test Workflow

This note describes the lightweight workflow for comparing the Furuta model
against the real SLDRT/UART system before putting the RL controller on hardware.

## Folder Layout

New comparison runs are saved under the repository root:

```text
results/model_vs_hardware/<test_name>/<timestamp>_<source>/
```

Each run folder contains:

```text
run.mat          saved raw simout, normalized signals, metadata, summary
metadata.json    human-readable run metadata
summary.csv      one-row summary metrics
plots/quicklook.png
```

Comparisons are saved under the repository root:

```text
results/model_vs_hardware/comparisons/<timestamp>_<label>/
```

## Test 1

Definition:

```text
I_cmd = 0.2 A
enable = 1 at test start
enable = 0 at t = 0.8 s
duration = 4 s
```

Purpose:

- compare real-system and model current/angle response,
- inspect friction and damping mismatch,
- inspect the free pendulum response after motor disable,
- check the sinusoidal-looking behavior in `omega2`.

The expected `simout` mux layout is:

```text
1 theta1
2 theta2
3 omega1
4 omega2
5 theta2_wrapped
6 enable
7 current_cmd
8 current
```

This matches the current model wiring:

```text
[sys_outputs0], [sys_theta2_wrapped], [sys_enable], [sys_I_cmd], [sys_I]
```

where `sys_outputs0` is:

```text
[sys_theta1, sys_theta2, sys_omega1, sys_omega2]
```

## Save Current Hardware Workspace Data

After a hardware run has produced `simout` in the MATLAB workspace:

```matlab
run("scripts/analysis/saveCurrentWorkspaceTest1HardwareRun.m")
```

## Save A Simulation Run

For a simulation run with the same muxed `simout`:

```matlab
spec = makeFurutaModelVsHardwareTest1Spec();

saved = saveFurutaModelVsHardwareRun(simout, ...
    TestName=spec.TestName, ...
    SourceType="simulation", ...
    Description=spec.Description, ...
    ModelDescription="analytical model, current path", ...
    InputDescription="I_cmd = 0.2 A until disable at 0.8 s", ...
    CurrentCommand=spec.CurrentCommand, ...
    EnableDisableTime=spec.EnableDisableTime, ...
    Duration=spec.Duration);
```

Use `SourceType="simscape"` or `SourceType="analytical"` when that distinction is
more useful than the generic `"simulation"`.

## Compare Runs

Pass two or more saved `run.mat` files:

```matlab
files = [
    "results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/<hardware_run>/run.mat"
    "results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/<simulation_run>/run.mat"
];

comparison = compareFurutaModelVsHardwareRuns(files, ...
    Label="test1_hardware_vs_analytical", ...
    ReferenceIndex=1);
```

The comparison writes overlay plots and RMS/max error metrics.

## Suggested Script Organization

Do not move everything at once while hardware work is active. A safer gradual
structure would be:

```text
scripts/
  analysis/       save, compare, plotting, metrics
  config/         make*Config.m files
  init/           workspace/model init files
  training/       train* entry points
  evaluation/     evaluate/load/finalize helpers
  simulink/       .slx models and generated model variants
  test/           smoke tests and diagnostics
  legacy/         old files kept only for reference
```

For now, new model-vs-hardware utilities live in `scripts/analysis` to avoid
adding more clutter to the top-level scripts folder.
