function pathValue = furutaResultsPath(varargin)
%FURUTARESULTSPATH Build a path below the configured results root.

paths = getFurutaPaths();
pathValue = fullfile(paths.ResultsRoot, varargin{:});
end
