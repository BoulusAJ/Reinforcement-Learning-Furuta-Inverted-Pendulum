# User results configuration

Training runs and experimental data can be stored outside the Git repository.
All current workflows resolve their results directory through
`scripts/getFurutaPaths.m`.

Resolution order:

1. `FURUTA_RESULTS_ROOT` environment variable
2. `config/userConfig.json`
3. the repository-local `results/` directory

For a persistent machine-specific location, copy
`config/userConfig.example.json` to `config/userConfig.json` and set:

```json
{
  "resultsRoot": "D:/Furuta-RL/results"
}
```

`config/userConfig.json` is ignored by Git. Do not commit personal absolute
paths. Forward slashes are recommended in JSON on Windows. Relative paths are
resolved from the repository root.

For a temporary MATLAB session or CI job, set the environment variable before
calling a project script:

```matlab
setenv("FURUTA_RESULTS_ROOT", "D:/Furuta-RL/results")
```

Without either override, a fresh clone uses its curated repository-local
`results/` directory. Training configurations expose the resolved location as
`cfg.ResultsRoot`; algorithm-specific runs use `cfg.Training.ResultsDir`.

To inspect the active resolution:

```matlab
paths = getFurutaPaths();
disp(paths)
```
