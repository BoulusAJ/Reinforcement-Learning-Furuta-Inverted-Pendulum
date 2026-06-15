%% Train Furuta direct TD3 with wider MathWorks-style reset distribution
% Overnight experiment: +/-90 deg pendulum errors, moderate initial angular
% velocities, 3000 episodes.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaMathWorksStyleWideTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
