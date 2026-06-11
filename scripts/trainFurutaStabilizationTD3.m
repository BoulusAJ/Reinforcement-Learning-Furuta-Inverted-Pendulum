%TRAINFURUTASTABILIZATIONTD3 Train the active TD3 Furuta setup.
%
% The shared training script reads cfg.Agent.Algorithm from
% makeFurutaConfig.m. This wrapper is intentionally small so the command
% used for the TD3 training run is explicit. On the direct swing-up branch,
% makeFurutaConfig.m defines the swing-up observation and curriculum.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
cd(repoRoot)
run(fullfile("scripts", "trainFurutaStabilizationDDPG.m"))
