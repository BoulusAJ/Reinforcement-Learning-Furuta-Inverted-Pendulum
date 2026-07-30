function paths = getFurutaPaths(options)
%GETFURUTAPATHS Resolve repository and per-user artifact locations.
%
% Resolution order for ResultsRoot and OutputsRoot:
%   1. FURUTA_RESULTS_ROOT / FURUTA_OUTPUTS_ROOT environment variable
%   2. config/userConfig.json resultsRoot / outputsRoot
%   3. <repository>/results and <repository>/outputs
%
% Copy config/userConfig.example.json to config/userConfig.json to use a
% machine-specific location. The personal file is intentionally ignored by
% Git. Relative roots are resolved from ProjectRoot.

arguments
    options.ProjectRoot (1,1) string = ""
    options.UserConfigFile (1,1) string = ""
    options.CreateResultsRoot (1,1) logical = false
    options.CreateOutputsRoot (1,1) logical = false
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
outputsRoot = fullfile(projectRoot, "outputs");
resultsSource = "repository default";
outputsSource = "repository default";

if isfile(userConfigFile)
    userConfig = jsondecode(fileread(userConfigFile));
    if isfield(userConfig, "resultsRoot")
        configuredRoot = strtrim(string(userConfig.resultsRoot));
        if strlength(configuredRoot) > 0
            resultsRoot = localAbsolutePath(configuredRoot, projectRoot);
            resultsSource = "user config";
        end
    end
    if isfield(userConfig, "outputsRoot")
        configuredRoot = strtrim(string(userConfig.outputsRoot));
        if strlength(configuredRoot) > 0
            outputsRoot = localAbsolutePath(configuredRoot, projectRoot);
            outputsSource = "user config";
        end
    end
end

environmentRoot = strtrim(string(getenv("FURUTA_RESULTS_ROOT")));
if strlength(environmentRoot) > 0
    resultsRoot = localAbsolutePath(environmentRoot, projectRoot);
    resultsSource = "environment";
end

environmentRoot = strtrim(string(getenv("FURUTA_OUTPUTS_ROOT")));
if strlength(environmentRoot) > 0
    outputsRoot = localAbsolutePath(environmentRoot, projectRoot);
    outputsSource = "environment";
end

if options.CreateResultsRoot && ~isfolder(resultsRoot)
    mkdir(resultsRoot);
end
if options.CreateOutputsRoot && ~isfolder(outputsRoot)
    mkdir(outputsRoot);
end

paths = struct();
paths.ProjectRoot = projectRoot;
paths.ResultsRoot = resultsRoot;
paths.OutputsRoot = outputsRoot;
paths.UserConfigFile = string(userConfigFile);
paths.ResultsRootSource = resultsSource;
paths.OutputsRootSource = outputsSource;
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
