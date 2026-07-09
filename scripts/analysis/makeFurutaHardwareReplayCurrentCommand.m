function [i_cmd, info, replay] = makeFurutaHardwareReplayCurrentCommand(source, options)
%MAKEFURUTAHARDWAREREPLAYCURRENTCOMMAND Build i_cmd replay input from hardware data.
%
% Example:
%   [i_cmd, info, replay] = makeFurutaHardwareReplayCurrentCommand( ...
%       "results/model_vs_hardware/.../run.mat");
%
% The returned i_cmd is a timeseries that starts at t = 0 when enable first
% becomes true, is cropped to Duration, and is padded with zero current up to
% Duration if the enabled hardware window is shorter. replay contains the same
% aligned/cropped time base for all logged channels.

arguments
    source
    options.Duration = 10.0
    options.SampleTime (1,1) double = NaN
    options.SignalPadMode (1,1) string {mustBeMember(options.SignalPadMode, ...
        ["hold", "zero"])} = "hold"
end

signals = localSignals(source);

idxEnableOn = find(signals.enable > 0.5, 1, "first");
if isempty(idxEnableOn)
    error("makeFurutaHardwareReplayCurrentCommand:NoEnableOn", ...
        "No enable > 0.5 sample was found.");
end

enableOnTime = signals.t(idxEnableOn);
idxEnableOff = find(signals.enable < 0.5 & signals.t > enableOnTime, 1, "first");

if isempty(idxEnableOff)
    idxEnd = numel(signals.t);
    enableOffTime = NaN;
else
    idxEnd = max(idxEnableOn, idxEnableOff - 1);
    enableOffTime = signals.t(idxEnableOff);
end

t = signals.t(idxEnableOn:idxEnd) - enableOnTime;
enabledWindowDuration = t(end);

sampleTime = localSampleTime(signals, options.SampleTime);
duration = localDuration(options.Duration);

if isempty(t)
    t = 0;
end

if isfinite(duration)
    nSteps = floor(duration / sampleTime);
    tUniform = (0:nSteps).' * sampleTime;
else
    tEnd = floor(t(end) / sampleTime) * sampleTime;
    tUniform = (0:sampleTime:tEnd).';
end

replay = localReplayTimeseries(signals, idxEnableOn, idxEnd, ...
    tUniform, enabledWindowDuration, sampleTime, options.SignalPadMode);
i_cmd = replay.current_cmd;
i_cmd.Name = "i_cmd_replay";

info = struct();
info.EnableOnTime = enableOnTime;
info.EnableOffTime = enableOffTime;
info.Duration = duration;
info.SampleTime = sampleTime;
info.SourceEndTime = signals.t(end);
info.EnabledWindowDuration = enabledWindowDuration;
info.ReplayEndTime = tUniform(end);
info.NumSamples = numel(tUniform);
info.WasCroppedToDuration = isfinite(duration) && enabledWindowDuration > duration;
info.WasPaddedToDuration = isfinite(duration) && enabledWindowDuration < duration;
info.IsUniformTime = all(abs(diff(tUniform) - sampleTime) < max(1e-12, 1e-9 * sampleTime));
info.SignalPadMode = options.SignalPadMode;
info.ChannelNames = string(fieldnames(replay)).';
info.Note = "All replay timeseries are shifted so t=0 is first enable sample; Duration=[] disables crop/pad. current_cmd and enable pad with 0.";
end

function signals = localSignals(source)
if isstring(source) || ischar(source)
    S = load(source);
    if isfield(S, "signals")
        signals = S.signals;
    elseif isfield(S, "simout")
        signals = extractFurutaModelVsHardwareSignals(S.simout, ...
            SourceLabel="hardware_replay_source");
    elseif isfield(S, "simout1")
        signals = extractFurutaModelVsHardwareSignals(S.simout1, ...
            SourceLabel="hardware_replay_source");
    else
        error("makeFurutaHardwareReplayCurrentCommand:MissingSignals", ...
            "File must contain signals, simout, or simout1: %s", string(source));
    end
elseif isstruct(source) && isfield(source, "t") && isfield(source, "current_cmd")
    signals = source;
else
    signals = extractFurutaModelVsHardwareSignals(source, ...
        SourceLabel="hardware_replay_source");
end
end

function sampleTime = localSampleTime(signals, requestedSampleTime)
if isfinite(requestedSampleTime)
    sampleTime = requestedSampleTime;
elseif isfield(signals, "dt_median")
    sampleTime = signals.dt_median;
else
    sampleTime = median(diff(signals.t), "omitnan");
end
end

function duration = localDuration(requestedDuration)
if isempty(requestedDuration)
    duration = NaN;
else
    duration = requestedDuration;
end
end

function replay = localReplayTimeseries(signals, idxStart, idxEnd, ...
    tUniform, enabledWindowDuration, sampleTime, signalPadMode)
replay = struct();

fieldNames = [
    "theta1"
    "theta2"
    "omega1"
    "omega2"
    "theta2_wrapped"
    "enable"
    "current_cmd"
    "current"
];

sourceTime = signals.t(idxStart:idxEnd) - signals.t(idxStart);

for idx = 1:numel(fieldNames)
    fieldName = fieldNames(idx);
    sourceValue = signals.(fieldName)(idxStart:idxEnd);
    padValue = localPadValue(fieldName, sourceValue, signalPadMode);

    value = interp1(sourceTime(:), sourceValue(:), tUniform(:), "previous", padValue);

    if tUniform(end) > enabledWindowDuration
        value(tUniform > enabledWindowDuration) = padValue;
    end

    replay.(fieldName) = localTimeseries(fieldName, value, tUniform, sampleTime);
end

replay.i_cmd = replay.current_cmd;
replay.t = tUniform(:);
end

function padValue = localPadValue(fieldName, sourceValue, signalPadMode)
if any(fieldName == ["current_cmd", "enable"])
    padValue = 0;
elseif signalPadMode == "zero"
    padValue = 0;
else
    padValue = sourceValue(end);
end
end

function ts = localTimeseries(fieldName, value, t, sampleTime)
ts = timeseries(value(:), t(:));
ts.Name = fieldName;
ts.TimeInfo.Units = "seconds";

if any(fieldName == ["current_cmd", "current"])
    ts.DataInfo.Units = "A";
elseif any(fieldName == ["theta1", "theta2", "theta2_wrapped"])
    ts.DataInfo.Units = "rad";
elseif any(fieldName == ["omega1", "omega2"])
    ts.DataInfo.Units = "rad/s";
end

try
    ts = setuniformtime(ts, "StartTime", 0, "Interval", sampleTime);
catch
    % Older timeseries versions may not provide setuniformtime.
end
end
