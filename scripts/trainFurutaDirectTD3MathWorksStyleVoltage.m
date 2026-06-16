%% Train Furuta direct TD3 with MathWorks-style settings and voltage input
% Diagnostic experiment: keep the successful wide-reset TD3 setup but route the
% agent action to the direct voltage actuator path in separate Simulink models.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaMathWorksStyleVoltageTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
