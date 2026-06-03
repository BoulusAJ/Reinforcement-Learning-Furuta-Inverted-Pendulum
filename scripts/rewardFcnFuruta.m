function [reward, isDone] = rewardFcnFuruta(obs, u, uPrev, rewardParams, safetyParams)
%REWARDFCNFURUTA Reward and termination logic for near-upright stabilization.
% obs convention: [theta; alpha; theta_dot; alpha_dot].

theta = obs(1);
alpha = obs(2);
thetaDot = obs(3);
alphaDot = obs(4);

alphaCost = (alpha / rewardParams.alphaScale)^2;
thetaCost = (theta / rewardParams.thetaScale)^2;
velocityCost = (thetaDot / rewardParams.velocityScale)^2 + ...
    (alphaDot / rewardParams.velocityScale)^2;
effortCost = rewardParams.lambda_u * u^2;
smoothnessCost = rewardParams.lambda_du * (u - uPrev)^2;

isUnsafe = abs(theta) > safetyParams.MaxAbsArmAngle || ...
    abs(alpha) > safetyParams.MaxAbsPendulumAngle || ...
    abs(thetaDot) > safetyParams.MaxAbsAngularVelocity || ...
    abs(alphaDot) > safetyParams.MaxAbsAngularVelocity;

uprightBonus = rewardParams.uprightBonus * (abs(alpha) < rewardParams.uprightTolerance);

reward = -alphaCost - 0.1 * thetaCost - 0.01 * velocityCost - ...
    effortCost - smoothnessCost + uprightBonus;

if isUnsafe
    reward = reward - rewardParams.unsafePenalty;
end

isDone = isUnsafe;
end
