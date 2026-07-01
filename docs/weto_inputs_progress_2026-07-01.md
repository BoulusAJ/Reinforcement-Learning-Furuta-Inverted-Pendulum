# Weto Inputs Progress - 2026-07-01

This document is the main status page for the ideas discussed after the meeting
with Thomas Weinmann. Detailed numbers, tables, and run notes are kept in:

```text
docs/weto_1x64_training_experiment_2026-06-26.md
```

## Current Direction

The Weto suggestions are being tested as controlled experiments, changing one
main factor at a time:

1. smaller actor/critic networks,
2. reduced observation representations,
3. later reward-structure changes,
4. later model/parameter robustness changes.

The current working baseline for comparison is:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

The best recent small-actor comparison run is:

```text
results/TD3/run_20260629_130518_td3_mathworks_style_pi_current_1b_500hz_long_actor1x64_critic2x64
```

## Infrastructure Fixes

The old 500 Hz parallel evaluation path had a workspace bug: parallel workers
initialized with the default config, which uses a 200 Hz agent sample time,
instead of the saved run config. This contaminated older 500 Hz eval artifacts.

Fixed:

```text
evalCfg.WorkspaceConfig = cfg
```

is now carried into parallel evaluation workers.

New/updated metrics:

```text
SettlingTimeTheta2       % existing 1 degree final settling metric
SettlingTimeTheta2Pct2   % new 2% settling metric
MaxAbsOmega1Error
MaxAbsOmega2Error
```

Corrected fixed-workspace evaluations were generated for the deployed 500 Hz
long baseline and the actor1x64/critic2x64 500 Hz long run.

## Network-Size Experiments

### Actor 1x64 / Critic 1x64

Result:

```text
failed
```

The 200 Hz symmetric 1x64 actor/critic run did not learn useful swing-up. It
terminated early and appeared underfit/under-trained.

Interpretation:

```text
The critic was probably too small for this task.
```

### Actor 1x64 / Critic 2x64

Result:

```text
viable but not better overall
```

The 200 Hz version learned meaningful behavior. The 500 Hz long version had a
slightly lower corrected full-grid failure rate than the deployed 500 Hz long
baseline, but was worse as a balancing controller:

```text
more final theta2 error
more near-upright oscillation
more action variation
more electrical energy
```

Interpretation:

```text
A small actor can learn swing-up if the critic remains stronger, but this
variant is not currently a better hardware candidate than the deployed 500 Hz
long baseline.
```

## Reduced-Observation Experiments

### Pure Unsigned Arc Distance

Prepared 1c models:

```text
scripts/inv_rot_pen_RL_cntr_simscape_sim_1c_train.slx
scripts/inv_rot_pen_RL_cntr_simscape_sim_1c_analytical_active.slx
```

Observation:

```text
theta1_arc_norm
theta2_arc_norm
omega1_scaled_norm
omega2_scaled_norm
previous_action
```

Run:

```text
results/TD3/run_20260630_183029_td3_mathworks_style_pi_current_1c_500hz_long_actor1x64_critic2x64_arcobs
```

Result:

```text
failed / interrupted, not worth continuing as-is
```

The run reached 1837 episodes before the parallel pool shut down. The
interruption itself was infrastructure, but the learning trace was poor:

```text
mean episode steps: 55.7
median episode steps: 48
max episode steps: 472
last episode steps: 38
last average reward: -1073.41
```

At 500 Hz, a full 5 s episode is 2500 steps, so the policy was still failing
very early.

Best guess:

```text
Pure unsigned arc-distance observations removed too much directional
information. The agent saw distance from target but not which side of the
target it was on.
```

This is likely especially damaging for `theta1`, because arm centering and
arm-limit avoidance are directly side-dependent.

## Next Reduced-Observation Options

Do not continue the pure unsigned arc-distance observation run as-is.

Two controlled follow-up variants:

```text
A: theta1 signed shortest arc + theta2 absolute arc distance
B: theta1 absolute arc distance + theta2 signed shortest arc
```

Recommended first:

```text
A: signed theta1, unsigned theta2
```

Reason:

```text
theta1 is an arm-centering and arm-limit variable. Knowing which side of zero
the arm is on is directly useful. theta2 swing-up may still be partly recoverable
from absolute distance plus omega2 phase information.
```

If variant A is inconclusive, variant B is the natural counter-test.

## Not Yet Tried

These Weto suggestions are still pending:

- state-dependent reward shaping, for example stronger jitter/current penalties
  near upright,
- adding controller/actuator state information such as PI output or saturated
  voltage,
- model improvements such as encoder quantization, velocity filters, static
  friction, current dead-zone/offset compensation,
- parameter randomization/domain randomization.

## Current Recommendation

The next controlled experiment should restore directional information while
keeping the reduced-observation idea:

```text
500 Hz long
actor 1x64
critic 2x64
theta1 signed shortest arc
theta2 absolute arc distance
scaled omega1/omega2
previous action
same reward family for now
```

After that, move to reward shaping or robustness randomization rather than
shrinking the network further.
