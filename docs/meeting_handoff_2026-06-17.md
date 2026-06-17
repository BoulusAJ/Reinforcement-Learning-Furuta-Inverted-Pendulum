# Meeting Handoff - Furuta RL Project

Date: 2026-06-17
Branch: `dev/direct-td3-swingup`

This handoff is for an agent helping prepare a meeting presentation today. The
goal is to summarize where the project stands, what worked, what failed, and
what should be shown next.

## One-Sentence Project Story

RL was tested as a learned controller for the Furuta inverted pendulum under
safety constraints. The strongest result so far is a MathWorks-style TD3
controller that can swing up and stabilize in simulation, with remaining issues
around robustness, arm management, actuator-interface choice, and
analytical-vs-Simscape model mismatch.

## Current Position In The 20-Day Plan

The project is around late Days 13-16:

```text
Days 1-7: model, signals, simulation setup, baseline context mostly complete.
Days 8-12: RL training achieved via MathWorks-style TD3, after abandoning the
           earlier fragile curriculum path.
Days 13-16: current phase; robustness, fixed evaluations, actuator-interface
            diagnosis, and plant-model mismatch diagnosis.
Days 17-20: meeting story, plots, demo choices, and possible hardware dry-run
            preparation still need to be assembled.
```

Important framing:

```text
Do not present this as "RL solved the Furuta pendulum."
Present it as "RL learned a useful swing-up/stabilization policy in simulation,
but robustness and sim-to-real behavior depend strongly on reward design,
actuator interface, and plant-model consistency."
```

## Most Important Results

### Failed/Weak Path: Earlier Curriculum Direct TD3

The earlier staged/curriculum direct-TD3 approach had training slowdowns,
timeouts, and poor early-stage behavior. It was useful for debugging reward
signals and evaluation infrastructure, but it should not be the main positive
result.

Relevant docs:

```text
docs/direct_td3_swingup_plan_2026-06-11.md
docs/direct_td3_stage1_results_2026-06-11.md
```

### Stronger Path: MathWorks-Style TD3

The project moved closer to the MathWorks QUBE TD3 example:

```text
no curriculum
TD3
200 Hz agent sample time
default 64-unit actor/critic style
MathWorks-style survival-minus-cost reward
async parallel training
fixed-case post-training evaluation
```

The reward used:

```text
r = F - 0.1 * (
    theta2Error^2
  + theta1Error^2
  + 1e-2 * omega1Error^2
  + 1e-2 * omega2Error^2
  + u[k-1]^2
  + 0.3 * (u[k-1] - u[k-2])^2
)
```

Relevant doc:

```text
docs/mathworks_style_td3_runs_2026-06-16.md
```

## Key Runs

### Run 1: MathWorks-Style Narrow Randomization

Run folder:

```text
results/TD3/run_20260616_000552_td3_mathworks_style
```

Configuration:

```text
2000 episodes
theta1 reset: +/-45 deg
theta2 reset: +/-45 deg
zero initial velocities
PI/current actuator path
```

Evaluation:

```text
Full eval cases = 297
Failure rate = 0
Mean final theta2 MAE = 0.5351 rad = 30.66 deg
Median final theta2 MAE = 10.38 deg
```

Interpretation:

```text
Training completed reliably, but survival/failure rate alone was misleading.
The agent often survived without tightly stabilizing upright.
```

### Run 2: MathWorks-Style Wide Randomization

Run folder:

```text
results/TD3/run_20260616_012625_td3_mathworks_style_wide
```

Configuration:

```text
3000 episodes
theta1 reset: +/-45 deg
theta2 reset: +/-90 deg
omega1/omega2 reset: [-2, 2] rad/s
PI/current actuator path
```

Training:

```text
Final episode reward = 827.861
Final average reward = 740.433
Last 50 mean reward = 718.231
Last 50 full-length episodes = 43/50
```

Evaluation:

