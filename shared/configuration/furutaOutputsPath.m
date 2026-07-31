function pathValue = furutaOutputsPath(varargin)
%FURUTAOUTPUTSPATH Build a path below the configured generated-output root.

paths = getFurutaPaths();
pathValue = fullfile(paths.OutputsRoot, varargin{:});
end
