# Furuta RL Project Handoff - 2026-06-09

This handoff summarizes the Furuta inverted rotary pendulum RL work done so far in this thread. It is written for another agent or future session to continue without rediscovering the setup, conventions, and debugging history.

## Big Picture

The project is a continuation of the user's earlier water-tank reinforcement learning project:

```text
C:\Users\abuj\Code\ZHAW\Reinforcement Learning\Control-Water-Level-in-a-Tank-Using-a-Reinforcement-Learning
```

The important lesson carried over from the water-tank project is not just "train an RL agent", but the whole workflow:

- define the task carefully,
- choose a reset distribution deliberately,
- design a reward and termination condition that can be inspected,
- compare against a classical baseline,
- use fixed evaluation cases for scientific comparison,
- organize training artifacts and stage results,
- use parallel training/evaluation where possible,
- avoid relying on MATLAB's default random evaluation because it can make the controller look better or worse depending mainly on initial conditions.

The Furuta story should therefore be:

```text
RL is tested as a learned near-upright controller under safety constraints,
compared against classical feedback,
with explicit sim-to-real and hardware-safety considerations.
```

It should not be framed as "RL solves everything."

## Repository

Repository:

```text
C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum
```

Main branch name:

```text
main
```

Current active branch:

```text
dev/upright-stabilization
```

The branch contains both committed work and uncommitted debugging changes. Always check:

```matlab
git status --short --branch
```

Known commits made so far:

```text
2800d19 Initial Furuta Inverted Rotary Pendulum RL project setup
cf0e916 Add ZHAW rotary pendulum lab references
af9212a Define near-upright RL task
a74d6c6 Align upright RL task with Simulink conventions
aa6ec52 Use controller-facing errors for RL observations
ed2d381 Use all-error observations and normalized actions
7335180 Prepare upright RL training smoke tests
1f456e1 Add fixed-case evaluation for upright RL
```

Important uncommitted or recently changed files include:

```text
.gitignore
docs/rl_task_definition.md
docs/chat_handoff_2026-06-09.md
scripts/makeFurutaConfig.m
scripts/initFurutaModelWorkspace.m
scripts/inv_rot_pen_RL_cntr_simscape_sim.slx
scripts/rewardFcnFuruta.m
scripts/extractFurutaSignals.m
scripts/computeFurutaMetrics.m
scripts/trainFurutaStabilizationDDPG.m
scripts/createFurutaRewardDiagnosisBus.m
scripts/loadFurutaStageAgent.m
scripts/test/analyzeStageTheta0Case.m
scripts/test/checkRewardDiagnosisTheta0Case.m
scripts/test/loadStageAgentForInspection.m
```

There are also generated result folders and reference callback files in the working tree. Do not clean or revert anything without checking with the user.

## Reference Material

The user provided two ZHAW reference folders:

```text
C:\Users\abuj\OneDrive - ZHAW\Work\9-Reinforcement Learning\pmic content\inv_rot_pen
C:\Users\abuj\OneDrive - ZHAW\Work\9-Reinforcement Learning\pmic content\P5_RotaryPendulum
```

These were copied into the repo under the references area with a clearer name:

```text
references/zhaw_rotary_pendulum_lab
```

The reference files include the lab model, initialization scripts, parameter functions, current controller quantities, and state-space/LQR-style controller setup.

One early question was whether the references contained an energy-based Luenberger controller. The useful takeaway was that the hardware-oriented files include classical control and observer/state-feedback ideas, but the current RL work is focused on near-upright stabilization, not swing-up.

## Project Plan Position

The original 20-day rough plan was:

```text
Days 1-3: gather model/prototype details, signals, actuator limits.
Days 4-7: get simulation running and implement LQR/PID balance baseline.
Days 8-12: train RL for near-upright stabilization in simulation.
Days 13-16: robustness testing with randomized parameters/disturbances.
Days 17-18: hardware dry runs with safety fallback.
Days 19-20: demo plots/video and baseline-vs-RL comparison.
```

