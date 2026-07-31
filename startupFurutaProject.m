function paths = startupFurutaProject()
%STARTUPFURUTAPROJECT Add the maintained project folders to the MATLAB path.

projectRoot = string(fileparts(mfilename("fullpath")));
folders = ["approaches", "shared", "deployment", "examples", "tests"];

for folder = folders
    addpath(genpath(fullfile(projectRoot, folder)));
end

paths = getFurutaPaths(ProjectRoot=projectRoot);
fprintf("Furuta project: %s\n", paths.ProjectRoot);
fprintf("Results root:  %s (%s)\n", paths.ResultsRoot, paths.ResultsRootSource);
fprintf("Outputs root:  %s (%s)\n", paths.OutputsRoot, paths.OutputsRootSource);
end
