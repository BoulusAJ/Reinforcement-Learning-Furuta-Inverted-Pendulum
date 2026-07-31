function projectRoot = findFurutaProjectRoot(startPath)
%FINDFURUTAPROJECTROOT Find the repository root from a file or folder.

if nargin == 0 || strlength(string(startPath)) == 0
    current = string(pwd);
else
    current = string(startPath);
end

if isfile(current)
    current = string(fileparts(current));
end

while true
    if isfile(fullfile(current, "startupFurutaProject.m")) && ...
            isfolder(fullfile(current, "approaches"))
        projectRoot = current;
        return;
    end

    parent = string(fileparts(current));
    if parent == current
        error("findFurutaProjectRoot:NotFound", ...
            "Could not find the Furuta project root from: %s", startPath);
    end
    current = parent;
end
end
