# TD3 Swing-Up and Balance

This approach uses one TD3 policy for the complete task: swing the pendulum up,
capture it, and balance it upright.

## Included Agent

```text
agents/FurutaTD3_500Hz_long_final.mat
```

The agent was trained at 500 Hz on the simpler `1b` analytical model. The action
is a normalized value in `[-1, 1]`, mapped to a current command. The training
configuration used a 4 A current scale.

On hardware, the Nucleo policy command was clamped to 0.5 A. This reduced the
strong balancing oscillation caused in part by static friction that was missing
from the training plant. Swing-up still worked, but required more swings. The
bench power supply was limited to about 1.5-2 A.

## Observation Vector

The policy has seven observations:

```text
[sin(theta1_error), cos(theta1_error),
 sin(theta2_error), cos(theta2_error),
 omega1_error, omega2_error,
 previous_action]
```

The Simulink convention is reference minus measurement. Upright pendulum error
is zero. Including the previous action gives the policy information about the
command held during the previous sample.

## Models

- `models/inv_rot_pen_RL_cntr_simscape_sim_1b_train.slx`: training model.
- `models/inv_rot_pen_RL_cntr_simscape_sim_1b_analytical_active.slx`:
  simulation and evaluation model.

The filenames are unchanged because model names and block paths inside Simulink
depend on them.

## Run

From the repository root:

```matlab
startupFurutaProject();
run("examples/evaluateTd3SwingupBalanceExample.m")
```

Training:

```matlab
run("examples/trainTd3SwingupBalanceExample.m")
```

Training this approach is expensive. The original run used the full Simulink
plant and took much longer than the MATLAB swing-up-only environment.

## Result

The included agent is the policy shown in the July 9 presentation and used in
the successful onboard Nucleo demonstration. Later training on the detailed
`1c` and `1d` plants did not produce a better policy.

See [training_result.md](docs/training_result.md) and
[hardware_transfer.md](docs/hardware_transfer.md).