Current status is around the transition from Days 8-12, but with a necessary debugging pause:

- model/references/config are mostly in place,
- Stage 1/2 agents exist from an initial training run,
- fixed post-stage evaluation infrastructure exists,
- a problem was discovered: Stage 1 fails even from a 1 degree near-upright offset,
- before retraining, evaluation metrics and signal alignment are being corrected and diagnosis signals were added.

## Naming and Sign Conventions

Use the Simulink/lab naming convention:

```text
theta1: rotary arm angle
theta2: pendulum angle
omega1: rotary arm angular velocity
omega2: pendulum angular velocity
```

Geometry/sign conventions from the user:

- `theta1` is the rotary arm angle.
- Looking from top, `theta1` counter-clockwise is positive.
- `theta2` is the pendulum angle.
- `theta2 = pi` is upright.
- Looking from the side where the rotary part points at the observer, `theta2` counter-clockwise is positive.

The hardware state-space controller uses a short-angle wrapped upright error. The RL project follows the same controller-facing error convention:

```matlab
theta2WrappedFromUpright = atan2(sin(theta2 - pi), cos(theta2 - pi));
theta2Error = 0 - theta2WrappedFromUpright;
```

Equivalent:

```matlab
theta2Error = -atan2(sin(theta2 - pi), cos(theta2 - pi));
```

The RL observation is:

```matlab
obs = [theta1Error; theta2Error; omega1Error; omega2Error]
```

The observation signals are taken after the summation/error blocks, so they match what the feedback controller sees.

Reset mapping:

```matlab
theta1_0 = -theta1Error0;
theta2_0 = pi - theta2Error0;
omega1_0 = -omega1Error0;
omega2_0 = -omega2Error0;
theta0 = [theta1_0; theta2_0];
```

Example:

```matlab
theta0 = [0; pi + deg2rad(1)]
```

corresponds to:

```matlab
theta2Error0 = -deg2rad(1)
```

## Hardware-Relevant Notes

The lab model has these hardware details from the user:

- pendulum quadrature encoder: `1024` increments, effectively `4*1024` ppr,
- rotary motor quadrature encoder: `4096` increments,
- velocity on hardware is produced using a low-pass differentiator:

```matlab
Tf = 1/(2*pi*100);
G_phi2omf = s / (Tf*s + 1);
```

For early RL training, the project currently uses the simulation velocity directly. The agreed approach was conservative:

- first get ideal/simpler near-upright RL working,
- then add hardware realism such as encoder quantization, velocity filtering, sample-time effects, actuator saturation, and current-loop dynamics.

The hardware controller has a one-shot hysteresis enable/disable switch around the upright region. It is not a swing-up controller; it enables the upright controller near upright and disables/locks out if the pendulum leaves the safe band.

## Action Convention

The RL action was changed to normalized signed action:

```matlab
a_rl in [-1, 1]
```

Reasons:

- decouples the neural network output range from physical actuator units,
- allows action limits to be changed in one mapping/gain place,
- matches common RL tooling and DDPG action bounding,
- makes saturation explicit.

The Simulink path maps this normalized action downstream to torque/current command.

Current logged signals include:

```text
action
observations
current_command
current
torque
omega1
omega2
theta1
theta2
voltage
torque_command
errors
isDone
reward
```

Signal notes from the user:

- `errors` is pre-ZOH.
- `observations` is post-ZOH.
- all signals are logged at plant `Ts` rate in logsout, but some values only update at the agent rate.
- `action` is pre-rate-adjustment.
- `torque_command` is after rate adjustment and gain factor.
- `torque` is after the PI/current-loop value.
- `errors` and `observations` vector order is:

```matlab
[theta1Error; theta2Error; omega1Error; omega2Error]
```

## Configuration and Initialization

Main config:

```text
scripts/makeFurutaConfig.m
```

Important current values:

