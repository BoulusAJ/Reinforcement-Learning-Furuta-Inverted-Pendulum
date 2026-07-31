%% Train the 500 Hz TD3 swing-up-and-balance setup

scriptDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(scriptDir);
addpath(projectRoot);
cd(projectRoot)
startupFurutaProject();
run("approaches/td3_swingup_balance/scripts/" + ...
    "trainFurutaDirectTD3MathWorksStylePICurrent1b500HzLong.m")
