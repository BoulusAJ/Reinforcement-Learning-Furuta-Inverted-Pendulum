function paths = getFurutaPaths(options)
%GETFURUTAPATHS Resolve repository and per-user result locations.
%
% Resolution order for ResultsRoot:
%   1. FURUTA_RESULTS_ROOT environment variable
%   2. config/userConfig.json resultsRoot
%   3. <repository>/results
%
% Copy config/userConfig.example.json to config/userConfig.json to use a
% machine-specific location. The personal file is intentionally ignored by
% Git. A relative resultsRoot is resolved from ProjectRoot.

arguments
    options.ProjectRoot (1,1) string = ""
    options.UserConfigFile (1,1) string = ""
    options.CreateResultsRoot (1,1) logical = false
end

if strlength(options.ProjectRoot) == 0
    scriptDir = fileparts(mfilename("fullpath"));
    projectRoot = string(fileparts(scriptDir));
else
    projectRoot = localAbsolutePath(options.ProjectRoot, string(pwd));
end

if strlength(options.UserConfigFile) == 0
    userConfigFile = fullfile(projectRoot, "config", "userConfig.json");
else
    userConfigFile = localAbsolutePath(options.UserConfigFile, projectRoot);
end

resultsRoot = fullfile(projectRoot, "results");
source = "repository default";

if isfile(userConfigFile)
    userConfig = jsondecode(fileread(userConfigFile));
    if isfield(userConfig, "resultsRoot")
        configuredRoot = strtrim(string(userConfig.resultsRoot));
        if strlength(configuredRoot) > 0
            resultsRoot = localAbsolutePath(configuredRoot, projectRoot);
            source = "user config";
        end
    end
end

environmentRoot = strtrim(string(getenv("FURUTA_RESULTS_ROOT")));
if strlength(environmentRoot) > 0
    resultsRoot = localAbsolutePath(environmentRoot, projectRoot);
    source = "environment";
end

if options.CreateResultsRoot && ~isfolder(resultsRoot)
    mkdir(resultsRoot);
end

paths = struct();
paths.ProjectRoot = projectRoot;
paths.ResultsRoot = resultsRoot;
paths.UserConfigFile = string(userConfigFile);
paths.ResultsRootSource = source;
end

function absolutePath = localAbsolutePath(pathValue, basePath)
pathValue = string(pathValue);
if ispc
    isAbsolute = ~isempty(regexp(pathValue, "^[A-Za-z]:[\\/]", "once")) ...
        || startsWith(pathValue, "\\");
else
    isAbsolute = startsWith(pathValue, "/");
end

if isAbsolute
    absolutePath = pathValue;
else
    absolutePath = fullfile(basePath, pathValue);
end
end