```matlab
cfg.Model.Name = "inv_rot_pen_RL_cntr_simscape_sim";
cfg.Model.AgentBlock = cfg.Model.Name + "/RL Agent";
cfg.Model.PlantSampleTime = 1/20e3;
cfg.Agent.SampleTime = 5e-3;
cfg.Agent.LearningFrequency = 1;
cfg.Training.EpisodeDuration = 3;
cfg.Training.UseFastRestart = true;
cfg.Training.UseParallel = true;
cfg.Training.RequestedWorkers = 10;
cfg.Training.ParallelMode = "async";
cfg.Training.StepsUntilDataIsSent = 32;
```

The user asked whether fixed time step is best for training. The answer was yes: for RL training with Simulink, fixed-step simulation and explicit sample times are preferred.

Two sample times are intentionally separate:

```matlab
cfg.Model.PlantSampleTime = 1/20e3;
cfg.Agent.SampleTime = 5e-3;  % currently 200 Hz
```

Originally `cfg.Agent.SampleTime` was tested at `1e-3`, but it made simulation much slower. The user tested `1e-2`, which was much faster. Current compromise in config is `5e-3`.

Safety limits:

```matlab
cfg.Safety.MaxAbsArmAngle = deg2rad(90);
cfg.Safety.MaxAbsPendulumAngle = deg2rad(30);
cfg.Safety.MaxAbsAngularVelocity = cfg.Limits.MotorSpeedMax;
```

Initialization helper:

```text
scripts/initFurutaModelWorkspace.m
```

This helper exists because the Simulink model expects variables with the same names as the reference lab scripts. It:

- adds the reference lab model path,
- calls `get_parameter()`,
- assigns `param`, `theta0`, `Ts`, `Kp_i`, `Tn_i`, `Kp_i_over_Tn_i`, `K_oben`, `K`, etc.,
- assigns `cfg`, `rewardParams`, `safetyParams`,
- creates `FurutaRewardDiagnosisBus`.

An earlier path bug was fixed by deriving `cfg.ProjectRoot` from `mfilename("fullpath")` instead of `pwd`.

## Current Controller/Agent Setup

Agent creator:

```text
scripts/createDDPGAgentFuruta.m
```

It accepts `cfg.Agent` and uses:

```matlab
cfg.Agent.SampleTime
cfg.Agent.LearningFrequency
```

`LearningFrequency` was set explicitly because the default `-1` was questioned as not ideal for this setup.

Zero-action test helper:

```text
scripts/createZeroActionDDPGAgentFuruta.m
```

This was useful to run the Simulink model through the RL Agent block without learning/control behavior.

Stage loader:

```text
scripts/loadFurutaStageAgent.m
```

Generic loading example:

```matlab
cd("C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum")
addpath(genpath("scripts"))

loaded = loadFurutaStageAgent( ...
    fullfile("results", "run_20260604_existing_stage_results"), ...
    1);

agent = loaded.agent;
cfg = loaded.cfg;
```

This also initializes the model workspace variables and creates `FurutaRewardDiagnosisBus`.

## Curriculum

Current curriculum:

```text
Stage 1 local_small_angle:
  theta1Error range: 0
  theta2Error range: +/- 5 deg
  omega1Error range: 0
  omega2Error range: +/- 1 rad/s

Stage 2 medium_angle:
  theta1Error range: 0
  theta2Error range: +/- 12 deg
  omega1Error range: 0
  omega2Error range: +/- 3 rad/s

Stage 3 robust_near_upright:
  theta1Error range: 0
  theta2Error range: +/- 20 deg
  omega1Error range: 0
  omega2Error range: +/- 5 rad/s
```

All theta values are in radians in the config/scripts, even when described in degrees in conversation.

## Training and Result Organization

Training script:

```text
scripts/trainFurutaStabilizationDDPG.m
```

It creates:

```text
results/<run_name>/config
results/<run_name>/stages
results/<run_name>/evaluation
```

