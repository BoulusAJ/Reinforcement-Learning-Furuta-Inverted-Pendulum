# Upright Stabilization Branch Archive

This branch records the first Furuta reinforcement-learning phase. Its scope was
limited to near-upright stabilization with DDPG, with LQR as the intended
classical reference and safety fallback.

## Purpose

The work established a controlled starting task before attempting swing-up:

- initialize the pendulum close to upright;
- use controller-facing state errors as observations;
- command a normalized, bidirectional actuator signal;
- terminate on defined arm, pendulum, and velocity safety limits;
- compare learned behavior on fixed initial conditions;
- prepare a curriculum from easy to more difficult reset conditions.

The detailed task definition is in
[`docs/rl_task_definition.md`](docs/rl_task_definition.md).

## Outcome

This branch did **not** produce a reliable learned upright controller.

- The Stage 1 DDPG agent lost the pendulum from an initial error of about one
  degree and crossed the 30-degree safety boundary after roughly 0.04 s.
- The Stage 2 agent controlled the pendulum angle more effectively, but the arm
  position eventually exceeded its limit after roughly 1.5 s.
- Investigation confirmed that these were genuine closed-loop failures, not
  false termination signals.
- A separate time-base alignment problem was found in the evaluation data
  extraction. Work to correct it began here and informed later evaluation tools.

The main result was therefore infrastructure and diagnosis, rather than a
successful policy. The branch introduced fixed-case evaluation, reward and
termination diagnostics, safer reset logic, result organization, zero-agent
smoke tests, and clearer Simulink signal conventions.

See [`docs/chat_handoff_2026-06-09.md`](docs/chat_handoff_2026-06-09.md) for the
detailed state of the work at the end of this phase.

## Useful Material

- [`scripts/trainFurutaStabilizationDDPG.m`](scripts/trainFurutaStabilizationDDPG.m):
  DDPG training entry point.
- [`scripts/rewardFcnFuruta.m`](scripts/rewardFcnFuruta.m): reward and safety
  diagnosis used in this phase.
- [`scripts/evaluateFurutaController.m`](scripts/evaluateFurutaController.m):
  deterministic controller evaluation workflow.
- [`scripts/test/checkRewardDiagnosisTheta0Case.m`](scripts/test/checkRewardDiagnosisTheta0Case.m):
  targeted reward-diagnosis check.
- [`docs/20_day_plan.md`](docs/20_day_plan.md): original project plan and scope.

## What Came After

- **`direct-td3-swingup`** replaced the unsuccessful DDPG direction with direct
  TD3 swing-up and balance. Following the MATLAB Quanser QUBE examples, it used
  sine/cosine angle observations and the previous action to preserve the Markov
  state. This produced the successful `500Hz_long` agent shown in the July 9
  presentation.
- **`dev/weto-inputs`** continued that work after the June 24 meeting with Thomas
  Weinmann (ZHAW). It tested his recommendations and introduced more detailed
  plant, sensor, filtering, and friction models. These improved evaluation
  realism, but training on the detailed plant did not produce a successful new
  agent.
- **`dev/nucleo-policy-deploy`** developed the actor export, plain C++ inference,
  UART, timing, and shadow-mode workflow. The older combined TD3 policy was
  successfully demonstrated on the Nucleo hardware.
- **`dev/swing-up`** moved to the final project direction: a compact analytical
  MATLAB environment for TD3 swing-up, with LQR capture and balancing handled as
  a separate controller. It also compares smaller networks and student-feasible
  training configurations.

## Archive Decision

Keep this branch as the record of the initial stabilization experiments. The
task-definition, safety, reset, and evaluation ideas remain useful, but the
branch should not be merged wholesale into the final main branch. Later branches
contain the successful controller approaches and the maintained workflows.
