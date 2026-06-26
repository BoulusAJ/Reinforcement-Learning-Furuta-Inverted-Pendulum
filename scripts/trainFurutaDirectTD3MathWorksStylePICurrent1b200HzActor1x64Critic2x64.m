%% Train Furuta direct TD3 with 1b PI/current path at 200 Hz, actor 1x64 critic 2x64
% Weto-input follow-up: keep the actor small, but restore MATLAB default-style
% critic capacity after the symmetric 1x64 actor/critic run failed.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaMathWorksStylePICurrent1b200HzActor1x64Critic2x64TD3Config();
trainFurutaDirectTD3WithConfig(cfg);
