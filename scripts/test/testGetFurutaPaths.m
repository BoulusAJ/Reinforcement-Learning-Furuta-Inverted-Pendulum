%TESTGETFURUTAPATHS Validate default, JSON, and environment path resolution.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = string(fileparts(fileparts(scriptDir)));
missingConfig = fullfile(tempdir, "furuta_missing_user_config.json");

oldEnvironment = string(getenv("FURUTA_RESULTS_ROOT"));
cleanup = onCleanup(@() setenv("FURUTA_RESULTS_ROOT", oldEnvironment));
setenv("FURUTA_RESULTS_ROOT", "");

paths = getFurutaPaths(ProjectRoot=repoRoot, UserConfigFile=missingConfig);
assert(paths.ResultsRoot == fullfile(repoRoot, "results"));
assert(paths.ResultsRootSource == "repository default");

testDir = string(tempname);
mkdir(testDir);
testDirCleanup = onCleanup(@() rmdir(testDir, "s"));
configFile = fullfile(testDir, "userConfig.json");
fid = fopen(configFile, "w");
assert(fid >= 0, "Could not create temporary user configuration.");
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid, '{"resultsRoot":"external-results"}');
clear fileCleanup

paths = getFurutaPaths(ProjectRoot=repoRoot, UserConfigFile=configFile);
assert(paths.ResultsRoot == fullfile(repoRoot, "external-results"));
assert(paths.ResultsRootSource == "user config");

environmentRoot = fullfile(testDir, "environment-results");
setenv("FURUTA_RESULTS_ROOT", environmentRoot);
paths = getFurutaPaths(ProjectRoot=repoRoot, UserConfigFile=configFile);
assert(paths.ResultsRoot == environmentRoot);
assert(paths.ResultsRootSource == "environment");

clear cleanup testDirCleanup
disp("getFurutaPaths validation passed.")
