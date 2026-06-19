%% Train Furuta direct TD3 with 1b PI/current path at 500 Hz, longer run
% Same reward and 1b models as the previous 500 Hz run, with 5000 episodes
% and replay/training cadence scaled for 2500-step episodes.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaMathWorksStylePICurrent1b500HzLongTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
