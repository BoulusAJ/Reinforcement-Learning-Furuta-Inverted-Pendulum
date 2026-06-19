# Future Reward Notes: Minimize Pre-Capture Side Swings

Date: 2026-06-19

## Goal

The next reward-design goal is not only to make the pendulum swing up and stabilize. The desired behavior is to minimize the number of side swings or pumping cycles before the final successful swing-up and capture.

In other words, we want a controller that does not keep moving the arm back and forth to build energy if a cleaner swing-up attempt is possible.

## Distinction From Energy Minimization

Generic energy minimization is useful, but it is not identical to minimizing side swings.

An energy penalty can reduce brute-force actuation, but the agent might still use large, slow arm excursions if they are not very costly electrically. The side-swing objective is more directly about reducing unnecessary arm reversals, arm travel, and failed pre-capture attempts.

## Candidate Evaluation Metrics

Before changing the reward, it would be useful to add diagnostic metrics to the evaluation scripts:

- First capture time: first time when `abs(theta2Error)` and `abs(omega2Error)` are both below capture thresholds.
- Pre-capture arm travel: integral or sum of `abs(diff(theta1))` before first capture.
- Pre-capture arm velocity effort: integral of `abs(omega1Error)` before first capture.
- Pre-capture arm reversal count: count sign changes in `omega1Error` before capture.
- Failed upright pass count: count near-upright crossings that are not followed by capture.

These metrics would let us compare agents before adding new reward terms.

## Candidate Reward Ideas

### Pre-Capture Time Penalty

Apply a small cost while the pendulum has not been captured:

```matlab
captured = abs(theta2Error) < theta2CaptureTol && abs(omega2Error) < omega2CaptureTol;

if ~captured
    reward = reward - wTimePreCapture;
end
```

This encourages earlier swing-up attempts, but if weighted too strongly it may encourage reckless trajectories.

### Pre-Capture Arm Travel Penalty

Penalize accumulated arm motion before capture:

```matlab
if ~captured
    reward = reward - wArmTravelPreCapture * abs(theta1Error - theta1ErrorPrev);
end
```

This directly targets repeated side swings. It requires passing `theta1ErrorPrev` into the reward function or computing the difference in Simulink with a Unit Delay.

### Pre-Capture Arm Reversal Penalty

Penalize direction reversals while not captured:

```matlab
reversalDetected = sign(omega1Error) ~= sign(omega1ErrorPrev);

if ~captured && reversalDetected
    reward = reward - wArmReversalPreCapture;
end
```

This is close to the intuitive target: fewer side swings before the final swing-up. It also requires previous-step state information.

### Soft Arm Excursion Margin

Add a soft penalty before the hard safety limit:

```matlab
armMargin = max(0, abs(theta1Error) - deg2rad(45));
reward = reward - wArmMargin * armMargin^2;
```

This discourages large arm sweeps without waiting until the `isDone` boundary at `90 deg`.

### Electrical Or Actuator Energy

Penalize actuator effort using electrical power if available:

```matlab
reward = reward - wElectrical * abs(current * voltage);
```

If current and voltage are not available in the reward path, a simpler proxy is:

```matlab
reward = reward - wCurrentCommand * currentCommand^2;
```

This is useful, but should be paired with arm-travel or reversal penalties if the specific goal is fewer side swings.

## Implementation Implication

The current reward function receives current observation and previous action, but not previous state. To implement arm-travel or reversal penalties properly, we likely need one of these:

- Add previous `theta1Error` and/or `omega1Error` as inputs to `rewardFcnFuruta`.
- Add Unit Delay blocks in Simulink and pass delayed state signals into the reward function.
- Add side-swing metrics to evaluation first, then modify the reward after confirming which signals best describe the unwanted behavior.

## Suggested Next Step

Do not change the reward until the current long 500 Hz run is evaluated. Then:

1. Add side-swing metrics to `computeFurutaMetrics`.
2. Compare the best current-path and voltage-path agents using those metrics.
3. If repeated side swings remain the main weakness, add a pre-capture arm-travel or arm-reversal penalty.
4. Tune the new penalty conservatively so it reduces unnecessary pumping without preventing successful swing-up discovery.
