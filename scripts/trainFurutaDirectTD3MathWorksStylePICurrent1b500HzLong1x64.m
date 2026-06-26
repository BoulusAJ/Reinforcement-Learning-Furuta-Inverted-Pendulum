%% Train Furuta direct TD3 with 1b PI/current path at 500 Hz long, 1x64 network
% Weto-input comparison run: same long 500 Hz 1b PI/current setup as the
% hardware-tested run, with a single 64-unit hidden layer for actor and critics.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaMathWorksStylePICurrent1b500HzLong1x64TD3Config();
trainFurutaDirectTD3WithConfig(cfg);