```text
Short eval: 7/7 passed
Short mean final theta2 MAE = 0.346 deg

Full eval cases = 297
Full failures = 43
Full failure rate = 14.48%
Full mean final theta2 MAE = 7.226 deg
Full median final theta2 MAE = 0.346 deg
```

Failure detail:

```text
All 43 failures were arm-angle limit failures.
No pendulum-limit failures.
No angular-velocity-limit failures.
Arm-limit exceedance margins were small:
  min    0.012 deg
  median 0.312 deg
  max    2.277 deg
```

Manual observations:

```text
Agent can swing up in practical inspected cases.
Agent stabilizes near upright.
Final theta2 oscillation around 0.5 deg amplitude and about 7 Hz.
Action has some 40 Hz chatter early in swing-up.
```

This is the current best controller candidate.

### Voltage Diagnostic Run

Run folder:

```text
results/TD3/run_20260616_233822_td3_mathworks_style_voltage
```

Configuration:

```text
Same general TD3/reward/training setup as run 2
Direct normalized action to voltage input
No PI/current controller in the action path
3000 episodes
```

Training finished all 3000 episodes, but final episodes had occasional
collapses:

```text
Episode 2991: reward 7.35, steps 21
Episode 2995: reward 4.30, steps 16
Episode 3000: reward 771.39, steps 1000
Final average reward = 629.95
```

Important evaluation issue:

```text
The voltage model logs voltage_command instead of current_command.
extractFurutaSignals.m was updated to support both actuator-command names.
```

Two evaluations were preserved:

```text
Simscape active:
  short_simscape_model_active_*.csv
  full_simscape_model_active_*.csv

Analytical active:
  short_final_*.csv
  full_final_*.csv
```

Results:

```text
Simscape-active short eval:
  FailureRate = 0
  MeanFinalTheta2MAE = 0.798 deg

Analytical-active short eval:
  FailureRate = 0
  MeanFinalTheta2MAE ~= 0 deg

Simscape-active full eval:
  FailureRate = 88.55%
  MeanFinalTheta2MAE = 32.19 deg

Analytical-active full eval:
  FailureRate = 21.21%
  MeanFinalTheta2MAE = 21.49 deg
```

Interpretation:

```text
The voltage policy looked much better when evaluated on the same analytical
plant it was trained on. This exposed an important plant-selection confound.

Direct voltage may reduce final upright theta2 oscillation in easy cases, but
it did not beat the PI/current path on broad robustness.
```

Current cautious actuator-interface conclusion:

```text
For the same broad MathWorks-style TD3 setup, PI/current is currently more
robust:
  PI/current run 2 full failure rate = 14.48%
  direct voltage analytical-active full failure rate = 21.21%

But direct voltage is diagnostically useful because easy upright cases show
little or no final theta2 oscillation.
```

## Important Lessons To Present

### Evaluation Must Be Fixed-Case, Not Only Training Reward

Training reward and episode survival can look good while upright accuracy is
poor. Fixed initial-condition grids are essential.

### Reward Scale Explains Residual Oscillation

Near upright, the theta2 penalty is tiny. For `0.5 deg`:

```matlab
theta2Error = deg2rad(0.5);
-0.1 * theta2Error^2  % about -7.6e-6
```

This is not a numerical problem, but tiny upright oscillations are almost free
relative to the survival reward `F = 1`.

### Angle Wrapping Needs Clear Explanation

Scalar `theta2Error` is wrapped to `[-pi, pi]`, so it has a sign discontinuity
at the downward position. The agent observation avoids exposing this directly
by using circular features:

```text
sin(theta2Error), cos(theta2Error)
```

The squared reward cost is acceptable because `+pi` and `-pi` have the same
cost. A future cleaner reward could use:

```matlab
theta2Cost = 2 * (1 - cos(theta2Error));
```

### Train And Evaluate With The Same Active Plant

The voltage run showed that using the Simscape Multibody model as the active
plant can change the control problem significantly. Since the policy was
trained on the analytical model, analytical-active evaluation is the fair
primary evaluation unless a policy is explicitly trained against Simscape
dynamics.

