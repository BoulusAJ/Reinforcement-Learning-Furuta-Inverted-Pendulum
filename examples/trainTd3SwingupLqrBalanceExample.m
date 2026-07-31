%% Train the MATLAB analytical 100 Hz TD3 swing-up setup

scriptDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(scriptDir);
addpath(projectRoot);
cd(projectRoot)
startupFurutaProject();
run("approaches/td3_swingup_lqr_balance/scripts/trainFurutaMatlabSwingupTD3.m")
