%TRAINFURUTASTABILIZATIONTD3 Train the active TD3 Furuta stabilization setup.
%
% The shared training script reads cfg.Agent.Algorithm from
% makeFurutaConfig.m. This wrapper is intentionally small so the command
% used for the TD3 training run is explicit.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
cd(repoRoot)
run(fullfile("scripts", "trainFurutaStabilizationDDPG.m"))