Meeting phrase:

```text
Simscape is useful for visualization and diagnostics, but if it is active in
the feedback loop and diverges from the analytical model, it is no longer just
visualization; it changes the policy's environment.
```

## Recommended Next Decision Gate

Before choosing voltage command or torque/current command for hardware-oriented
work, run a dry-run comparison matrix with saved agents and no learning:

```text
A) PI/current-path TD3 run 2 agent
   - analytical-active evaluation
   - Simscape-active evaluation

B) Direct-voltage TD3 agent
   - analytical-active evaluation
   - Simscape-active evaluation
```

For each case, compare:

```text
short and full fixed-evaluation summaries
theta2 final oscillation amplitude/frequency
theta1 offset and arm-limit margin
action chatter frequency
current/voltage/torque saturation
analytical-vs-Simscape trajectory divergence time
```

Interpretation:

```text
If PI/current remains more robust and matches Simscape better:
    keep PI/current as main controller path.

If voltage removes final upright oscillation but loses robustness:
    present voltage as diagnostic, not main path.

If both policies diverge with Simscape active:
    model mismatch is the next main issue.

If hardware is tested:
    do policy-only dry runs with safety fallback. Do not continue TD3 learning
    on hardware yet.
```

## Meeting Slide Outline

Suggested minimal slide/story order:

```text
1. Problem and objective
   Furuta pendulum, RL under safety constraints, compare with classical context.

2. System and signal setup
   theta1/theta2 convention, normalized action, observation features,
   safety limits, analytical and Simscape models.

3. Early approach and debugging
   Curriculum direct TD3 was slow/fragile; fixed evaluation and reward
   diagnostics were added.

4. MathWorks-style TD3 setup
   Reward equation, TD3 settings, no curriculum, fixed evaluation.

5. Main result: PI/current run 2
   Training curve, short/full evaluation summary, representative trajectory.

6. Remaining issues
   Arm-limit failures, theta2 oscillation, action chatter.

7. Voltage diagnostic
   Same training setup but voltage action path; analytical vs Simscape
   evaluation split.

8. Lessons and next steps
   Fixed-case evaluation, reward scale, plant consistency, dry-run matrix,
   hardware only with safety fallback.
```

## Files To Use

Core documentation:

```text
docs/20_day_plan.md
docs/mathworks_style_td3_runs_2026-06-16.md
Notes for Documentation/rl_project_lessons_from_setup.md
```

Best PI/current run:

```text
results/TD3/run_20260616_012625_td3_mathworks_style_wide
```

Voltage diagnostic run:

```text
results/TD3/run_20260616_233822_td3_mathworks_style_voltage
```

Reference QUBE comparison:

```text
references/MATLAB-Train-Default-TD3-Agent-to-Control-Quanser-QUBE-Pendulum/agent_1_results_1.csv
```

Useful scripts:

```text
scripts/loadFurutaFinalAgent.m
scripts/finalizeFurutaDirectTD3Run.m
scripts/evaluateFurutaController.m
scripts/extractFurutaSignals.m
scripts/makeFurutaMathWorksStyleTD3Config.m
scripts/makeFurutaMathWorksStyleWideTD3Config.m
scripts/makeFurutaMathWorksStyleVoltageTD3Config.m
```

## Current Caveats

Do not overclaim:

```text
- No hardware RL result yet.
- Direct voltage did not clearly beat PI/current on robustness.
- Simscape-active dynamics need diagnosis before they can be trusted as the
  primary feedback model.
- Reward still tolerates arm offset and tiny upright oscillations.
- Broad robustness is incomplete; some initial conditions still fail.
```

Safe conclusion:

```text
The project now has a usable simulation RL controller and a clearer experimental
story. The next scientific step is not more random training, but a controlled
dry-run matrix that separates actuator-interface effects from plant-model
mismatch before any hardware attempt.
```
