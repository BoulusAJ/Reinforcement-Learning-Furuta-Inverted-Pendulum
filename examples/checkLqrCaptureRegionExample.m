%% Check and plot the LQR capture region

scriptDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(scriptDir);
addpath(projectRoot);
cd(projectRoot)
startupFurutaProject();
run("approaches/td3_swingup_lqr_balance/scripts/exampleLqrCaptureRegionCheck.m")
plotLqrCaptureRegionSlices
