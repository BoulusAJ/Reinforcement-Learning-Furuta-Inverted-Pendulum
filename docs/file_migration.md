# File Migration Record

This file records how the clean `main` snapshot was assembled on July 31, 2026.

## New Files

- `README.md`: new project entry point.
- `startupFurutaProject.m`: adds maintained folders to the MATLAB path.
- `shared/configuration/findFurutaProjectRoot.m`: finds the repository root from
  nested scripts.
- All approach and deployment `README.md` files.
- Scripts under `examples/`.
- `deployment/nucleo/firmware_reference.json`.
- `docs/reproduction_guide.md`, `docs/observation_conventions.md`,
  `docs/project_history.md`, `docs/lessons_learned.md`, and
  `docs/archive_branches.md`.
- `docs/verification.md`: checks run against the clean folder layout.

## TD3 Swing-Up and Balance

| New location | Source on `dev/swing-up` |
|---|---|
| `agents/FurutaTD3_500Hz_long_final.mat` | `results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long/FurutaTD3_mathworks_style_pi_current_1b_500hz_long_final.mat` |
| `models/inv_rot_pen_RL_cntr_simscape_sim_1b_train.slx` | `scripts/inv_rot_pen_RL_cntr_simscape_sim_1b_train.slx` |
| `models/inv_rot_pen_RL_cntr_simscape_sim_1b_analytical_active.slx` | `scripts/inv_rot_pen_RL_cntr_simscape_sim_1b_analytical_active.slx` |
| `scripts/trainFurutaDirectTD3MathWorksStylePICurrent1b500HzLong.m` | same filename under `scripts/` |
| `scripts/trainFurutaDirectTD3WithConfig.m` | same filename under `scripts/` |

The model filenames were not changed because Simulink model names and block
paths depend on them.

## TD3 Swing-Up with LQR Balance

| New location | Source on `dev/swing-up` |
|---|---|
| `agents/FurutaTD3_swingup_100Hz_final.mat` | `results/TD3/run_20260728_153540_td3_matlab_analytical_100hz_fast/FurutaTD3_matlab_analytical_100hz_fast_actor1x64_critic2x64_final.mat` |
| `models/inv_rot_pen_RL_swingup_1_train.slx` | `scripts/inv_rot_pen_RL_swingup_1_train.slx` |
| `models/inv_rot_pen_RL_swingup_1_test_agent_alt.slx` | `scripts/inv_rot_pen_RL_swingup_1_test_agent_alt.slx` |
| `scripts/createFurutaAnalyticalSwingupEnv.m` | same filename under `scripts/` |
| `scripts/createFurutaAnalyticalSwingupEnvSimulinkConvention.m` | same filename under `scripts/` |
| `scripts/trainFurutaMatlabSwingupOde3TD3.m` | same filename under `scripts/` |
| `scripts/evaluateFurutaMatlabSwingupAgent.m` | same filename under `scripts/` |
| `scripts/isInLqrCaptureRegion.m` | `scripts/analysis/isInLqrCaptureRegion.m` |
| `scripts/plotLqrCaptureRegionSlices.m` | `scripts/analysis/plotLqrCaptureRegionSlices.m` |

The two included agent files were renamed to shorter names. Their original run
and full filename are recorded in each approach README.

The PNG plots referenced by the LQR capture-region and four-run comparison notes
were copied under `approaches/td3_swingup_lqr_balance/outputs/`. The larger FIG
and MAT source files were left in external project storage.

## Shared Code

Plant files came from
`references/zhaw_rotary_pendulum_lab/lab_model/`. TD3 helpers, metrics, path
configuration, and the selected configuration chain came from `scripts/`.
Paths inside copied configuration and training files were updated for the new
folder layout.

## Nucleo

The MATLAB exporter, verification code, policy mirror, protocol notes, generated
combined-policy headers, and successful firmware manifest came from:

```text
dev/nucleo-policy-deploy:uC/nucleo_policy_deploy/
```

The full PlatformIO/mbed project, copied libraries, firmware binaries, and build
folders were not copied. The intended home for the complete firmware is the
separate `altb71/drehpendel` repository.

## SLDRT

Four SLDRT models and the hardware workspace initializer came from `scripts/`.
The small UART, filter-design, and pendulum initialization support set came from
`references/drehpendel/matlab/dev/`. The full reference repository was not
copied.

## Deliberately Left Out

- Full `results/` and `outputs/` trees.
- Intermediate checkpoints and failed agents.
- `.autosave`, `.original`, `.slxc`, generated build, and `slprj` files.
- Detailed `1c` and `1d` training models.
- Meeting working files and duplicate presentation exports.
- The full Nucleo firmware project and third-party embedded libraries.
