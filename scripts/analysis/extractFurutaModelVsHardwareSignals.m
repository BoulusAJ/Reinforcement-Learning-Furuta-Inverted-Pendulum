function signals = extractFurutaModelVsHardwareSignals(simout, options)
%EXTRACTFURUTAMODELVSHARDWARESIGNALS Normalize model-vs-hardware simout data.
%
% Expected mux layout:
%   [sys_outputs0]       -> theta1, theta2, omega1, omega2
%   [sys_theta2_wrapped] -> wrapped pendulum angle
%   [sys_enable]         -> motor enable command
%   [sys_I_cmd]          -> current command [A]
%   [sys_I]              -> measured/model current [A]

arguments
    simout
    options.SampleTime (1,1) double = NaN
    options.SourceLabel (1,1) string = ""
end

[t, data] = localTimeAndData(simout, options.SampleTime);

if size(data, 2) < 8
    error("extractFurutaModelVsHardwareSignals:NotEnoughColumns", ...
        "Expected at least 8 columns from the mux, but found %d.", size(data, 2));
end

data = data(:, 1:8);

signals = struct();
signals.sourceLabel = options.SourceLabel;
signals.t = t(:);
signals.theta1 = data(:, 1);
signals.theta2 = data(:, 2);
signals.omega1 = data(:, 3);
signals.omega2 = data(:, 4);
signals.theta2_wrapped = data(:, 5);
signals.enable = data(:, 6);
signals.current_cmd = data(:, 7);
signals.current = data(:, 8);

signals.theta2_upright_error = -atan2(sin(signals.theta2 - pi), cos(signals.theta2 - pi));
signals.theta2_wrapped_from_theta2 = atan2(sin(signals.theta2), cos(signals.theta2));
signals.dt_median = median(diff(signals.t), "omitnan");
signals.fs_median = 1 / signals.dt_median;
signals.channelNames = [ ...
    "theta1", "theta2", "omega1", "omega2", ...
    "theta2_wrapped", "enable", "current_cmd", "current"];
end

function [t, data] = localTimeAndData(value, sampleTime)
if isa(value, "Simulink.SimulationOutput")
    names = string(who(value));
    if any(names == "simout")
        value = value.get("simout");
    else
        error("extractFurutaModelVsHardwareSignals:MissingSimout", ...
            "SimulationOutput does not contain a variable named simout.");
    end
end

if isa(value, "timeseries")
    t = double(value.Time(:));
    data = double(squeeze(value.Data));
elseif istimetable(value)
    t = seconds(value.Properties.RowTimes - value.Properties.RowTimes(1));
    data = double(value{:, :});
elseif isstruct(value) && isfield(value, "time") && isfield(value, "signals")
    t = double(value.time(:));
    data = double(squeeze(value.signals.values));
elseif isstruct(value) && isfield(value, "Time") && isfield(value, "Data")
    t = double(value.Time(:));
    data = double(squeeze(value.Data));
elseif isnumeric(value)
    if ~isfinite(sampleTime)
        error("extractFurutaModelVsHardwareSignals:MissingSampleTime", ...
            "Numeric simout data needs SampleTime so a time vector can be created.");
    end
    data = double(squeeze(value));
    t = (0:size(data, 1)-1).' * sampleTime;
else
    error("extractFurutaModelVsHardwareSignals:UnsupportedType", ...
        "Unsupported simout type: %s", class(value));
end

if isvector(data)
    data = data(:);
end

if size(data, 1) ~= numel(t) && size(data, 2) == numel(t)
    data = data.';
end

n = min(numel(t), size(data, 1));
t = t(1:n);
data = data(1:n, :);
end
