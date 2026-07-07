function saved = saveCurrentWorkspaceSwingupHardwareRun(simout1, options)
%SAVECURRENTWORKSPACESWINGUPHARDWARERUN Save one hardware swing-up recording.
%
% Example:
%   saved = saveCurrentWorkspaceSwingupHardwareRun(simout1);
%
% The raw recording is saved using the existing model-vs-hardware run format.
% The saved run.mat is then extended with enabledSignals and swingupInfo for
% later run averaging and input replay.

arguments
    simout1
    options.Agent (1,1) string = "TD3 500Hz long"
    options.ActionScale (1,1) double = NaN
    options.CurrentLimitAbs (1,1) double = NaN
    options.TestDate (1,1) string = string(datetime("today", "Format", "yyyyMMdd"))
    options.TestName (1,1) string = ""
    options.RunLabel (1,1) string = "hardware_closed_loop"
    options.Description (1,1) string = ""
    options.ModelDescription (1,1) string = "SLDRT hardware system, TD3 500Hz long agent"
    options.InputDescription (1,1) string = "Closed-loop RL current command from hardware run; manual enable/disable"
    options.OutputRoot (1,1) string = ""
end

scriptDir = fileparts(mfilename("fullpath"));
addpath(scriptDir);

signals = extractFurutaModelVsHardwareSignals(simout1, ...
    SourceLabel="hardware_swingup_500hz_long");

enableMask = signals.enable > 0.5;
idxEnableOn = find(enableMask, 1, "first");

enableOnTime = NaN;
enableOffTime = NaN;
enabledDuration = NaN;

if ~isempty(idxEnableOn)
    enableOnTime = signals.t(idxEnableOn);
    idxEnableOff = find(~enableMask & signals.t > enableOnTime, 1, "first");
    if ~isempty(idxEnableOff)
        enableOffTime = signals.t(idxEnableOff);
    end
    enabledDuration = signals.t(find(enableMask, 1, "last")) - enableOnTime;
end

if strlength(options.TestName) == 0
    testName = localDefaultTestName(options.TestDate, ...
        options.ActionScale, options.CurrentLimitAbs);
else
    testName = options.TestName;
end

if strlength(options.Description) == 0
    description = "Hardware swing-up using TD3 500Hz long RL agent. SLDRT started first, motor enabled manually after roughly 1 s, then disabled before stopping connection.";
else
    description = options.Description;
end

saveOptions = { ...
    'TestName', testName, ...
    'SourceType', "hardware", ...
    'Description', description, ...
    'ModelDescription', options.ModelDescription, ...
    'InputDescription', options.InputDescription, ...
    'Duration', signals.t(end) - signals.t(1), ...
    'RunLabel', options.RunLabel};

if strlength(options.OutputRoot) > 0
    saveOptions = [saveOptions, {'OutputRoot', options.OutputRoot}];
end

saved = saveFurutaModelVsHardwareRun(simout1, saveOptions{:});

enabledSignals = localEnabledSignals(signals, enableMask, enableOnTime);

swingupInfo = struct();
swingupInfo.Agent = options.Agent;
swingupInfo.ActionScale = options.ActionScale;
swingupInfo.CurrentLimitAbs = options.CurrentLimitAbs;
swingupInfo.EnableOnTime = enableOnTime;
swingupInfo.EnableOffTime = enableOffTime;
swingupInfo.EnabledDuration = enabledDuration;
swingupInfo.EnabledSampleCount = nnz(enableMask);
swingupInfo.Note = "enabledSignals is time-shifted so t=0 is first enable sample.";

save(saved.matPath, "enabledSignals", "swingupInfo", "-append");

saved.enabledSignals = enabledSignals;
saved.swingupInfo = swingupInfo;

fprintf("Saved hardware swing-up run:\n  %s\n", saved.runDir);
fprintf("Enable ON:  %.3f s\n", enableOnTime);
fprintf("Enable OFF: %.3f s\n", enableOffTime);
end

function testName = localDefaultTestName(testDate, actionScale, currentLimitAbs)
testName = "swingup_500hz_long_hardware";

if isfinite(actionScale)
    testName = testName + "_scale" + localActionScaleSlug(actionScale);
end

if isfinite(currentLimitAbs)
    testName = testName + "_lim" + localNumberSlug(currentLimitAbs) + "a";
end

testName = testName + "_" + testDate;
end

function slug = localActionScaleSlug(value)
if abs(value - round(value)) < 1e-9
    slug = regexprep(string(sprintf("%.1f", value)), "\.", "p");
else
    slug = localNumberSlug(value);
end
end

function slug = localNumberSlug(value)
slug = regexprep(string(sprintf("%.6g", value)), "\.", "p");
slug = regexprep(slug, "-", "m");
end

function enabledSignals = localEnabledSignals(signals, enableMask, enableOnTime)
enabledSignals = struct();

if ~any(enableMask) || ~isfinite(enableOnTime)
    enabledSignals.t = [];
    enabledSignals.theta1 = [];
    enabledSignals.theta2 = [];
    enabledSignals.omega1 = [];
    enabledSignals.omega2 = [];
    enabledSignals.theta2_wrapped = [];
    enabledSignals.current_cmd = [];
    enabledSignals.current = [];
    enabledSignals.enable = [];
    return
end

enabledSignals.t = signals.t(enableMask) - enableOnTime;
enabledSignals.theta1 = signals.theta1(enableMask);
enabledSignals.theta2 = signals.theta2(enableMask);
enabledSignals.omega1 = signals.omega1(enableMask);
enabledSignals.omega2 = signals.omega2(enableMask);
enabledSignals.theta2_wrapped = signals.theta2_wrapped(enableMask);
enabledSignals.current_cmd = signals.current_cmd(enableMask);
enabledSignals.current = signals.current(enableMask);
enabledSignals.enable = signals.enable(enableMask);
end
