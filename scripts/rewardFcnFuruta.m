function [reward, isDone, diagnosis] = rewardFcnFuruta(obs, aRl, aRlPrev, rewardParams, safetyParams)
%REWARDFCNFURUTA Reward and termination logic for near-upright stabilization.
% obs convention: [theta1Error; theta2Error; omega1Error; omega2Error].
% aRl is the normalized signed RL action in [-1, 1].

theta1Error = obs(1);
theta2Error = obs(2);
omega1Error = obs(3);
omega2Error = obs(4);

theta2Cost = (theta2Error / rewardParams.theta2Scale)^2;
theta1Cost = (theta1Error / rewardParams.theta1Scale)^2;
velocityCost = (omega1Error / rewardParams.velocityScale)^2 + ...
    (omega2Error / rewardParams.velocityScale)^2;
effortCost = rewardParams.lambda_u * aRl^2;
smoothnessCost = rewardParams.lambda_du * (aRl - aRlPrev)^2;

theta1Unsafe = abs(theta1Error) > safetyParams.MaxAbsArmAngle;
theta2Unsafe = abs(theta2Error) > safetyParams.MaxAbsPendulumAngle;
omega1Unsafe = abs(omega1Error) > safetyParams.MaxAbsAngularVelocity;
omega2Unsafe = abs(omega2Error) > safetyParams.MaxAbsAngularVelocity;

isUnsafe = theta1Unsafe || theta2Unsafe || omega1Unsafe || omega2Unsafe;

uprightBonus = rewardParams.uprightBonus * (abs(theta2Error) < rewardParams.uprightTolerance);

reward = -theta2Cost - 0.1 * theta1Cost - 0.01 * velocityCost - ...
    effortCost - smoothnessCost + uprightBonus;

if isUnsafe
    reward = reward - rewardParams.unsafePenalty;
end

isDone = isUnsafe;

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
    "uPrev_used_by_reward", aRlPrev);
end
