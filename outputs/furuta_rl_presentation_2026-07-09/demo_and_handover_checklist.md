# Demo And Handover Checklist

## Recommended Demo Order

Use this order if you have only a few minutes.

### 1. Show Hardware Swing-Up Data

Open:

```text
results/model_vs_hardware/comparisons/20260707_173214_selected_500hz_long_hardware_swing_ups/plots/overlay.png
results/model_vs_hardware/comparisons/20260707_173214_selected_500hz_long_hardware_swing_ups/plots/average.png
```

Say:

```text
These are real hardware runs of the 500 Hz long TD3 agent. The runs are aligned
at motor enable and averaged on a common time grid.
```

Mention:

- agent: `run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long`,
- deployment scaling: `I_cmd = action * CurrentScale * 0.4`,
- final clamp: `+/-4 A`,
- logging rate: 500 Hz,
- runs saved with metadata and `run.mat`.

### 2. Show A Quicklook Hardware Run

Open one example:

```text
results/model_vs_hardware/swingup_500hz_long_hardware_scale0p4_lim4a_20260707/20260707_171152_hardware_closed_loop/plots/quicklook.png
```

Point out:

- theta1/theta2 behavior,
- current command,
- measured current,
- enable window.

### 3. Show Simple Model-vs-Hardware Diagnostic

Open:

```text
results/model_vs_hardware/comparisons/20260622_205659_test1_hardware_vs_model/plots/overlay.png
```

Say:

```text
This was an open-loop diagnostic with 0.2 A current command and motor disable
at 0.8 s. It helped separate plant mismatch from policy behavior.
```

### 4. Show Detailed Simulation Comparison

Open:

```text
results/model_vs_hardware/comparisons/20260708_230429_hardware_scale1p0_lim3a_vs_detailed_sim_v1_closed_loop/plots/overlay.png
```

Say:

```text
The detailed model is closer to hardware, but the policy/reward still needs
work for capture and quiet balance.
```

### 5. Show Repository Handover Structure

Open these folders:

```text
docs/
scripts/
scripts/analysis/
results/TD3/
results/model_vs_hardware/
```

Show these docs:

```text
docs/hardware_swingup_scaled_current_tests_2026-07-07.md
docs/detailed_model_training_results_2026-07-05.md
docs/weto_inputs_progress_2026-07-01.md
docs/domain_randomization_preparation.md
```

## Optional Live Hardware Demo

Only do this if the hardware is already safe and ready.

Suggested condition:

```text
agent: 500Hz_long
deployment scaling: 0.4
current clamp: +/-4 A
logging enabled
emergency stop ready
```

Do not run a live test if:

- the encoder zeroing is unclear,
- current command scaling is unclear,
- motor enable/disable logic is not checked,
- logging is off,
- safety clamp is not visible.

## How To Save A Hardware Run

Relevant scripts:

```text
scripts/analysis/saveCurrentWorkspaceSwingupHardwareRun.m
scripts/analysis/inspectCurrentWorkspaceSwingupHardwareRun.m
scripts/analysis/plotFurutaSwingupHardwareRuns.m
```

Typical workflow:

```matlab
addpath(genpath("scripts"));

% after a hardware run has written simout:
run("scripts/analysis/saveCurrentWorkspaceSwingupHardwareRun.m");
```

Each run should save:

```text
run.mat
metadata.json
summary.csv
plots/quicklook.png
```

## How To Compare Runs

Relevant scripts:

```text
scripts/analysis/compareFurutaModelVsHardwareRuns.m
scripts/analysis/rerunFourSwingupSimHardwareComparisons.m
scripts/analysis/plotCurrentHardwareSwingupBatches.m
```

Useful output:

```text
plots/overlay.png
plots/average.png
swingup_overlay_average.mat
comparison_metrics.csv
```

## Important Training Entry Points

Original useful 500 Hz hardware baseline:

```text
scripts/trainFurutaDirectTD3MathWorksStylePICurrent1b500HzLong.m
scripts/makeFurutaMathWorksStylePICurrent1b500HzLongTD3Config.m
```

Detailed 1c model:

```text
scripts/trainFurutaDetailed1c500HzLongScratch7000.m
scripts/makeFurutaDetailed1c500HzLongScratch7000TD3Config.m
```

Capture-tune follow-up:

```text
scripts/trainFurutaDetailed1c500HzCaptureTuneFromScratch7000.m
scripts/makeFurutaDetailed1c500HzCaptureTuneFromScratch7000TD3Config.m
```

Measured-current 1d path:

```text
scripts/trainFurutaDetailed1d500HzLongImeasScratch7000.m
scripts/makeFurutaDetailed1d500HzLongImeasScratch7000TD3Config.m
```

## Important Result Runs

Best 200 Hz baseline:

```text
results/TD3/run_20260616_012625_td3_mathworks_style_wide
```

Best 500 Hz hardware-tested baseline:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

Small actor / stronger critic comparison:

```text
results/TD3/run_20260629_130518_td3_mathworks_style_pi_current_1b_500hz_long_actor1x64_critic2x64
```

Detailed 1c long scratch result:

```text
results/TD3/run_20260708_222715_td3_mathworks_style_pi_current_1c_500hz_long_detailed_scratch7000
```

Hardware swing-up data:

```text
results/model_vs_hardware/swingup_500hz_long_hardware_scale0p4_lim4a_20260707
results/model_vs_hardware/swingup_500hz_long_hardware_scale1p0_lim4a_20260707
```

## Handover Warnings

- Some older 500 Hz evaluation files were affected by a parallel-worker
  workspace config bug. Prefer corrected `full_fixed_workspace_*` files where
  available.
- Do not compare runs unless the agent sample time, action scaling, current
  limit, and active model path are known.
- A low failure rate does not mean good balance. Check final theta2 error,
  end-window oscillation, action variation, and electrical energy.
- Hardware tests with action scale `0.4` are not the same controller as raw
  training scale `1.0`.
- Domain randomization should stay paused until the nominal detailed model can
  capture and balance.
