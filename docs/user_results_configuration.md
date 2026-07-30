# User artifact storage configuration

Training runs, experimental data, and generated analysis output can be stored
outside the Git repository. Current workflows resolve these directories through
`scripts/getFurutaPaths.m`.

Resolution order:

1. `FURUTA_RESULTS_ROOT` and `FURUTA_OUTPUTS_ROOT` environment variables
2. `resultsRoot` and `outputsRoot` in `config/userConfig.json`
3. the repository-local `results/` and `outputs/` directories

For a persistent machine-specific location, copy
`config/userConfig.example.json` to `config/userConfig.json` and set:

```json
{
  "resultsRoot": "D:/Furuta-RL/results",
  "outputsRoot": "D:/Furuta-RL/outputs"
}
```

`config/userConfig.json` is ignored by Git. Do not commit personal absolute
paths. Forward slashes are recommended in JSON on Windows. Relative paths are
resolved from the repository root.

For a temporary MATLAB session or CI job, set the environment variable before
calling a project script:

```matlab
setenv("FURUTA_RESULTS_ROOT", "D:/Furuta-RL/results")
setenv("FURUTA_OUTPUTS_ROOT", "D:/Furuta-RL/outputs")
```

Without overrides, a fresh clone uses its repository-local `results/` and
`outputs/` directories. Training configurations expose the result location as
`cfg.ResultsRoot`; algorithm-specific runs use `cfg.Training.ResultsDir`.
Generated plots and analysis packages should use `paths.OutputsRoot` or
`furutaOutputsPath(...)`. Outputs selected for publication should be copied into
`docs/` and referenced there explicitly.

To inspect the active resolution:

```matlab
paths = getFurutaPaths();
disp(paths)
```
