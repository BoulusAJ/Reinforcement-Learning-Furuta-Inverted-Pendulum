%% Train Furuta direct TD3 with MathWorks QUBE-style settings
% Baseline no-curriculum run: +/-45 deg pendulum errors, zero initial
% velocities, 2000 episodes.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaMathWorksStyleTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
