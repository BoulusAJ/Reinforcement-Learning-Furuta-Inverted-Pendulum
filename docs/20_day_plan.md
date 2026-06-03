# 20-Day Furuta RL Plan

## Days 1-3: Model and Constraints

- Freeze the water-tank project as the reference learning artifact.
- Collect Furuta model/prototype details.
- Confirm observation signals, action signal, encoder units, sample time, actuator limits, and safety limits.
- Decide the first RL task boundary: near-upright stabilization only.

## Days 4-7: Simulation and Classical Baseline

- Get simulation running.
- Verify units and sign conventions.
- Implement LQR and/or PID balance baseline.
- Produce first baseline plots for pendulum angle, arm angle, angular velocities, and actuator command.

## Days 8-12: RL Near-Upright Stabilization

- Define observation vector and action range.
- Implement reward, termination, and reset distribution.
- Train RL for near-upright stabilization in simulation.
- Start with narrow angle and angular-velocity ranges, then widen gradually.

## Days 13-16: Robustness

- Randomize uncertain physical parameters.
- Add initial-condition sweeps and disturbances.
- Evaluate safety violations and recovery behavior.
- Compare RL and baseline under identical test cases.

## Days 17-18: Hardware Dry Runs

- Test sensor readout and actuator command path without RL control first.
- Run baseline controller with safety fallback.
- Run RL only inside conservative state and action limits.
- Log every hardware test.

## Days 19-20: Demo and Lab Meeting Story

- Prepare baseline vs RL plots.
- Prepare reward curve and training progress.
- Prepare angle response and actuator response plots.
- Document safety constraints, termination logic, and sim-to-real assumptions.
- Capture a short demo video if hardware tests are safe.

## Main Message

Do not make the Furuta project "RL solves everything." Make it:

> RL is tested as a learned controller under safety constraints, compared against a classical baseline, with sim-to-real considerations.

That is the stronger lab meeting story.
