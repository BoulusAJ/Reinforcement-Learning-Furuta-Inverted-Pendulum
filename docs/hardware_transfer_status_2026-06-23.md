# Hardware Transfer Status - 2026-06-23

## Current Hardware Result

The 500 Hz PI/current TD3 policy from:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

was deployed on the real Furuta hardware through the SLDRT/UART current-command
path.

Observed behavior:

- the policy ran on hardware,
- it attempted swing-up/lift-up,
- the hardware behavior was slightly better than the matching simulation in the
  sense that the simulated agent got very close to lift-up but did not complete
  it,
- near upright, the policy jitters too much during balancing.

The jitter is plausibly related to mismatch between the simulation and real
actuator/mechanics, especially:

- extra bearing or slip-ring friction,
- small dead zones,
- gear/backlash-like effects,
- current-loop and command-path differences,
- unmodeled damping or stiction near upright.

This is an encouraging transfer result because the policy is not failing at the
sign-convention or gross-dynamics level. The remaining problem is robustness and
smoothness under hardware mismatch.

## Recommendation

Do not jump directly to online hardware RL as the next step. The safer and more
scientifically useful next step is simulation retraining with domain
randomization.

This means training the policy on a family of slightly different simulated
plants rather than one nominal plant. The goal is to stop the policy from
depending on fragile details of the exact simulation.

Candidate randomized quantities:

- arm viscous damping and/or Coulomb friction,
- pendulum damping,
- motor torque constant/current scaling,
- current-command delay or actuator lag,
- current-command low-pass/filter variation,
- encoder offsets/noise/quantization,
- small initial angle offsets,
- dead-zone/current threshold,
- arm/pendulum friction sign asymmetry if needed.

Use bounded randomization rather than extreme variation at first. A normal or
truncated-normal distribution around the nominal values is a reasonable starting
point.

## Reward And Policy Polishing

The near-upright jitter should be addressed in simulation before more aggressive
hardware tests.

Candidate reward/control changes:

- increase action-difference penalty near upright,
- increase velocity damping terms near upright,
- add an upright-only fine stabilization term,
- add a small action-rate limiter or low-pass filter in the hardware command
  path, then mirror it in simulation,
- keep swing-up authority available away from upright so smoothing does not
  prevent capture.

A useful pattern is conditional polishing:

```text
far from upright: allow aggressive action for swing-up
near upright: penalize jitter, current RMS, and angular velocity more strongly
```

For example, apply stronger action-smoothness and damping penalties when:

```matlab
abs(theta2Error) < deg2rad(10)
```

## Residual Dynamics Learning

Residual dynamics learning is still a useful later option, but it should not be
the first response.

A residual model would learn the mismatch:

```text
x_next_hardware - x_next_simulation
```

from logged hardware data, then augment the simulator:

```text
x_next_corrected = f_model(x, u) + g_residual(x, u)
```

This adds another modeling and validation step. It becomes attractive if domain
randomization and simple friction/actuator improvements still leave a clear,
repeatable hardware-specific failure.

## Suggested Next Sequence

1. Save and analyze the current hardware run logs.
2. Compare hardware against simulation using the model-vs-hardware scripts.
3. Add domain randomization for friction, damping, current scaling, and actuator
   timing.
4. Retrain or fine-tune the 500 Hz PI/current TD3 policy in randomized
   simulation.
5. Add near-upright jitter metrics to evaluation:
   - action RMS,
   - action-difference RMS,
   - final-window theta2 oscillation RMS,
   - current RMS,
   - theta1 drift,
   - capture success and capture time.
6. Test the randomized policy on hardware in policy-only mode with conservative
   safety clamps.
7. Consider residual dynamics learning only if a consistent mismatch remains.

## Safety Position

Hardware tests should remain policy-only for now. Do not continue TD3 learning
directly on hardware until the policy-only tests are repeatable, bounded, and
boringly safe.

Use:

- current clamp,
- arm-angle limit,
- pendulum-angle limit,
- velocity limit,
- timeout,
- hardware power cutoff,
- complete logging for every trial.

## Current Project Story

The current story is strong:

```text
A simulation-trained TD3 policy transferred far enough to attempt swing-up on
real hardware. The remaining gap is not gross sign/model failure but robustness
to real actuator and friction effects. The next step is domain-randomized
simulation training, followed by another safety-gated hardware policy test.
```
