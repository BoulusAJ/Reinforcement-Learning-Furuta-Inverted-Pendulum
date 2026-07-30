%TESTGETFURUTAPATHS Validate default, JSON, and environment path resolution.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = string(fileparts(fileparts(scriptDir)));
missingConfig = fullfile(tempdir, "furuta_missing_user_config.json");

oldEnvironment = string(getenv("FURUTA_RESULTS_ROOT"));
oldOutputsEnvironment = string(getenv("FURUTA_OUTPUTS_ROOT"));
cleanup = onCleanup(@() localRestoreEnvironment( ...
    oldEnvironment, oldOutputsEnvironment));
setenv("FURUTA_RESULTS_ROOT", "");
setenv("FURUTA_OUTPUTS_ROOT", "");

paths = getFurutaPaths(ProjectRoot=repoRoot, UserConfigFile=missingConfig);
assert(paths.ResultsRoot == fullfile(repoRoot, "results"));
assert(paths.OutputsRoot == fullfile(repoRoot, "outputs"));
assert(paths.ResultsRootSource == "repository default");
assert(paths.OutputsRootSource == "repository default");

testDir = string(tempname);
mkdir(testDir);
testDirCleanup = onCleanup(@() rmdir(testDir, "s"));
configFile = fullfile(testDir, "userConfig.json");
fid = fopen(configFile, "w");
assert(fid >= 0, "Could not create temporary user configuration.");
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid, ['{"resultsRoot":"external-results",' ...
    '"outputsRoot":"external-outputs"}']);
clear fileCleanup

paths = getFurutaPaths(ProjectRoot=repoRoot, UserConfigFile=configFile);
assert(paths.ResultsRoot == fullfile(repoRoot, "external-results"));
assert(paths.OutputsRoot == fullfile(repoRoot, "external-outputs"));
assert(paths.ResultsRootSource == "user config");
assert(paths.OutputsRootSource == "user config");

environmentRoot = fullfile(testDir, "environment-results");
environmentOutputsRoot = fullfile(testDir, "environment-outputs");
setenv("FURUTA_RESULTS_ROOT", environmentRoot);
setenv("FURUTA_OUTPUTS_ROOT", environmentOutputsRoot);
paths = getFurutaPaths(ProjectRoot=repoRoot, UserConfigFile=configFile);
assert(paths.ResultsRoot == environmentRoot);
assert(paths.OutputsRoot == environmentOutputsRoot);
assert(paths.ResultsRootSource == "environment");
assert(paths.OutputsRootSource == "environment");

clear cleanup testDirCleanup
disp("getFurutaPaths validation passed.")

function localRestoreEnvironment(resultsRoot, outputsRoot)
setenv("FURUTA_RESULTS_ROOT", resultsRoot);
setenv("FURUTA_OUTPUTS_ROOT", outputsRoot);
end
