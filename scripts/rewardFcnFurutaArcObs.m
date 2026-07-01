function [reward, isDone, diagnosis] = rewardFcnFurutaArcObs(obs, aRl, aRlPrev, stepCount, rewardParams, safetyParams)
%REWARDFCNFURUTAARCOBS Reward for reduced arc-distance observations.
%
% Observation convention:
% [theta1_arc_norm; theta2_arc_norm; omega1_scaled; omega2_scaled; previousAction]
%
% theta*_arc_norm is in [0, 1]:
%   0 = target/upright
%   1 = opposite side
%
% omega*_scaled_norm is saturated and normalized by
% rewardParams.AngularVelocityScale:
%   min(max(omegaError / rewardParams.AngularVelocityScale, -1), 1)
%
% This intentionally mirrors rewardFcnFuruta's default reward structure while
% changing only the observation decoding for the reduced-observation
% experiment.

if nargin < 6
    safetyParams = rewardParams;
    rewardParams = stepCount;
    stepCount = aRlPrev;
    aRlPrev = obs(5);
end

theta1ErrorAbs = obs(1) * pi;
theta2ErrorAbs = obs(2) * pi;
% Decode normalized velocity observations back to rad/s so the existing
% rewardParams.omega*Scale values keep the same meaning as rewardFcnFuruta.
% A future normalized reward can operate directly on obs(3:4).
omega1Error = obs(3) * rewardParams.AngularVelocityScale;
omega2Error = obs(4) * rewardParams.AngularVelocityScale;
% Keep the same action interface as rewardFcnFuruta: aRl and aRlPrev are
% separate block inputs. obs(5) remains visible to the agent but is not used
% for the reward's delta-u term.

theta2Cost = (theta2ErrorAbs / rewardParams.theta2Scale)^2;
theta1Cost = (theta1ErrorAbs / rewardParams.theta1Scale)^2;
omega1Cost = (omega1Error / rewardParams.omega1Scale)^2;
omega2Cost = (omega2Error / rewardParams.omega2Scale)^2;
effortCost = rewardParams.lambda_u * aRl^2;

% Skip startup delta-u penalties caused by deliberate unit-delay
% initialization used to avoid algebraic loops, not by physical transients.
if stepCount <= rewardParams.duWarmupSteps
    smoothnessCost = 0;
else
    smoothnessCost = rewardParams.lambda_du * (aRl - aRlPrev)^2;
end

theta1Unsafe = theta1ErrorAbs > safetyParams.MaxAbsArmAngle;
theta2Unsafe = theta2ErrorAbs > safetyParams.MaxAbsPendulumAngle;
omega1Unsafe = abs(omega1Error) > safetyParams.MaxAbsAngularVelocity;
omega2Unsafe = abs(omega2Error) > safetyParams.MaxAbsAngularVelocity;

isUnsafe = theta1Unsafe || theta2Unsafe || omega1Unsafe || omega2Unsafe;

uprightBonus = rewardParams.uprightBonus * ...
    (theta2ErrorAbs < rewardParams.uprightTolerance);
unsafePenalty = rewardParams.unsafePenalty * isUnsafe;

rewardTermAliveBonus = rewardParams.aliveBonus;
rewardTermTheta2Error = -rewardParams.theta2Weight * theta2Cost;
rewardTermTheta1Error = -rewardParams.theta1Weight * theta1Cost;
rewardTermVelocity = -(rewardParams.omega1Weight * omega1Cost + ...
    rewardParams.omega2Weight * omega2Cost);
rewardTermActionEffort = -effortCost;
rewardTermActionSmoothness = -smoothnessCost;
rewardTermUprightBonus = uprightBonus;
rewardTermUnsafePenalty = -unsafePenalty;

reward = rewardTermAliveBonus + rewardTermTheta2Error + ...
    rewardTermTheta1Error + rewardTermVelocity + rewardTermActionEffort + ...
    rewardTermActionSmoothness + rewardTermUprightBonus + rewardTermUnsafePenalty;

isDone = isUnsafe;

diagnosis = struct( ...
    "theta1Unsafe", theta1Unsafe, ...
    "theta2Unsafe", theta2Unsafe, ...
    "omega1Unsafe", omega1Unsafe, ...
    "omega2Unsafe", omega2Unsafe, ...
    "theta1Error_used_by_reward", theta1ErrorAbs, ...
    "theta2Error_used_by_reward", theta2ErrorAbs, ...
    "omega1Error_used_by_reward", omega1Error, ...
    "omega2Error_used_by_reward", omega2Error, ...
    "u_used_by_reward", aRl, ...
    "uPrev_used_by_reward", aRlPrev, ...
    "rewardTerm_aliveBonus", rewardTermAliveBonus, ...
    "rewardTerm_theta2Error", rewardTermTheta2Error, ...
    "rewardTerm_theta1Error", rewardTermTheta1Error, ...
    "rewardTerm_velocity", rewardTermVelocity, ...
    "rewardTerm_actionEffort", rewardTermActionEffort, ...
    "rewardTerm_actionSmoothness", rewardTermActionSmoothness, ...
    "rewardTerm_uprightBonus", rewardTermUprightBonus, ...
    "rewardTerm_unsafePenalty", rewardTermUnsafePenalty);
end
