%% Export Furuta TD3 actor for Nucleo deployment
% This script may be run either from the repository root or directly.

repoRoot = localFindRepoRoot(fileparts(mfilename("fullpath")));
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))
addpath(genpath(fullfile(repoRoot, "uC", "nucleo_policy_deploy", "matlab")))

runDir = fullfile("results", "TD3", ...
    "run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long");

finalAgentFile = fullfile(runDir, ...
    "FurutaTD3_mathworks_style_pi_current_1b_500hz_long_final.mat");

export = exportFurutaActorForNucleo(finalAgentFile, ...
    OutputHeader=fullfile("uC", "nucleo_policy_deploy", "lib", ...
        "RLPolicy", "rl_policy_weights.h"), ...
    OutputMat=fullfile(runDir, "actor_export_nucleo.mat"));

verify = verifyFurutaActorExport(finalAgentFile, export.Weights, ...
    NumTests=2000, ...
    PrintExamples=true);

disp(export)
disp(verify)

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

error("example_export_policy_for_nucleo:RepoRootNotFound", ...
    "Could not find the repository root above %s.", startDir);
end
