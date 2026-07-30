function trainFurutaSwingupCaptureTD3()
%TRAINFURUTASWINGUPCAPTURETD3 Train TD3 swing-up with capture termination.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaSwingupCaptureTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
end
