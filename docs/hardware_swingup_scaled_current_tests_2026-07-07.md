# Hardware Swing-Up Tests With Scaled Current Command - 2026-07-07

## Purpose

These tests record hardware swing-up attempts using the `500Hz_long` TD3 agent on
the real SLDRT/current-commanded Furuta setup. They are intended as the first
hardware data set for comparing:

- real closed-loop swing-up behavior,
- the detailed simulation running the same agent,
- later replay simulations driven by the hardware-recorded `current_cmd` and
  `enable` signals.

The recordings also provide candidate runs for averaging during the enabled
window, with time normalized so `t = 0` at motor enable.

## Controller And Actuator Scaling

These hardware tests did not use the raw training current scale directly.

The RL action output was scaled as:

```text
I_cmd = action * cfg.Action.CurrentScale * 0.4
```

instead of:

```text
I_cmd = action * cfg.Action.CurrentScale
```

After this action-to-current scaling, the command still passes through a
saturation block:

```text
-4 A <= I_cmd <= +4 A
```

The system is therefore still a current-commanded hardware test, but with the
effective learned action authority reduced to 40 percent before the final
`+/-4 A` saturation.

## Reason For This Test

The `500Hz_long` agent was trained on a simpler analytical model, so some
hardware mismatch and near-upright jitter are expected on the real system.

The scaled-current configuration was tested because it appeared to give more
stable hardware operation and less `theta2` jitter after swing-up, during the
balancing phase. The working interpretation is that the nominal agent has too
much effective high-frequency current authority on hardware, especially after
capture near upright.

## Saved Hardware Runs

Saved root for the `scale0p4`, `+/-4 A` limiter batch:

```text
results/model_vs_hardware/swingup_500hz_long_hardware_scale0p4_lim4a_20260707/
```

Each run folder contains:

- `run.mat` with raw `simout`, normalized `signals`, `enabledSignals`, and
  `swingupInfo`,
- `metadata.json`,
- `summary.csv`,
- `plots/quicklook.png`.

Current saved run folders:

| Timestamp | Duration [s] | Samples | Fs [Hz] | Max abs `I_cmd` [A] | Max abs current [A] | Run folder |
|---|---:|---:|---:|---:|---:|---|
| `20260707_171152` | 12.476 | 6239 | 500 | 1.570 | 1.352 | `results/model_vs_hardware/swingup_500hz_long_hardware_scale0p4_lim4a_20260707/20260707_171152_hardware_closed_loop/` |
| `20260707_171506` | 11.492 | 5747 | 500 | 1.572 | 1.373 | `results/model_vs_hardware/swingup_500hz_long_hardware_scale0p4_lim4a_20260707/20260707_171506_hardware_closed_loop/` |
| `20260707_171625` | 13.906 | 6954 | 500 | 1.503 | 1.348 | `results/model_vs_hardware/swingup_500hz_long_hardware_scale0p4_lim4a_20260707/20260707_171625_hardware_closed_loop/` |
| `20260707_171734` | 12.896 | 6449 | 500 | 1.569 | 1.366 | `results/model_vs_hardware/swingup_500hz_long_hardware_scale0p4_lim4a_20260707/20260707_171734_hardware_closed_loop/` |
| `20260707_171842` | 14.530 | 7266 | 500 | 1.510 | 1.352 | `results/model_vs_hardware/swingup_500hz_long_hardware_scale0p4_lim4a_20260707/20260707_171842_hardware_closed_loop/` |

Note: these five run folders were originally saved under
`swingup_500hz_long_hardware_20260707/` and were later moved into the
condition-specific `scale0p4_lim4a` folder to avoid mixing averages across
deployment settings.

## Additional Scale 1.0, +/-4 A Hardware Runs

After the reduced-current batch, a second batch was recorded with:

```text
I_cmd = action * cfg.Action.CurrentScale
-4 A <= I_cmd <= +4 A
```

Saved root:

```text
results/model_vs_hardware/swingup_500hz_long_hardware_scale1p0_lim4a_20260707/
```

Current saved run folders:

| Timestamp | Duration [s] | Samples | Fs [Hz] | Max abs `I_cmd` [A] | Max abs current [A] | Run folder |
|---|---:|---:|---:|---:|---:|---|
| `20260707_174108` | 22.120 | 11061 | 500 | 3.938 | 3.220 | `results/model_vs_hardware/swingup_500hz_long_hardware_scale1p0_lim4a_20260707/20260707_174108_hardware_closed_loop/` |
| `20260707_174246` | 12.836 | 6419 | 500 | 3.881 | 3.240 | `results/model_vs_hardware/swingup_500hz_long_hardware_scale1p0_lim4a_20260707/20260707_174246_hardware_closed_loop/` |
| `20260707_174339` | 11.510 | 5756 | 500 | 3.929 | 3.261 | `results/model_vs_hardware/swingup_500hz_long_hardware_scale1p0_lim4a_20260707/20260707_174339_hardware_closed_loop/` |
| `20260707_174521` | 12.622 | 6312 | 500 | 3.944 | 3.250 | `results/model_vs_hardware/swingup_500hz_long_hardware_scale1p0_lim4a_20260707/20260707_174521_hardware_closed_loop/` |

## Saved Overlay And Average Output

Saved comparison root:

```text
results/model_vs_hardware/comparisons/20260707_173214_selected_500hz_long_hardware_swing_ups/
```

Saved files:

```text
results/model_vs_hardware/comparisons/20260707_173214_selected_500hz_long_hardware_swing_ups/swingup_overlay_average.mat
results/model_vs_hardware/comparisons/20260707_173214_selected_500hz_long_hardware_swing_ups/plots/overlay.png
results/model_vs_hardware/comparisons/20260707_173214_selected_500hz_long_hardware_swing_ups/plots/average.png
```

The overlay plot aligns runs at the first `enable > 0.5` sample. The average
plot uses a common time grid and treats time points outside each run's available
enabled window as missing data. This allows runs with different total durations
to be overlaid directly while keeping the average statistically honest.

## Next Comparison Steps

1. Compare this scaled-current hardware batch against the detailed simulation
   running the same `500Hz_long` agent and same `cfg.Action.CurrentScale * 0.4`
   deployment scaling.
2. Replay the hardware-recorded `current_cmd` and `enable` into the detailed
   simulation and compare state outputs against hardware.
3. Repeat the same save/overlay/average process for the next hardware batches,
   explicitly documenting any changes to scaling, saturation, model file,
   agent, filtering, or enable logic.
