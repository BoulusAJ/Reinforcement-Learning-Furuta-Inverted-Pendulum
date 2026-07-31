# Reproduction Guide

## Setup

1. Clone the repository.
2. Open MATLAB in the repository root.
3. Run `startupFurutaProject`.
4. Run `runtests("tests")` before training.

MATLAB R2025a was used for the final project work. A nearby release may work,
but Simulink model upgrades should be reviewed before saving.

## Generated Results

Training results and plots are intentionally kept outside `main`. By default,
new files go to local `results/` and `outputs/` folders, which are ignored.

To use another drive, copy:

```text
config/userConfig.example.json
```

to:

```text
config/userConfig.json
```

Then set absolute paths:

```json
{
  "resultsRoot": "D:/furuta/results",
  "outputsRoot": "D:/furuta/outputs"
}
```

Environment variables `FURUTA_RESULTS_ROOT` and `FURUTA_OUTPUTS_ROOT` override
the JSON file.

## Evaluate First

Run the two evaluation examples before starting training. This checks MATLAB
paths, saved-agent compatibility, model loading, and observation conventions.

## Training Notes

The 500 Hz combined controller uses Simulink and is the expensive path. The
100 Hz swing-up-only controller uses a MATLAB function environment and should be
the first training experiment on an average laptop.

RL training is not deterministic across hardware and MATLAB versions. Keep the
random seed, evaluate fixed initial conditions, and retain the best evaluation
checkpoint instead of assuming the final episode is the best policy.
