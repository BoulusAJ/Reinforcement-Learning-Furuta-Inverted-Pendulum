function params = loadFurutaUcPolicyMirrorParams(exportMatFile)
%LOADFURUTAUCPOLICYMIRRORPARAMS Load codegen-friendly uC policy mirror params.
%
% This creates plain numeric variables in the base workspace so a Simulink
% MATLAB Function block can use them as parameters without passing a struct.

arguments
    exportMatFile (1,1) string = ""
end

if strlength(exportMatFile) == 0
    repoRoot = localFindRepoRoot(fileparts(mfilename("fullpath")));
    exportMatFile = fullfile(repoRoot, "results", "TD3", ...
        "run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long", ...
        "actor_export_nucleo.mat");
end

S = load(exportMatFile, "weights");
weights = S.weights;

params = struct();
params.ucW1 = single(weights.W1);
params.ucb1 = single(weights.b1(:));
params.ucW2 = single(weights.W2);
params.ucb2 = single(weights.b2(:));
params.ucW3 = single(weights.W3);
params.ucb3 = single(weights.b3(:));
params.ucActionScale = single(weights.ActionScale);
params.ucTsPolicy = single(weights.SampleTime);
params.ucCurrentLimit = single(0.5);
params.ucCurrentOffset = single(0.0205);
params.ucFinalCurrentLimit = single(4.0);

names = fieldnames(params);
for k = 1:numel(names)
    assignin("base", names{k}, params.(names{k}));
end

disp("Loaded uC policy mirror numeric parameters into base workspace:")
disp(names)
end

function repoRoot = localFindRepoRoot(startDir)
repoRoot = string(startDir);
while strlength(repoRoot) > 0
    hasGit = isfolder(fullfile(repoRoot, ".git")) || isfile(fullfile(repoRoot, ".git"));
    hasResults = isfolder(fullfile(repoRoot, "results"));
    if hasGit && hasResults
        return;
    end

    parentDir = string(fileparts(repoRoot));
    if parentDir == repoRoot
        break;
    end
    repoRoot = parentDir;
end

error("loadFurutaUcPolicyMirrorParams:RepoRootNotFound", ...
    "Could not find the repository root above %s.", startDir);
end
