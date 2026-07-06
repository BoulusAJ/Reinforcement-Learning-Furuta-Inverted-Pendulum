function [reward, isDone, diagnosis] = rewardFcnFuruta(obs, aRl, aRlPrev, stepCount, rewardParams, safetyParams, theta2_unwrapped)
%REWARDFCNFURUTA Reward and termination logic for Furuta RL.
% Preferred obs convention:
% [sin(theta1Error); cos(theta1Error);
%  sin(theta2Error); cos(theta2Error);
%  omega1Error; omega2Error; previousAction].
% Legacy obs convention is also accepted during transition:
% [theta1Error; theta2Error; omega1Error; omega2Error].
% aRl is the normalized signed RL action in [-1, 1].
%
% theta2_unwrapped is optional and is used only when
% safetyParams.EnablePendulumTravelLimit is true. It is interpreted as the
% physical pendulum angle with theta2 = 0 at the down rest position and
% theta2 = +/-pi at upright. The travel limit is applied relative to the
% episode start so upright starts are not treated as unsafe.

if nargin < 6
    safetyParams = rewardParams;
    rewardParams = stepCount;
    stepCount = Inf;
end
hasTheta2Unwrapped = nargin >= 7;
if ~hasTheta2Unwrapped
    theta2_unwrapped = NaN;
end

[theta1Error, theta2Error, omega1Error, omega2Error, ~] = decodeObservation(obs, aRlPrev);
theta2TravelUnsafe = computeTheta2TravelUnsafe(theta2_unwrapped, stepCount, safetyParams, hasTheta2Unwrapped);
uprightReachTimeoutUnsafe = computeUprightReachTimeoutUnsafe(theta2Error, stepCount, safetyParams);

if rewardParams.RewardMode == 2
    [reward, isDone, diagnosis] = mathWorksQubeStyleReward( ...
        theta1Error, theta2Error, omega1Error, omega2Error, ...
        aRl, aRlPrev, stepCount, rewardParams, safetyParams, ...
        theta2TravelUnsafe, uprightReachTimeoutUnsafe);
    return;
end

theta2Cost = (theta2Error / rewardParams.theta2Scale)^2;
theta1Cost = (theta1Error / rewardParams.theta1Scale)^2;
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

theta1Unsafe = abs(theta1Error) > safetyParams.MaxAbsArmAngle;
theta2Unsafe = abs(theta2Error) > safetyParams.MaxAbsPendulumAngle || ...
    theta2TravelUnsafe || uprightReachTimeoutUnsafe;
omega1Unsafe = abs(omega1Error) > safetyParams.MaxAbsAngularVelocity;
omega2Unsafe = abs(omega2Error) > safetyParams.MaxAbsAngularVelocity;

isUnsafe = theta1Unsafe || theta2Unsafe || omega1Unsafe || omega2Unsafe;

uprightBonus = rewardParams.uprightBonus * (abs(theta2Error) < rewardParams.uprightTolerance);
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

diagnosis = makeDiagnosis( ...
    theta1Unsafe, theta2Unsafe, omega1Unsafe, omega2Unsafe, ...
    theta1Error, theta2Error, omega1Error, omega2Error, ...
    aRl, aRlPrev, ...
    rewardTermAliveBonus, rewardTermTheta2Error, rewardTermTheta1Error, ...
    rewardTermVelocity, rewardTermActionEffort, rewardTermActionSmoothness, ...
    rewardTermUprightBonus, rewardTermUnsafePenalty);
end

function [reward, isDone, diagnosis] = mathWorksQubeStyleReward( ...
    theta1Error, theta2Error, omega1Error, omega2Error, ...
    aRl, aRlPrev, stepCount, rewardParams, safetyParams, ...
    theta2TravelUnsafe, uprightReachTimeoutUnsafe)

theta1Unsafe = abs(theta1Error) > safetyParams.MaxAbsArmAngle;
theta2Unsafe = abs(theta2Error) > safetyParams.MaxAbsPendulumAngle || ...
    theta2TravelUnsafe || uprightReachTimeoutUnsafe;
omega1Unsafe = abs(omega1Error) > safetyParams.MaxAbsAngularVelocity;
omega2Unsafe = abs(omega2Error) > safetyParams.MaxAbsAngularVelocity;

constraintFailed = abs(theta1Error) > rewardParams.aliveTheta1Limit || ...
    abs(omega1Error) > rewardParams.aliveOmega1Limit;
isUnsafe = theta1Unsafe || theta2Unsafe || omega1Unsafe || omega2Unsafe;
aliveFlag = double(~constraintFailed);

if stepCount <= rewardParams.duWarmupSteps
    deltaAction = 0;
else
    deltaAction = aRl - aRlPrev;
end

theta2Cost = theta2Error^2;
theta1Cost = theta1Error^2;
omega1Cost = rewardParams.angularVelocityWeight * omega1Error^2;
omega2Cost = rewardParams.angularVelocityWeight * omega2Error^2;
actionCost = aRl^2;
actionSmoothnessCost = rewardParams.actionSmoothnessWeight * deltaAction^2;

