# Nucleo Deployment

This folder contains the RL-specific part of the Nucleo workflow. It does not
contain the complete pendulum firmware project.

The full firmware belongs in the team repository:

```text
https://github.com/altb71/drehpendel
```

An RL branch should be created there from `dev_altb`. The exact repository and
branch status are recorded in `firmware_reference.json`.

## Contents

- `matlab/`: actor export, raw forward pass, and export verification.
- `generated/td3_swingup_balance/`: tested combined-policy headers.
- `generated/td3_swingup_lqr_balance/`: reserved for the split controller.
- `docs/`: UART, timing, shadow mode, and tested-firmware notes.
- `tests/`: deployment checks added to `main`.

## Export the Included Agent

```matlab
startupFurutaProject();
run("deployment/nucleo/matlab/example_export_policy_for_nucleo.m")
```

The script loads the included 500 Hz agent, writes `rl_policy_weights.h`, saves
the exported arrays in a MAT file, and compares the raw MATLAB forward pass with
the Reinforcement Learning Toolbox actor.

Do not copy the generated header into firmware until the verification error is
small. The previous deployment was close to single-precision numerical error.

## Tested Status

The TD3 swing-up-and-balance agent ran onboard at 500 Hz. The policy command was
limited to 0.5 A, and a small static-current offset was applied. See
`docs/tested_firmware_manifest.md`.

The TD3 swing-up with LQR balance approach has not yet been exported or tested
on the Nucleo.