It writes:

```text
run_config.json
eval_config.mat
training_eval_cases.csv
post_stage_eval_cases.csv
stage_XX_<stage_name>_metrics.csv
stage_XX_<stage_name>_summary.csv
FurutaDDPG_near_upright_stage_XX_<stage_name>.mat
```

The newer organized run folder seen in the working tree is:

```text
results/run_20260609_082402_upright_stabilization
```

Older saved stage agents are in:

```text
results/run_20260604_existing_stage_results/stages
```

These older stage files contain `postStageEval`, but their metrics were generated before the time-base extraction fix described below.

## Evaluation Approach

The fixed-case evaluation design was intentionally inspired by the water-tank project. The user specifically wanted:

- custom evaluation instead of MATLAB default random evaluation,
- predefined initial conditions for scientific comparison,
- post-stage evaluation after each curriculum stage,
- possible parallel evaluation using the Parallel Computing Toolbox,
- result files organized similarly to the water-tank work.

Evaluation config:

```text
scripts/makeFurutaEvalConfig.m
```

Current fixed case sets:

```matlab
evalCfg.TrainingCases
evalCfg.PostStageCases
```

`PostStageCases` currently has 35 cases:

```text
theta2Error: [-20 -12 -5 0 5 12 20] deg
omega2Error: [-5 -2 0 2 5] rad/s
theta1Error: 0
omega1Error: 0
```

Evaluator:

```text
scripts/evaluateFurutaController.m
```

Options include:

```matlab
"RunInBackground"
"CloseModelWhenDone"
"UseFastRestart"
"UseParallel"
"RequestedWorkers"
"AllowPoolRestart"
```

Parallel evaluation currently uses `parfor`, not `parsim`.

Important parallel notes:

- workers initialize the model workspace,
- workers use per-worker Simulink cache/codegen folders,
- parallel evaluation disables Fast Restart to avoid JIT/cache conflicts,
- existing pools are reused unless `AllowPoolRestart=true`.

Inspection script:

```text
scripts/test/inspectPostStageEval.m
```

Loader/inspection helper:

```text
scripts/test/loadStageAgentForInspection.m
```

## Fast Restart and Parallel Notes

Fast Restart gave only modest speedup in one test:

```text
30.48 s without Fast Restart
27.87 s with Fast Restart
```

The user noticed warnings when running repeated simulations with Fast Restart:

```text
Failed to change the value of parameter 'ExperienceProcessor' ...
```

This did not mean the RL Agent block was learning during evaluation. It was related to non-tunable internal RL Agent block parameters under Fast Restart.

For debugging correctness:

- use serial evaluation,
- turn Fast Restart off,
- inspect signals.

For training speed later:

- use parallel training,
- revisit Fast Restart only after correctness is settled.

## Reward Diagnosis Bus

The reward function was extended:

```text
scripts/rewardFcnFuruta.m
```

Current signature:

```matlab
function [reward, isDone, diagnosis] = rewardFcnFuruta(obs, aRl, aRlPrev, rewardParams, safetyParams)
```

`diagnosis` contains:

```matlab
theta1Unsafe
theta2Unsafe
omega1Unsafe
omega2Unsafe
theta1Error_used_by_reward
theta2Error_used_by_reward
omega1Error_used_by_reward
omega2Error_used_by_reward
u_used_by_reward
uPrev_used_by_reward
```

A bus helper was added:

```text
scripts/createFurutaRewardDiagnosisBus.m
```

It creates a base-workspace bus object:

```matlab
FurutaRewardDiagnosisBus
```

Bus elements:

```text
theta1Unsafe               boolean
theta2Unsafe               boolean
omega1Unsafe               boolean
omega2Unsafe               boolean
theta1Error_used_by_reward double
theta2Error_used_by_reward double
omega1Error_used_by_reward double
omega2Error_used_by_reward double
u_used_by_reward           double
uPrev_used_by_reward       double
```

