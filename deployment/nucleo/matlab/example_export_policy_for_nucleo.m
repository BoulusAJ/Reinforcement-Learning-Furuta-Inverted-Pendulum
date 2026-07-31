%% Export Furuta TD3 actor for Nucleo deployment
% This script may be run either from the repository root or directly.

repoRoot = localFindRepoRoot(fileparts(mfilename("fullpath")));
cd(repoRoot)
startupFurutaProject();

finalAgentFile = fullfile(repoRoot, "approaches", "td3_swingup_balance", ...
    "agents", "FurutaTD3_500Hz_long_final.mat");
outputDir = fullfile(repoRoot, "deployment", "nucleo", "generated", ...
    "td3_swingup_balance");

export = exportFurutaActorForNucleo(finalAgentFile, ...
    OutputHeader=fullfile(outputDir, "rl_policy_weights.h"), ...
    OutputMat=fullfile(outputDir, "actor_export_nucleo.mat"));

verify = verifyFurutaActorExport(finalAgentFile, export.Weights, ...
    NumTests=2000, ...
    PrintExamples=true);

disp(export)
disp(verify)

function repoRoot = localFindRepoRoot(startDir)
repoRoot = string(startDir);
while strlength(repoRoot) > 0
    hasGit = isfolder(fullfile(repoRoot, ".git")) || isfile(fullfile(repoRoot, ".git"));
    hasStartup = isfile(fullfile(repoRoot, "startupFurutaProject.m"));
    if hasGit && hasStartup
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
