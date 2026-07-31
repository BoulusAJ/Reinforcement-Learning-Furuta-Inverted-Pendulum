# Shared MATLAB Code

This folder contains code used by both controller approaches.

- `plant/`: nonlinear equations, parameters, and upright linearization.
- `rl/`: TD3 actor, critic, and agent-option builders.
- `analysis/`: controller metrics and oscillation estimates.
- `configuration/`: project paths and the retained training configurations.

Run `startupFurutaProject` before calling these functions directly.

The plant parameter and dynamics files came from the ZHAW rotary-pendulum lab
model used during the project. They are included here because both training
paths require them.
