%% Evaluate the included 100 Hz TD3 swing-up agent
% The MATLAB environment stops when the LQR capture region is reached.

scriptDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(scriptDir);
addpath(projectRoot);
cd(projectRoot)
startupFurutaProject();
theta1InitialDeg = 0;
theta2InitialDeg = 0;
omega1Initial = 0;
omega2Initial = 0;
evaluationAgentHz = 100;
run("approaches/td3_swingup_lqr_balance/scripts/evaluateFurutaMatlabSwingupAgent.m")
