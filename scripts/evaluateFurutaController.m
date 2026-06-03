function metrics = evaluateFurutaController(simOut, cfg)
%EVALUATEFURUTACONTROLLER Compute basic metrics from a Furuta simulation run.
%
% Update signal extraction once the model logging names are known.

metrics = struct();
metrics.Source = "TBD";
metrics.MaxAbsPendulumAngle = NaN;
metrics.MaxAbsArmAngle = NaN;
metrics.SettlingTime = NaN;
metrics.ControlEnergy = NaN;
metrics.SafetyViolation = NaN;

if nargin < 2
    cfg = makeFurutaConfig();
end

metrics.SafetyPendulumLimit = cfg.Safety.MaxAbsPendulumAngle;
metrics.SafetyArmLimit = cfg.Safety.MaxAbsArmAngle;
metrics.SimOutClass = class(simOut);
end
