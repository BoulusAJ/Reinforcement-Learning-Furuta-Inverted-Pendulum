%% Train Furuta direct TD3 with 1b PI/current path at 200 Hz, 1x64 network
% Weto-input comparison run: same 1b models and MathWorks-style wide reset
% setup, with a single 64-unit hidden layer for actor and critics.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaMathWorksStylePICurrent1b200Hz1x64TD3Config();
trainFurutaDirectTD3WithConfig(cfg);
