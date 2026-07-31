# Lessons Learned

## What Helped

- Following the MathWorks TD3/QUBE setup was more successful than continuing the
  first DDPG configuration.
- Sine and cosine avoid angle-wrap discontinuities.
- Including the previous action helps describe the sampled system and supports
  action-change reward terms.
- Fixed evaluation cases are more useful than training reward alone.
- Keeping the best evaluation checkpoint matters because performance can fall
  again during later training.
- A small MATLAB analytical plant is enough for useful swing-up prototyping.
- Separating swing-up from LQR balance gives a smaller and clearer RL task.

## What Did Not Help

- Adding every known hardware detail to the training plant made training much
  slower and did not produce a successful policy in the available time.
- Fine-tuning a working policy on the detailed plant could destroy its useful
  behavior quickly.
- Unsigned arc-distance observations removed direction information.
- Reducing the number of gradient updates reduced time per episode but also
  delayed learning. The task still appeared to require a similar total number
  of useful updates.
- Smaller 16- and 32-unit agents could learn parts of the task, but their
  commands were more oscillatory than the 64-unit actor.
- Continued training of the 32-unit agent increased oscillation instead of
  improving it.

## Problems to Avoid

- Do not mix observation sign conventions.
- Do not use only pendulum angle as the LQR handover condition. Velocity, arm
  state, current limit, and the full LQR ellipsoid matter.
- Do not assume the final saved agent is the best agent.
- Do not compare signals without checking sample times and time alignment.
- Do not train with one current scale and deploy with another without recording
  the conversion and clamps.
- Do not put every training checkpoint and generated plot in the Git repository.
