# Reinforcement Learning for a Furuta Pendulum

This repository contains two tested control approaches for a Furuta inverted
pendulum and the MATLAB, Simulink, SLDRT, and Nucleo files used around them.

## Control Approaches

### TD3 Swing-Up and Balance

[`approaches/td3_swingup_balance`](approaches/td3_swingup_balance) contains the
older single-policy controller. One TD3 agent performs both swing-up and upright
balance at 500 Hz. The included `500Hz_long` agent worked in simulation and was
later demonstrated on the Nucleo hardware.

### TD3 Swing-Up with LQR Balance

[`approaches/td3_swingup_lqr_balance`](approaches/td3_swingup_lqr_balance)
contains the later split-controller approach. TD3 performs swing-up and stops
when the state enters an LQR capture region. The LQR controller then handles
balance. The included swing-up agent runs at 100 Hz and was trained with the
small MATLAB analytical plant.

This second approach is the better starting point for teaching. It separates
the RL task from the control-theory task and trains much faster than the full
20 kHz Simulink plant.

## Quick Start

Requirements:

- MATLAB R2025a or a compatible release
- Simulink
- Reinforcement Learning Toolbox
- Control System Toolbox
- Simulink Real-Time for the SLDRT hardware path

Open MATLAB in the repository root and run:

```matlab
paths = startupFurutaProject();
```

Evaluate the included agents:

```matlab
run("examples/evaluateTd3SwingupBalanceExample.m")
run("examples/evaluateTd3SwingupLqrBalanceExample.m")
```

Train from scratch:

```matlab
run("examples/trainTd3SwingupBalanceExample.m")
run("examples/trainTd3SwingupLqrBalanceExample.m")
```

The first training path uses Simulink and is resource-heavy. The second uses a
MATLAB analytical environment and is the practical student experiment.

## Hardware Paths

[`deployment/sldrt`](deployment/sldrt) contains the host-side Simulink Real-Time
models that communicate with the pendulum over USB/UART.

[`deployment/nucleo`](deployment/nucleo) contains actor export, verification,
generated policy headers, protocol notes, and the tested firmware settings. The
complete microcontroller firmware should remain in the separate
[`drehpendel`](https://github.com/altb71/drehpendel/tree/dev_altb) repository.

## Repository Layout

```text
approaches/   The two controller approaches, included agents, and models
shared/       Plant equations, TD3 helpers, analysis, and path configuration
deployment/   Nucleo policy export and SLDRT USB/UART integration
examples/     Short entry-point scripts
tests/        MATLAB checks for the analytical plant and project paths
docs/         Setup, history, lessons, and the file migration record
config/       Example per-user paths for generated results and outputs
```

Generated training runs are not stored in `main`. Configure an external results
folder as described in [`docs/reproduction_guide.md`](docs/reproduction_guide.md).

## Acknowledgment

This project was developed as part of a research project at the Zurich
University of Applied Sciences (ZHAW). The work was carried out by Boulus Abu
Joudom (abuj) during his employment at the Institute of Mechatronics (IMS),
ZHAW.

Thanks to project co-supervisor Michael Peter (pmic) and project supervisor
Ruprecht Altenburger (altb) for their support and input during the project.

## License

Copyright (C) 2026 Zurich University of Applied Sciences (ZHAW).

The project is licensed under the GNU General Public License version 3. You may
use, study, modify, and redistribute it under the terms of that license.
Commercial use is permitted by GPLv3; distributed modified versions must follow
the GPLv3 source and license requirements.

See [`LICENSE`](LICENSE), [`NOTICE`](NOTICE), and
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Project Status

- TD3 swing-up and balance: successful in simulation and on the Nucleo.
- TD3 swing-up with LQR balance: successful in MATLAB and Simulink evaluation.
- Nucleo deployment of the split controller: not yet implemented.
- Retraining the split controller with the standard Simulink sign convention
  and ODE3 integration: prepared as future work, not completed.

The development history remains on the archived `dev/*` branches. See
[`docs/archive_branches.md`](docs/archive_branches.md).

The checks run against this clean layout are listed in
[`docs/verification.md`](docs/verification.md).
