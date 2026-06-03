function [reward, isDone] = rewardFcnFuruta(obs, u, uPrev, rewardParams, safetyParams)
%REWARDFCNFURUTA Reward and termination logic for near-upright stabilization.
% obs convention: [theta1Error; theta2Error; omega1; omega2].

theta1Error = obs(1);
theta2Error = obs(2);
omega1 = obs(3);
omega2 = obs(4);

theta2Cost = (theta2Error / rewardParams.theta2Scale)^2;
theta1Cost = (theta1Error / rewardParams.theta1Scale)^2;
velocityCost = (omega1 / rewardParams.velocityScale)^2 + ...
    (omega2 / rewardParams.velocityScale)^2;
effortCost = rewardParams.lambda_u * u^2;
smoothnessCost = rewardParams.lambda_du * (u - uPrev)^2;

isUnsafe = abs(theta1Error) > safetyParams.MaxAbsArmAngle || ...
    abs(theta2Error) > safetyParams.MaxAbsPendulumAngle || ...
    abs(omega1) > safetyParams.MaxAbsAngularVelocity || ...
    abs(omega2) > safetyParams.MaxAbsAngularVelocity;

uprightBonus = rewardParams.uprightBonus * (abs(theta2Error) < rewardParams.uprightTolerance);

reward = -theta2Cost - 0.1 * theta1Cost - 0.01 * velocityCost - ...
    effortCost - smoothnessCost + uprightBonus;

if isUnsafe
    reward = reward - rewardParams.unsafePenalty;
end

isDone = isUnsafe;
end
