%% Train Furuta direct TD3 with 1b PI/current path at 500 Hz
% Overnight experiment: MathWorks-style wide reset distribution, PI/current
% actuator path with integrator saturation, and hardware-rate agent timing.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaMathWorksStylePICurrent1bTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
