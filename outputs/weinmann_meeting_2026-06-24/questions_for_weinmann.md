# Questions For Weinmann Meeting

## Highest Priority Questions

1. Why do you think the pre-MathWorks-style approach failed: reward scale, network size, curriculum/replay mismatch, training parameters, or actuator/model confounds?
2. How would you tune a reward function for swing-up plus quiet upright balance without killing the energy-injection behavior needed for swing-up?
3. Should reward terms be normalized to a certain numerical range for TD3 stability, or is relative scale and gradient signal the main issue?
4. How detailed should the simulator be before training? What level of model mismatch is acceptable if the goal is black-box/grey-box RL?
5. Would you recommend domain randomization first, residual dynamics learning first, or direct hardware fine-tuning first? Why?
6. How would you design randomization distributions for friction, damping, current scaling, delay, dead zone, and sensor noise? Bounded uniform, normal, truncated normal, or hand-picked scenarios?
7. How can we reduce or guarantee against jitter/high-frequency action near upright? Reward shaping, action-rate constraints, filters, control-barrier/safety filters, supervisor, or classical inner-loop structure?
8. Can one combine RL with control guarantees in a practical university-applied project: Lyapunov critic, control barrier functions, MPC/RL safety filter, or gain-scheduled fallback?
9. What is your experience/opinion on training on hardware for a system like this? When does it become worth the risk and effort?
10. If we collect 60-100 s of hardware interaction data with disturbances and enable/disable cycles, what is the best use: system ID, offline RL prefill, residual dynamics, validation set, or all of these?

## Evidence-Specific Questions

1. On the shared short eval, the 500 Hz long agent has near-zero final theta2 error but higher transient/effort metrics than 200 Hz. Would you call that better or more brittle?
2. The 500 Hz long hardware policy attempted lift-up and looked slightly better than matching simulation in one observation. Does that suggest the simulation is pessimistic, or just different?
3. The 200 Hz policy looked less jittery when scaled down by about 0.4 before current command. Does that indicate the action scale/current limit should be part of training, not only deployment?
4. The 500 Hz long policy saturated/current-clipped around upright until limited to +/-0.5 A. Should the reward penalize current RMS, action derivative, or frequency content directly?
5. The PI/current analytical-active broad eval has 14.5% failure rate, while Simscape-active has 86.5%. How much effort should go into making Simscape and analytical model agree before further RL?
6. Is the missing 500 Hz full evaluation a blocker before making decisions, or can hardware observation plus short eval guide the next experiment?

## Open Questions I Have Not Fully Answered Yet

1. What exact current-loop and filtering dynamics are active on the uC, and are they mirrored in simulation?
2. How much of the upright jitter is caused by static friction/dead zone versus reward/policy behavior?
3. Is previousAction in hardware exactly the previous normalized policy action, not the previous current command after scaling/clamping?
4. Does the policy see the same theta2 wrapping and sign conventions in SLDRT as in training? Early evidence says yes, but it should remain on the checklist.
5. Is the correct hardware safety strategy a hard limiter, a soft action filter, a fallback controller, or a supervisor that gates RL authority by state?
6. Should the next agent be trained at 200 Hz or 500 Hz if the uC PI loop handles current at a faster rate?
7. Should the reward include an upright-only action-rate/current-RMS penalty triggered by abs(theta2Error) < 10 deg?
8. How should isDone be handled in real hardware logs where exceeding training boundaries might be tolerable but unsafe states still need to end a trial?

## Questions You Have Asked Along The Way

- Should the current-command low-pass cutoff be adapted when the agent runs at 200 Hz?
- Where is `Ts_fast` used?
- How do we pass an agent file path relative to the repo instead of writing an absolute path?
- Are the PI controller parameters used in training the same as those on the uC?
- How do we save hardware and simulation tests in an organized way?
- What happens if two compared files have different sample times?
- Should the RL action scale to current using `cfg.Limits.CurrentMax` instead of `cfg.Limits.CurrentMax * param.km`?
- Which MAT file belongs in the generated RL Policy block?
- What maximum current did a training config use?
- What does residual learning mean?
- Should residual learning train another RL agent or improve the simulator?
- Would hardware disturbance logs be useful as experience?
- How important is `isDone` for hardware?
- Should parameter randomization happen before hardware data replay/fine-tuning?
