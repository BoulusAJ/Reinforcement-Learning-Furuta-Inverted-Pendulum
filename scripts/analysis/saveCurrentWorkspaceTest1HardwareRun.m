%% Save current workspace simout for Test 1 hardware run
% Test 1:
% - current command: 0.2 A constant
% - motor enabled at start
% - motor disabled at 0.8 s
% - total run time: 4 s
%
% Purpose:
% - compare real-system current/angle response against simulation,
% - inspect friction/damping differences,
% - inspect pendulum free response after disabling the motor,
% - check whether theta2 speed shows sinusoidal/free-oscillation behavior.

scriptDir = fileparts(mfilename("fullpath"));
addpath(scriptDir);

if ~exist("simout", "var")
    error("saveCurrentWorkspaceTest1HardwareRun:MissingSimout", ...
        "Expected a workspace variable named simout.");
end

saved = saveFurutaModelVsHardwareRun(simout, ...
    TestName="test1_constant_current_0p2A_disable_0p8s", ...
    SourceType="hardware", ...
    Description="Real system. Constant 0.2 A current command, motor enabled at test start and disabled at 0.8 s. Total run time 4 s.", ...
    ModelDescription="SLDRT UART hardware system", ...
    InputDescription="I_cmd = 0.2 A until disable at 0.8 s; enable = 1 then 0", ...
    CurrentCommand=0.2, ...
    EnableDisableTime=0.8, ...
    Duration=4.0);

fprintf("Saved Test 1 hardware run:\n  %s\n", saved.runDir);
