function signals = extractFurutaSignals(experiences)
%EXTRACTFURUTASIGNALS Extract Furuta logsout signals into column vectors.

logsout = getLogsoutFromExperiences(experiences);
if isempty(logsout)
    error("extractFurutaSignals:MissingLogsout", ...
        "Could not find logsout/logsOut in simulation experiences.");
end

signals = struct();

[signals.tAction, signals.action] = getScalarSignal(logsout, "action");
[signals.tActuatorCommand, signals.actuator_command, actuatorCommandName] = ...
    getFirstScalarSignal(logsout, ["current_command", "voltage_command"]);
signals.actuator_command_name = actuatorCommandName;
signals.tCurrentCommand = signals.tActuatorCommand;
signals.current_command = signals.actuator_command;
if actuatorCommandName == "voltage_command"
    signals.tVoltageCommand = signals.tActuatorCommand;
    signals.voltage_command = signals.actuator_command;
else
    signals.tVoltageCommand = [];
    signals.voltage_command = [];
end
[signals.tCurrent, signals.current] = getOptionalScalarSignal(logsout, "current", ...
    signals.tActuatorCommand, zeros(size(signals.actuator_command)));
[signals.tTorque, signals.torque] = getOptionalScalarSignal(logsout, "torque", ...
    signals.tActuatorCommand, zeros(size(signals.actuator_command)));
[signals.tOmega1, signals.omega1] = getScalarSignal(logsout, "omega1");
[signals.tOmega2, signals.omega2] = getScalarSignal(logsout, "omega2");
[signals.tTheta1, signals.theta1] = getScalarSignal(logsout, "theta1");
[signals.tTheta2, signals.theta2] = getScalarSignal(logsout, "theta2");
[signals.tVoltage, signals.voltage] = getOptionalScalarSignal(logsout, "voltage", ...
    signals.tActuatorCommand, signals.actuator_command);
[signals.tTorqueCommand, signals.torque_command] = ...
    getOptionalScalarSignal(logsout, "torque_command", signals.tActuatorCommand, signals.actuator_command);
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

function [t, sig, matchedName] = getFirstScalarSignal(logsout, names)
for idx = 1:numel(names)
    name = string(names(idx));
    if hasSignal(logsout, name)
        [t, sig] = getScalarSignal(logsout, name);
        matchedName = name;
        return;
    end
end

error("extractFurutaSignals:MissingSignal", ...
    "Missing logsout signal. Expected one of: %s", strjoin(string(names), ", "));
end

function [t, sig] = getOptionalScalarSignal(logsout, name, fallbackT, fallbackSig)
if hasSignal(logsout, name)
    [t, sig] = getScalarSignal(logsout, name);
else
    t = fallbackT;
    sig = fallbackSig;
end
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
elem = getSignalElement(logsout, name);
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

function tf = hasSignal(logsout, name)
tf = ~isempty(getSignalElement(logsout, name));
end

function elem = getSignalElement(logsout, name)
elem = [];
name = string(name);

try
    names = string(logsout.getElementNames);
    idx = find(names == name, 1);
    if ~isempty(idx)
        elem = logsout.getElement(idx);
        return;
    end
catch
end

try
    for idx = 1:logsout.numElements
        candidate = logsout.getElement(idx);
        if string(candidate.Name) == name
            elem = candidate;
            return;
        end
    end
catch
end
end
