function [isDone, diagnosis] = isDoneFcnFurutaSwingupCapture(obs, stepCount, doneParams, safetyParams)
%ISDONEFCNFURUTASWINGUPCAPTURE Termination logic for swing-up-to-LQR training.
%
% This function intentionally contains termination logic only. Reward shaping
% belongs in rewardFcnFurutaSwingupCapture.
%
% Observation convention:
% [sin(theta1Error); cos(theta1Error);
%  sin(theta2Error); cos(theta2Error);
%  omega1Observed; omega2Observed; previousAction]
%
% If doneParams.ObservationOmegaIsScaled is true, omega observations are
% multiplied by doneParams.ObservationOmegaScale to recover rad/s. For the
% requested swing-up test, the Simulink model caps omega at +/-25 rad/s and
% feeds omega/25 to the agent, so ObservationOmegaScale should be 25.

if nargin < 4
    safetyParams = doneParams;
end

[theta1Error, theta2Error, omega1, omega2] = localDecodeObs(obs, doneParams);

[captured, captureV, captureCurrent, ellipsoidOk, currentOk, guardsOk] = ...
    localCaptureCheck(theta1Error, theta2Error, omega1, omega2, doneParams);

theta1Unsafe = abs(theta1Error) > safetyParams.MaxAbsArmAngle;
theta2Unsafe = abs(theta2Error) > safetyParams.MaxAbsPendulumAngle;
omega1Unsafe = abs(omega1) > safetyParams.MaxAbsAngularVelocity;
omega2Unsafe = abs(omega2) > safetyParams.MaxAbsAngularVelocity;
isUnsafe = theta1Unsafe || theta2Unsafe || omega1Unsafe || omega2Unsafe;

timeout = false;
if isfield(doneParams, "EnableTimeout") && doneParams.EnableTimeout && ...
        isfield(doneParams, "MaxSteps")
    timeout = stepCount >= doneParams.MaxSteps;
end

isDone = captured || isUnsafe || timeout;

diagnosis = struct( ...
    "captured", captured, ...
    "captureV", captureV, ...
    "rhoCapture", doneParams.RhoCapture, ...
    "lqrCurrent", captureCurrent, ...
    "ellipsoidOk", ellipsoidOk, ...
    "currentOk", currentOk, ...
    "guardsOk", guardsOk, ...
    "theta1Unsafe", theta1Unsafe, ...
    "theta2Unsafe", theta2Unsafe, ...
    "omega1Unsafe", omega1Unsafe, ...
    "omega2Unsafe", omega2Unsafe, ...
    "isUnsafe", isUnsafe, ...
    "timeout", timeout, ...
    "theta1Error", theta1Error, ...
    "theta2Error", theta2Error, ...
    "omega1", omega1, ...
    "omega2", omega2);
end

function [theta1Error, theta2Error, omega1, omega2] = localDecodeObs(obs, params)
obsVec = obs(:);
theta1Error = atan2(obsVec(1), obsVec(2));
theta2Error = atan2(obsVec(3), obsVec(4));
omega1 = obsVec(5);
omega2 = obsVec(6);

if isfield(params, "ObservationOmegaIsScaled") && params.ObservationOmegaIsScaled
    omegaScale = params.ObservationOmegaScale;
    omega1 = omega1 * omegaScale;
    omega2 = omega2 * omegaScale;
end
end

function [captured, V, iLqr, ellipsoidOk, currentOk, guardsOk] = ...
    localCaptureCheck(theta1Error, theta2Error, omega1, omega2, params)
x = [theta1Error; theta2Error; omega1; omega2];
P = params.PCapture;
K = params.KCapture;
V = x' * P * x;
iLqr = -K * x;

ellipsoidOk = V <= params.RhoCapture;
currentOk = abs(iLqr) <= params.CurrentLimit;

theta1Ok = true;
theta2Ok = true;
omega1Ok = true;
omega2Ok = true;

if isfield(params, "Theta1Guard")
    theta1Ok = abs(theta1Error) <= params.Theta1Guard;
end
if isfield(params, "Theta2Guard")
    theta2Ok = abs(theta2Error) <= params.Theta2Guard;
end
if isfield(params, "Omega1Guard")
    omega1Ok = abs(omega1) <= params.Omega1Guard;
end
if isfield(params, "Omega2Guard")
    omega2Ok = abs(omega2) <= params.Omega2Guard;
end

guardsOk = theta1Ok && theta2Ok && omega1Ok && omega2Ok;
captured = ellipsoidOk && currentOk && guardsOk;
end