shapingCost = theta2Cost + theta1Cost + omega1Cost + omega2Cost + ...
    actionCost + actionSmoothnessCost;

rewardTermAliveBonus = rewardParams.aliveReward * aliveFlag;
rewardTermTheta2Error = -rewardParams.costWeight * theta2Cost;
rewardTermTheta1Error = -rewardParams.costWeight * theta1Cost;
rewardTermVelocity = -rewardParams.costWeight * (omega1Cost + omega2Cost);
rewardTermActionEffort = -rewardParams.costWeight * actionCost;
rewardTermActionSmoothness = -rewardParams.costWeight * actionSmoothnessCost;
rewardTermUprightBonus = 0;
rewardTermUnsafePenalty = 0;

reward = rewardParams.aliveReward * aliveFlag - rewardParams.costWeight * shapingCost;
isDone = isUnsafe;

diagnosis = makeDiagnosis( ...
    theta1Unsafe, theta2Unsafe, omega1Unsafe, omega2Unsafe, ...
    theta1Error, theta2Error, omega1Error, omega2Error, ...
    aRl, aRlPrev, ...
    rewardTermAliveBonus, rewardTermTheta2Error, rewardTermTheta1Error, ...
    rewardTermVelocity, rewardTermActionEffort, rewardTermActionSmoothness, ...
    rewardTermUprightBonus, rewardTermUnsafePenalty);
end

function theta2TravelUnsafe = computeTheta2TravelUnsafe(theta2_unwrapped, stepCount, safetyParams, hasTheta2Unwrapped)
persistent theta2Unwrapped0
persistent theta2Unwrapped0Valid

theta2TravelUnsafe = false;

if isempty(theta2Unwrapped0Valid)
    theta2Unwrapped0 = 0;
    theta2Unwrapped0Valid = false;
end

if ~hasTheta2Unwrapped || ~isfield(safetyParams, "EnablePendulumTravelLimit") || ...
        ~safetyParams.EnablePendulumTravelLimit
    theta2Unwrapped0Valid = false;
    return;
end

if ~isfield(safetyParams, "MaxAbsPendulumTravel") || ...
        ~isfinite(theta2_unwrapped)
    return;
end

if ~theta2Unwrapped0Valid || stepCount <= 1
    theta2Unwrapped0 = theta2_unwrapped;
    theta2Unwrapped0Valid = true;
end

theta2Travel = theta2_unwrapped - theta2Unwrapped0;
theta2TravelUnsafe = abs(theta2Travel) > safetyParams.MaxAbsPendulumTravel;
end

function uprightReachTimeoutUnsafe = computeUprightReachTimeoutUnsafe(theta2Error, stepCount, safetyParams)
persistent uprightReached

uprightReachTimeoutUnsafe = false;

if isempty(uprightReached) || stepCount <= 1
    uprightReached = false;
end

if ~isfield(safetyParams, "EnableUprightReachTimeout") || ...
        ~safetyParams.EnableUprightReachTimeout
    return;
end

if ~isfield(safetyParams, "AgentSampleTime") || ...
        ~isfield(safetyParams, "UprightReachTimeout_s") || ...
        ~isfield(safetyParams, "UprightReachTolerance")
    return;
end

if abs(theta2Error) <= safetyParams.UprightReachTolerance
    uprightReached = true;
end

episodeTime = double(stepCount) * safetyParams.AgentSampleTime;
uprightReachTimeoutUnsafe = episodeTime >= safetyParams.UprightReachTimeout_s && ...
    ~uprightReached;
end

function diagnosis = makeDiagnosis( ...
    theta1Unsafe, theta2Unsafe, omega1Unsafe, omega2Unsafe, ...
    theta1Error, theta2Error, omega1Error, omega2Error, ...
    aRl, aRlPrev, ...
    rewardTermAliveBonus, rewardTermTheta2Error, rewardTermTheta1Error, ...
    rewardTermVelocity, rewardTermActionEffort, rewardTermActionSmoothness, ...
    rewardTermUprightBonus, rewardTermUnsafePenalty)

diagnosis = struct( ...
    "theta1Unsafe", theta1Unsafe, ...
    "theta2Unsafe", theta2Unsafe, ...
    "omega1Unsafe", omega1Unsafe, ...
    "omega2Unsafe", omega2Unsafe, ...
    "theta1Error_used_by_reward", theta1Error, ...
    "theta2Error_used_by_reward", theta2Error, ...
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

function [theta1Error, theta2Error, omega1Error, omega2Error, aRlPrevObs] = decodeObservation(obs, aRlPrev)
if numel(obs) >= 7
    theta1Error = atan2(obs(1), obs(2));
    theta2Error = atan2(obs(3), obs(4));
    omega1Error = obs(5);
    omega2Error = obs(6);
    aRlPrevObs = obs(7);
else
    theta1Error = obs(1);
    theta2Error = obs(2);
    omega1Error = obs(3);
    omega2Error = obs(4);
    aRlPrevObs = aRlPrev;
end
end
