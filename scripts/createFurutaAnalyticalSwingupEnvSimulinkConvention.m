function env = createFurutaAnalyticalSwingupEnvSimulinkConvention(cfg)
%CREATEFURUTAANALYTICALSWINGUPENVSIMULINKCONVENTION MATLAB swing-up environment.
%
% This variant follows the established Simulink reference-minus-measurement
% convention for all four error states:
%   e1 = 0 - wrap(theta1)
%   e2 = 0 - wrap(theta2 - pi)
%   ew1 = 0 - omega1
%   ew2 = 0 - omega2
%
% The mechanical plant uses a fixed-step third-order Bogacki-Shampine
% update configured to correspond to the Simulink ode3 fixed-step solver.

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
actInfo = rlNumericSpec([1 1], LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, Name=cfg.Action.Name);

env = rlFunctionEnv(obsInfo, actInfo, ...
    @(action, logged) localStep(action, logged, cfg), ...
    @() localReset(cfg));
end

function [nextObs, reward, isDone, logged] = localStep(action, logged, cfg)
if iscell(action)
    action = action{1};
end
action = min(max(double(action(1)), cfg.Action.Min), cfg.Action.Max);

currentCommand = cfg.Limits.CurrentMax * action;
motorTorque = cfg.Motor.km * currentCommand;
x = logged.State;

for idx = 1:cfg.MatlabEnvironment.Substeps
    x = localOde3Step(x, motorTorque, ...
        cfg.MatlabEnvironment.IntegrationStep, logged.Param);
end

logged.State = x;
logged.StepCount = logged.StepCount + 1;
nextObs = localObservation(x, action, cfg);

[reward, ~] = rewardFcnFurutaSwingupCapture(nextObs, action, ...
    logged.PreviousAction, logged.StepCount, cfg.Reward, cfg.Safety);
[isDone, logged.LastDiagnosis] = isDoneFcnFurutaSwingupCapture(nextObs, ...
    logged.StepCount, cfg.Done, cfg.Safety);

rawStateUnsafe = ~all(isfinite(x)) || ...
    abs(x(1)) > cfg.Safety.MaxAbsArmAngle || ...
    any(abs(x(3:4)) > cfg.Safety.MaxAbsAngularVelocity);
if rawStateUnsafe && ~logged.LastDiagnosis.isUnsafe
    reward = reward - cfg.Reward.UnsafePenalty;
end
isDone = isDone || rawStateUnsafe;
logged.LastDiagnosis.rawStateUnsafe = rawStateUnsafe;

logged.PreviousAction = action;
logged.LastCurrentCommand = currentCommand;
logged.LastMotorTorque = motorTorque;
end

function [initialObs, logged] = localReset(cfg)
reset = cfg.MatlabEnvironment.Reset;
x = [localUniform(reset.Theta1Range); ...
     localUniform(reset.Theta2Range); ...
     localUniform(reset.Omega1Range); ...
     localUniform(reset.Omega2Range)];

logged = struct();
logged.State = x;
logged.PreviousAction = 0;
logged.StepCount = 0;
logged.Param = cfg.MatlabEnvironment.Param;
logged.LastCurrentCommand = 0;
logged.LastMotorTorque = 0;
logged.LastDiagnosis = struct();

initialObs = localObservation(x, 0, cfg);
end

function xNext = localOde3Step(x, torque, dt, param)
% Fixed-step Bogacki-Shampine third-order update, matching Simulink ode3.
k1 = furutaAnalyticalStateDerivative(x, torque, param);
k2 = furutaAnalyticalStateDerivative(x + 0.5 * dt * k1, torque, param);
k3 = furutaAnalyticalStateDerivative(x + 0.75 * dt * k2, torque, param);
xNext = x + dt * ((2/9) * k1 + (1/3) * k2 + (4/9) * k3);
end

function obs = localObservation(x, previousAction, cfg)
theta1Error = -atan2(sin(x(1)), cos(x(1)));
theta2Error = -atan2(sin(x(2) - pi), cos(x(2) - pi));
omegaError = -x(3:4);
omegaClip = cfg.Observation.OmegaClip;
omegaObserved = min(max(omegaError, -omegaClip), omegaClip) ...
    / cfg.Observation.OmegaScale;

obs = [sin(theta1Error); cos(theta1Error); ...
       sin(theta2Error); cos(theta2Error); ...
       omegaObserved; previousAction];
end

function value = localUniform(range)
value = range(1) + rand() * (range(2) - range(1));
end
