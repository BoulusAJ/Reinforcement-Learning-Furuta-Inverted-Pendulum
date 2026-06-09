function busObj = createFurutaRewardDiagnosisBus(options)
%CREATEFURUTAREWARDDIAGNOSISBUS Define reward diagnosis bus object.
%
% MATLAB Function block setup:
%   diagnosis output type: Bus: FurutaRewardDiagnosisBus

arguments
    options.AssignToBase (1,1) logical = true
    options.BusName (1,1) string = "FurutaRewardDiagnosisBus"
end

names = [ ...
    "theta1Unsafe"
    "theta2Unsafe"
    "omega1Unsafe"
    "omega2Unsafe"
    "theta1Error_used_by_reward"
    "theta2Error_used_by_reward"
    "omega1Error_used_by_reward"
    "omega2Error_used_by_reward"
    "u_used_by_reward"
    "uPrev_used_by_reward"];

dataTypes = [ ...
    "boolean"
    "boolean"
    "boolean"
    "boolean"
    "double"
    "double"
    "double"
    "double"
    "double"
    "double"];

elements(numel(names), 1) = Simulink.BusElement;
for idx = 1:numel(names)
    elements(idx).Name = char(names(idx));
    elements(idx).DataType = char(dataTypes(idx));
    elements(idx).Dimensions = 1;
    elements(idx).DimensionsMode = "Fixed";
    elements(idx).Complexity = "real";
end

busObj = Simulink.Bus;
busObj.Description = "Reward and termination diagnosis signals for Furuta RL.";
busObj.Elements = elements;

if options.AssignToBase
    assignin("base", options.BusName, busObj);
end
end
