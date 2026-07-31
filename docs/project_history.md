# Project History

The project started with near-upright DDPG stabilization. That work established
the Simulink task, reset, reward, safety, and fixed-case evaluation setup, but it
did not produce a reliable controller.

The next phase moved to direct TD3 swing-up and followed the MathWorks Quanser
QUBE example more closely. Sine/cosine angle observations and the previous
action were important changes. This produced the `500Hz_long` agent that learned
swing-up and balance on the simpler `1b` plant.

After a review with Thomas Weinmann from ZHAW, smaller networks, alternate
observations, and a more detailed plant were tested. The detailed plant added
current, friction, encoder, filtering, and timing effects. It improved
evaluation realism, but training and fine-tuning on it did not produce a better
agent. The unsigned arc-angle observation also failed because it removed useful
direction information.

The combined `500Hz_long` policy was exported to C++ and demonstrated onboard on
the Nucleo. SLDRT was used for host control, UART tests, policy comparison, and
recording hardware behavior.

The final direction separated the task: TD3 performs swing-up, while LQR handles
balance. A small MATLAB analytical environment made training and comparison much
faster. The best included 100 Hz agent reaches the state-dependent LQR capture
region and works with the existing Simulink/LQR setup after correcting its
observation signs.
