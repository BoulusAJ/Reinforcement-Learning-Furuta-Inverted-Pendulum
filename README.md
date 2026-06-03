# Reinforcement Learning for a Furuta Inverted Pendulum

This repository is the starting point for a Furuta inverted pendulum reinforcement-learning project. It continues the workflow learned from the water-tank DDPG project, but frames the pendulum work as a controlled comparison:

- build or import a simulation model,
- implement a classical baseline such as LQR and/or PID,
- train an RL controller for near-upright stabilization in simulation,
- test robustness with parameter randomization and disturbances,
- only then move toward hardware dry runs with safety fallback.

The goal is not "RL solves the Furuta pendulum." The stronger story is:

> RL is tested as a learned controller under safety constraints, compared against a classical baseline, with sim-to-real considerations.

## Current Status

The repo is intentionally lightweight until the lab-model details are available. Add the measured/provided hardware information in `docs/hardware_info_template.md`, then use those values to complete the simulation model and control limits.

## Project Plan

The current 20-day plan is captured in `docs/20_day_plan.md`.

## Repository Layout

| Path | Purpose |
|---|---|
| `models/` | Simulink models, MATLAB plant models, and derived linearizations. |
| `scripts/` | Training, reward, reset, baseline, and evaluation scripts. |
| `hardware/` | Hardware interface notes, safety checks, and dry-run scripts. |
| `data/` | Logged experiment data. Large generated files are ignored by default. |
| `results/` | Training curves, comparison plots, videos, and exported metrics. |
| `docs/` | Planning notes, model details, experiment design, and lab notes. |

## First Milestones

1. Fill in `docs/hardware_info_template.md` with the Furuta lab model signals, actuator limits, encoder units, sample time, and safety constraints.
2. Add or build the simulation model in `models/`.
3. Implement and validate an LQR/PID baseline before training RL.
4. Run RL only for near-upright stabilization first.
5. Compare controllers using the same initial conditions, disturbances, and safety limits.

## Water-Tank Lessons to Reuse

- Make task design explicit before training.
- Normalize reward terms so critic values stay numerically reasonable.
- Use reset distributions as a curriculum instead of jumping to the full task immediately.
- Log angle, angular velocity, arm position, action, reward, termination reason, and safety flags.
- Keep deterministic evaluation separate from exploratory training.
- Treat hardware as a guarded validation step, not as a training playground.

## Suggested MATLAB Entry Points

These files are stubs until the lab model is known:

- `scripts/makeFurutaConfig.m`
- `scripts/trainFurutaStabilizationDDPG.m`
- `scripts/rewardFcnFuruta.m`
- `scripts/localResetFcnFurutaCurriculum.m`
- `scripts/runBaselineComparison.m`
- `scripts/evaluateFurutaController.m`

Run the project from MATLAB after adding the model:

```matlab
addpath(genpath("scripts"))
cfg = makeFurutaConfig();
```

Then fill in the model and block names in `makeFurutaConfig.m`.
