function [reward, diagnosis] = rewardFcnFurutaSwingupCapture(obs, aRl, aRlPrev, stepCount, rewardParams, safetyParams)
%REWARDFCNFURUTASWINGUPCAPTURE Reward for RL swing-up into the LQR capture region.
%
% This reward is meant for the RT2-oriented swing-up-only task:
%
%   RL swing-up -> enter LQR capture region -> terminate successfully
%
% It does not return isDone. Use isDoneFcnFurutaSwingupCapture for episode
% termination. The reward may still compute captured/unsafe flags so it can
% add a terminal bonus or penalty consistently.

if nargin < 6
    safetyParams = rewardParams;
end

[theta1Error, theta2Error, omega1, omega2] = localDecodeObs(obs, rewardParams);

if stepCount <= rewardParams.duWarmupSteps
    deltaAction = 0;
else
    deltaAction = aRl - aRlPrev;
end

[captured, captureV, captureCurrent, ellipsoidOk, currentOk, guardsOk] = ...
    localCaptureCheck(theta1Error, theta2Error, omega1, omega2, rewardParams);

theta1Unsafe = abs(theta1Error) > safetyParams.MaxAbsArmAngle;
theta2Unsafe = abs(theta2Error) > safetyParams.MaxAbsPendulumAngle;
omega1Unsafe = abs(omega1) > safetyParams.MaxAbsAngularVelocity;
omega2Unsafe = abs(omega2) > safetyParams.MaxAbsAngularVelocity;
isUnsafe = theta1Unsafe || theta2Unsafe || omega1Unsafe || omega2Unsafe;

% Global swing-up progress. This is high near upright and low near downward.
uprightProgress = cos(theta2Error);

% Penalize arm displacement and motor motion throughout swing-up. Penalize
% pendulum velocity mostly near upright; far away the policy needs velocity to
% build energy.
nearUprightWeight = exp(-(theta2Error / rewardParams.NearUprightAngle)^2);

theta1Cost = (theta1Error / rewardParams.Theta1Scale)^2;
omega1Cost = (omega1 / rewardParams.Omega1Scale)^2;
omega2NearCost = nearUprightWeight * (omega2 / rewardParams.Omega2Scale)^2;
actionCost = aRl^2;
actionSmoothnessCost = deltaAction^2;
actionDiffWeight = localActionDiffWeight(rewardParams);

rewardTermProgress = rewardParams.ProgressWeight * uprightProgress;
rewardTermTheta1 = -rewardParams.Theta1Weight * theta1Cost;
rewardTermOmega1 = -rewardParams.Omega1Weight * omega1Cost;
rewardTermOmega2Near = -rewardParams.Omega2NearWeight * omega2NearCost;
rewardTermAction = -rewardParams.ActionWeight * actionCost;
rewardTermActionSmoothness = -actionDiffWeight * actionSmoothnessCost;
rewardTermCaptureBonus = rewardParams.CaptureBonus * double(captured);
rewardTermUnsafePenalty = -rewardParams.UnsafePenalty * double(isUnsafe);

reward = rewardTermProgress + rewardTermTheta1 + rewardTermOmega1 + ...
    rewardTermOmega2Near + rewardTermAction + rewardTermActionSmoothness + ...
    rewardTermCaptureBonus + rewardTermUnsafePenalty;

diagnosis = struct( ...
    "theta1Unsafe", theta1Unsafe, ...
    "theta2Unsafe", theta2Unsafe, ...
    "omega1Unsafe", omega1Unsafe, ...
    "omega2Unsafe", omega2Unsafe, ...
    "theta1Error_used_by_reward", theta1Error, ...
    "theta2Error_used_by_reward", theta2Error, ...
    "omega1Error_used_by_reward", omega1, ...
    "omega2Error_used_by_reward", omega2, ...
    "u_used_by_reward", aRl, ...
    "uPrev_used_by_reward", aRlPrev, ...
    "rewardTerm_aliveBonus", 0, ...
    "rewardTerm_theta2Error", rewardTermProgress, ...
    "rewardTerm_theta1Error", rewardTermTheta1, ...
    "rewardTerm_velocity", rewardTermOmega1 + rewardTermOmega2Near, ...
    "rewardTerm_actionEffort", rewardTermAction, ...
    "rewardTerm_actionSmoothness", rewardTermActionSmoothness, ...
    "rewardTerm_uprightBonus", rewardTermCaptureBonus, ...
    "rewardTerm_unsafePenalty", rewardTermUnsafePenalty);
end

function weight = localActionDiffWeight(params)
weight = params.ActionDiffWeight;
if isfield(params, "ActionDiffReferenceSampleTime") && ...
        isfield(params, "AgentSampleTime")
    referenceTs = params.ActionDiffReferenceSampleTime;
    agentTs = params.AgentSampleTime;
    if referenceTs <= 0 || agentTs <= 0
        error("Reward sample times must be positive.");
    end
    weight = weight * (referenceTs / agentTs)^2;
end
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
