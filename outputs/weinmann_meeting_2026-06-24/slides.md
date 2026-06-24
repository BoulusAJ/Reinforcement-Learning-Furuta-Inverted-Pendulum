# Furuta RL Meeting With Dr. Weinmann

## 1. Why This Meeting

- We have a TD3 Furuta controller that learned in simulation.
- The 500 Hz PI/current policy transferred far enough to attempt lift-up on hardware.
- The remaining question is robustness and jitter, not basic sign/wiring failure.
- We want input on reward tuning, model detail, domain randomization, residual learning, and safe hardware learning.

## 2. Relevant Weinmann Context

- ZHAW School of Engineering, Scientific Computing and Algorithmics.
- Research areas: Machine Learning, Optimization, Visual Computing.
- Current listed projects: Raman for Process Analytics and Target Recognition using Artificial Intelligence.
- Useful angle: ask about applied ML/optimization choices, not just pendulum control.

## 3. Controller Architecture

- Observation: sin/cos of theta1 and theta2 errors, omega1, omega2, previousAction.
- Action: normalized scalar in [-1, 1].
- Hardware path: action -> current scale/clamp -> SLDRT/UART -> uC PI current loop -> motor.
- Deployment uses actor only; critics are training-only.

## 4. Why TD3

- Continuous action control.
- Two critics reduce optimistic value estimates.
- Delayed actor updates improve stability.
- Target policy smoothing discourages sharp brittle actions.
- Small actor network is deployable on SLDRT and eventually Nucleo.

## 5. What Changed After Early Failures

- Early curriculum/direct TD3 was fragile.
- MathWorks-style TD3 gave a stable baseline.
- Fixed-case evaluation became more trustworthy than training reward alone.
- Current hypothesis: reward scaling, replay/curriculum mismatch, and actuator/model confounds were the main reasons earlier attempts failed.

## 6. 200 Hz Wide Agent Evidence

- Run: run_20260616_012625_td3_mathworks_style_wide.
- Full evaluation: 297 cases.
- Failure rate: 14.48 percent.
- Mean final theta2 MAE: 7.23 deg.
- Median successful behavior is much better; failures were arm-limit related.

## 7. 500 Hz Long Agent Evidence

- Run: run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long.
- Short eval: 7/7 pass.
- Simulation final theta2 error is extremely small in short cases.
- But transient/effort metrics are higher, and hardware showed upright jitter/current chatter.

## 8. Evidence Caveat

- 200 Hz has full 297-case CSV.
- 500 Hz long currently has short eval plus a missing-cases debug subset.
- So the exact 200 Hz vs 500 Hz full robustness comparison is not yet complete.
- Present the 500 Hz simulation failure from downward start as an observed/manual issue unless we generate matching full evaluation.

## 9. Open-Loop Model vs Hardware Test

- Test 1: I_cmd = 0.2 A, disable at 0.8 s, run for 4 s.
- Until 0.8 s, signs and broad dynamics match.
- Model appears slightly faster than hardware in theta/omega response.
- After disable, divergence likely reflects friction/stiction/dead-zone mismatch.

## 10. Jitter Interpretation

- Reward may not punish small near-upright oscillation strongly enough.
- Policy may have learned to use saturation/high authority.
- Static friction and dead zones can turn small commands into stick-slip.
- Current loop and command filtering must match between training and deployment.
- Scaling/clamping helped, which suggests action authority should be trained, not only patched afterward.

## 11. Suggested Next Technical Step

- First: domain randomization in simulation.
- Randomize friction, damping, current scale, delay/lag, low-pass cutoff, dead zone, encoder noise/offset.
- Add near-upright smoothness/current penalties carefully.
- Then run policy-only hardware tests with logging.
- Use residual dynamics later if mismatch remains repeatable.

## 12. Questions For Weinmann

- How would he tune reward scale and near-upright smoothness?
- How much model detail is enough before RL training?
- Domain randomization vs residual dynamics vs hardware fine-tuning: what first?
- How to add practical control guarantees or safety filters?
- What is his experience with hardware learning and offline data reuse?
