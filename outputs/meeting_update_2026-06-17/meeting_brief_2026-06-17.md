# Furuta RL Meeting Brief - 2026-06-17

## One-line update

We now have a usable MathWorks-style TD3 simulation controller on the analytical-active plant, but the PI/current rerun shows that Simscape-active feedback is also a major robustness problem.

## Speaking version

- The Water Tank project was the workflow prototype: staged curriculum, reward scaling, stage-specific exploration, replay-buffer caution, saved artifacts, and fixed deterministic evaluations.
- The Water Tank started from MathWorks' tolerance-band reward: +10 inside |error| < 0.1, -1 outside, and a large unsafe-level penalty.
- That reward was useful for entering an acceptable band, but it did not distinguish 0.09 error from near-zero error, so it was weak for steady-state tracking.
- The project moved through normalized squared-error rewards and then to a more control-oriented reward: normalized tracking error, integral-error/PI-like terms, action effort, action-difference smoothness, unsafe penalties, and optional potential shaping.
- The tank is deceptively awkward because actuation is one-sided: the agent can add water, but if the tank is too high it can mostly only set inlet flow near zero and wait for the plant to drain naturally.
- Best-looking Water Tank behavior was not one universal win. Run 3 stage 1 was excellent for local/at-reference cases, while run 4 full curriculum was better as a broader final run but still showed asymmetric weaknesses.
- The reason to move away was that reward shaping started feeling like a moving target: one shape improved some cases but broke others, especially across raising, draining, and already-at-reference conditions.
- The curriculum idea came from that practical experience: learn a smaller control problem first, then widen reset distributions rather than asking the agent to solve the full nonlinear task at once.
- Furuta started conservatively with near-upright stabilization, controller-facing errors, normalized current/torque action, safety limits, and fixed post-stage evaluation.
- We looked at analytical swing-up literature, MathWorks hybrid SAC/PPO/classical QUBE Servo2 work, DDPG, TD3, and the MathWorks QUBE TD3 example.
- TD3 became the direct next choice because it kept the deterministic continuous-action interface but reduced DDPG's overestimation/instability issues.
- The early curriculum/direct-TD3 path was useful for debugging, but it was too fragile to make the main result.
- The stronger result is the no-curriculum MathWorks-style TD3 run with wide reset randomization.
- Best current full-grid result: 297 fixed cases, 14.48% failure rate, median final theta2 MAE about 0.35 deg, mean final theta2 MAE about 7.23 deg.
- The failures are arm-limit failures, not pendulum-limit or velocity-limit failures.
- Direct voltage reduced final upright oscillation in easy analytical cases, but it did not beat PI/current robustness on the broad fixed grid.
- The PI/current analytical-active rerun reproduced the old result exactly: 14.48% failure rate, 43/297 failures, mean final theta2 MAE 0.1261 rad.
- The voltage-command analytical-active rerun has a higher full-grid failure rate than PI/current: 21.21% versus 14.48%.
- In the easy/short cases, voltage command is much quieter at the pendulum: mean Theta2EndOscRMS is about 5.4e-8 rad, versus about 0.0067 rad for PI/current.
- Matched case theta0 = (0, 0): both survive, but voltage has near-zero final theta2 oscillation while PI/current keeps a small 7 Hz oscillation.
- Matched case theta0 = (0, pi): PI/current survives and settles with the same small oscillation; voltage command fails early in this full swing-up case.
- The PI/current Simscape-active rerun was much worse: 86.53% failure rate, 257/297 failures, mean final theta2 MAE 0.0545 rad.
- That smaller Simscape mean final MAE is misleading because most hard cases fail; robustness and failure breakdown tell the real story.
- The Simscape mismatch is therefore not just a voltage-path issue. It appears when the PI/current controller uses Simscape-active feedback too.
- The evaluation matrix is 3 arm offsets x 11 pendulum errors x 3 arm velocities x 3 pendulum velocities = 297 cases. Present it as grouped stress axes, not as 297 separate cases.
- The evaluation code now includes last-second theta2 oscillation metrics, action oscillation metrics, action-difference RMS, electrical absolute energy, and mean absolute electrical power.
- On short/easy cases, analytical and Simscape PI/current behavior is very similar: theta2 end oscillation RMS is about 0.0067 rad and oscillation frequency is about 7 Hz in both.

## Recommended next step

The PI/current rerun is complete. Use it as the main cautionary result:

1. Analytical-active reproduces the old full evaluation.
2. Simscape-active collapses on broad robustness, especially omega 5 and omega 10 rad/s cases.
3. Do not use mean final theta2 MAE alone as a headline metric when many cases fail early or hit limits.

If time allows later, rerun the direct-voltage agent with the same new metric set, but keep that as a second comparison after presenting the PI/current plant-mismatch finding.
