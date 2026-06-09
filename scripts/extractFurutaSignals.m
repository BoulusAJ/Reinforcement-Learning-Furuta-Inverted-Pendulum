function signals = extractFurutaSignals(experiences)
%EXTRACTFURUTASIGNALS Extract Furuta logsout signals into column vectors.

logsout = getLogsoutFromExperiences(experiences);
if isempty(logsout)
    error("extractFurutaSignals:MissingLogsout", ...
        "Could not find logsout/logsOut in simulation experiences.");
end

signals = struct();

[signals.tAction, signals.action] = getScalarSignal(logsout, "action");
[signals.tCurrentCommand, signals.current_command] = getScalarSignal(logsout, "current_command");
[signals.tCurrent, signals.current] = getScalarSignal(logsout, "current");
[signals.tTorque, signals.torque] = getScalarSignal(logsout, "torque");
[signals.tOmega1, signals.omega1] = getScalarSignal(logsout, "omega1");
[signals.tOmega2, signals.omega2] = getScalarSignal(logsout, "omega2");
[signals.tTheta1, signals.theta1] = getScalarSignal(logsout, "theta1");
[signals.tTheta2, signals.theta2] = getScalarSignal(logsout, "theta2");
[signals.tVoltage, signals.voltage] = getScalarSignal(logsout, "voltage");
[signals.tTorqueCommand, signals.torque_command] = getScalarSignal(logsout, "torque_command");
[signals.tIsDone, signals.isDone] = getScalarSignal(logsout, "isDone");
[signals.tReward, signals.reward] = getScalarSignal(logsout, "reward");

[signals.tErrors, errors] = getVectorSignal(logsout, "errors");
signals.theta1Error = errors(:, 1);
signals.theta2Error = errors(:, 2);
signals.omega1Error = errors(:, 3);
signals.omega2Error = errors(:, 4);

[signals.tObservations, observations] = getVectorSignal(logsout, "observations");
signals.observations = observations;
signals.obsTheta1Error = observations(:, 1);
signals.obsTheta2Error = observations(:, 2);
signals.obsOmega1Error = observations(:, 3);
signals.obsOmega2Error = observations(:, 4);

signals.t = signals.tErrors(:);
end

function logsout = getLogsoutFromExperiences(experiences)
logsout = [];

try
    simInfo = experiences.SimulationInfo;
    if isstruct(simInfo)
        if isfield(simInfo, "logsout")
            logsout = simInfo.logsout;
            return;
        end
        if isfield(simInfo, "logsOut")
            logsout = simInfo.logsOut;
            return;
        end
    end
catch
end

try
    logsout = experiences.SimulationInfo.logsout;
    return;
catch
end

try
    logsout = experiences.SimulationInfo.logsOut;
    return;
catch
end

try
    simData = experiences.SimulationInfo.getSimulationData(1);
    logsout = simData.logsout;
    return;
catch
end

try
    simData = experiences.SimulationInfo.getSimulationData(1);
    logsout = simData.logsOut;
    return;
catch
end

try
    simData = experiences.SimulationInfo.getSimulationData(1);
    logsout = simData.get("logsout");
    return;
catch
end

try
    simData = experiences.SimulationInfo.getSimulationData(1);
    logsout = simData.get("logsOut");
    return;
catch
end

try
    logsout = experiences.SimulationInfo.get("logsout");
    return;
catch
end

try
    logsout = experiences.SimulationInfo.get("logsOut");
    return;
catch
end
end

function [t, sig] = getScalarSignal(logsout, name)
[t, data] = getSignalData(logsout, name);
if size(data, 2) > 1
    data = data(:, 1);
end
sig = data(:);
end

function [t, data] = getVectorSignal(logsout, name)
[t, data] = getSignalData(logsout, name);
if size(data, 2) < 4
    error("extractFurutaSignals:SignalTooSmall", ...
        "Signal %s must have at least 4 columns.", name);
end
data = data(:, 1:4);
end

function [t, data] = getSignalData(logsout, name)
elem = logsout.get(name);
if isempty(elem)
    error("extractFurutaSignals:MissingSignal", ...
        "Missing logsout signal: %s", name);
end

ts = elem.Values;
t = ts.Time(:);
raw = squeeze(ts.Data);

if isvector(raw)
    data = double(raw(:));
elseif size(raw, 1) == numel(t)
    data = double(raw);
elseif size(raw, ndims(raw)) == numel(t)
    data = double(reshape(raw, [], numel(t)).');
else
    data = double(raw);
    data = reshape(data, numel(t), []);
end
end
