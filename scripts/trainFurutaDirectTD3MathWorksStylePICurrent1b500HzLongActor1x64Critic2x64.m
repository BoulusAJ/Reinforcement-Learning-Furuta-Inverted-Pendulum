%% Train Furuta direct TD3 with 1b PI/current path at 500 Hz long, actor 1x64 critic 2x64
% Weto-input follow-up: keep the actor small for hardware deployment, but use
% the default-style two-hidden-layer critic for training.

% scriptDir = fileparts(mfilename("fullpath"));
% repoRoot = fileparts(scriptDir);
% cd(repoRoot)
% addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaMathWorksStylePICurrent1b500HzLongActor1x64Critic2x64TD3Config();
trainFurutaDirectTD3WithConfig(cfg);