The Simulink MATLAB Function block should type its `diagnosis` output as:

```text
Bus: FurutaRewardDiagnosisBus
```

The user routed this diagnosis bus to a MATLAB workspace output named:

```matlab
simout
```

When running through `rlSimulinkEnv`, retrieve it using:

```matlab
simData = experiences.SimulationInfo.getSimulationData(1);
diagnosis = simData.get("simout");
```

Each field is a `timeseries`.

The delays in the reward subsystem are intentional:

```text
Delay1 breaks the algebraic loop.
Delay2 provides the previous delayed action.
```

Do not remove these casually.

## Diagnostic Scripts

### `scripts/test/analyzeStageTheta0Case.m`

Purpose:

- load saved Stage 1 and Stage 2 agents,
- compare them on `theta0 = [0; pi + deg2rad(1)]`,
- print saved post-stage summaries,
- run the one-degree fixed case,
- save diagnostic outputs under `results/diagnostics`.

### `scripts/test/checkRewardDiagnosisTheta0Case.m`

Purpose:

- load Stage 1 and Stage 2,
- run the same one-degree case,
- extract `simout` diagnosis bus,
- print unsafe flags and values used by the reward function,
- save CSV/MAT outputs under `results/diagnostics`.

This is currently the most useful debugging script.

## Diagnostic Findings So Far

The user tested Stage 1 with:

```matlab
theta0 = [0; pi + deg2rad(1)]
```

and saw that it hit `isDone` around `0.04 s`.

Direct reward-function check:

```matlab
rewardFcnFuruta([0; -deg2rad(1); 0; 0], 0, 0, cfg.Reward, cfg.Safety)
```

returns:

```text
isDone = 0
```

So the reward function is not inherently declaring the initial condition unsafe.

After routing the diagnosis bus and running `checkRewardDiagnosisTheta0Case.m`, the result was:

Stage 1:

```text
first theta2Unsafe: t = 0.040000 s
theta1Unsafe: never
omega1Unsafe: never
omega2Unsafe: never
max |theta2Error_used_by_reward| = 0.670284 rad = 38.404 deg
```

Interpretation:

- Stage 1 really loses the pendulum angle quickly.
- It crosses the configured 30 deg pendulum safety limit at about 0.04 s.
- This is not just a false `isDone`.
- For a Stage 1 agent trained on +/-5 deg, this is not acceptable.

Stage 2:

```text
first theta1Unsafe: t = 1.500000 s
theta2Unsafe: never
omega1Unsafe: never
omega2Unsafe: never
max |theta1Error_used_by_reward| = 1.58273 rad
max |theta2Error_used_by_reward| = 0.25436 rad = 14.574 deg
```

Interpretation:

- Stage 2 handles pendulum angle better.
- It eventually violates the rotary arm angle limit.
- The Stage 2 issue is more arm management than immediate pendulum loss.

## Important Evaluation Bug

The earlier post-stage metrics looked worse than the diagnosis-bus results because of a time-base alignment bug.

Affected file:

```text
scripts/extractFurutaSignals.m
```

Old behavior:

```matlab
signals.t = signals.tErrors;
signals = trimToCommonLength(signals);
```

Problem:

- `errors` is plant-rate, around 20 kHz.
- `reward` and `isDone` are agent-rate, currently 200 Hz.
- Trimming all arrays to the shortest length and interpreting them on `tErrors` makes the `isDone` time wrong.

Example:

```text
diagnosis bus: Stage 1 first theta2Unsafe at 0.04 s
old extraction: could report final time near 0.0004 s
```

Partial fix already started:

- `extractFurutaSignals.m` now records individual time vectors:

```matlab
signals.tAction
signals.tCurrentCommand
signals.tCurrent
signals.tTorque
signals.tOmega1
signals.tOmega2
signals.tTheta1
signals.tTheta2
signals.tVoltage
signals.tTorqueCommand
signals.tIsDone
signals.tReward
signals.tErrors
signals.tObservations
```

- old trimming was removed.
- `signals.t` still points to `signals.tErrors` for state/error metrics.

`computeFurutaMetrics.m` was also partially updated:

- state error integrals use the error time vector,
- action/torque/current/voltage energies use their own signal time vectors,
- integration now uses `trapz`.

This fix was started right before this handoff. The corrected post-stage metrics have not yet been rerun.

## Current Open Task

The user's latest technical request before this expanded handoff was:

```text
Rerun post-stage metrics and tell me your thoughts,
then we can look into fixing Stage 1.
I believe Stage 1 should return a stable controller,
even if not the best, for the errors it trained on at least.
Tell me if my expectations are wrong.
```

The user's expectation is correct. A Stage 1 near-upright agent trained on small errors should at least survive/stabilize cases inside its own reset distribution. It does not need to handle large-angle robustness yet, but failing from a one-degree offset is a serious issue.

Recommended continuation:

1. Finish verifying the `extractFurutaSignals.m` / `computeFurutaMetrics.m` time-base fix.
2. Rerun post-stage evaluation for Stage 1 and Stage 2.
3. Also evaluate a Stage-1-training-like subset:

```text
theta2Error in [-5 -2 0 2 5] deg
omega2Error in [-1 0 1] rad/s
```

4. Use the diagnosis bus to classify failures:

```text
theta1Unsafe
theta2Unsafe
omega1Unsafe
omega2Unsafe
```

5. If Stage 1 still fails inside its training distribution, investigate:

- action sign,
- action scaling,
- torque/current mapping,
- learned policy output near upright,
- reward shaping,
- whether training actually used the expected reset distribution,
- whether observations/action timing match training assumptions.

## Useful MATLAB Commands

Use MATLAB 2025a:

```text
C:\Program Files\matlab\bin\matlab.exe
```

R2025b in this environment did not expose all needed licenses/toolboxes in shell runs.

Load Stage 1:

```matlab
cd("C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum")
addpath(genpath("scripts"))

loaded = loadFurutaStageAgent( ...
    fullfile("results", "run_20260604_existing_stage_results"), ...
    1);

agent = loaded.agent;
cfg = loaded.cfg;
```

Run reward diagnosis check:

```matlab
run("scripts/test/checkRewardDiagnosisTheta0Case.m")
```

Rerun post-stage evaluation serially while debugging:

```matlab
loaded = loadFurutaStageAgent( ...
    fullfile("results", "run_20260604_existing_stage_results"), ...
    1);

cfg = loaded.cfg;
agent = loaded.agent;
evalCfg = makeFurutaEvalConfig(cfg);

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
actInfo = rlNumericSpec([1 1], ...
    LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, ...
    Name=cfg.Action.Name);

env = rlSimulinkEnv(cfg.Model.Name, cfg.Model.AgentBlock, obsInfo, actInfo);
env.ResetFcn = @localResetFcnFurutaCurriculum;

postStageEval = evaluateFurutaController( ...
    agent, env, evalCfg.PostStageCases, evalCfg, ...
    "ControllerName", "DDPG", ...
    "EvalSetName", "post_stage_full", ...
    "StageIndex", 1, ...
    "StageName", "local_small_angle", ...
    "RunInBackground", true, ...
    "UseFastRestart", false, ...
    "UseParallel", false);

postStageEval.summary
```

Repeat with stage index `2` and `StageName="medium_angle"`.

## Current Best Interpretation

The reward/isDone path is now observable and appears to be behaving logically. Stage 1 genuinely crosses the pendulum safety limit quickly from a very small offset. Stage 2 is better for pendulum angle but violates arm-angle safety later.

Before changing the controller/training, rerun corrected post-stage metrics using the fixed time-base extraction. If corrected metrics confirm the diagnosis, the next major debugging target is Stage 1 policy behavior near upright, especially action sign/scale and whether the learned action is destabilizing immediately.
