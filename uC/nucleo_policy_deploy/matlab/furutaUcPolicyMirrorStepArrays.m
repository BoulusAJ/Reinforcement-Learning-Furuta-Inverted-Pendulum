function [ucActionSingle, ucCurrentCmdSingle, actionError, obsSingle, omegaSingle] = furutaUcPolicyMirrorStepArrays(packetInput, packetOutput, matlabPolicyAction, resetState, W1, b1, W2, b2, W3, b3, actionScale, TsPolicy, agentCurrentLimit, currentOffset, finalCurrentLimit)
%FURUTAUCPOLICYMIRRORSTEPARRAYS Codegen-friendly uC policy mirror.
%
% This variant avoids passing a struct into a Simulink MATLAB Function block.

persistent previousAction omega1State omega2State initialized

if isempty(initialized) || resetState
    previousAction = single(0);
    omega1State = single(0);
    omega2State = single(0);
    initialized = true;
end

packetInput = single(packetInput(:));
packetOutput = single(packetOutput(:));

rawTheta1 = packetInput(1);
rawTheta2 = packetInput(2);

enable = true;
if numel(packetOutput) >= 2
    enable = packetOutput(2) ~= single(0);
end

theta1 = rawTheta1;
theta2 = -rawTheta2;

[omega1, omega1State] = localTustinDiffLowPass(theta1, omega1State, single(TsPolicy));
[omega2, omega2State] = localTustinDiffLowPass(theta2, omega2State, single(TsPolicy));

obsSingle = localBuildObservation(theta1, theta2, omega1, omega2, previousAction);

evaluateWhenDisabled = true;
shouldEvaluate = enable || evaluateWhenDisabled;
ucActionSingle = single(0);
ucCurrentCmdSingle = single(0);
if shouldEvaluate
    ucActionSingle = localActorForwardSingle(obsSingle, W1, b1, W2, b2, W3, b3);
    currentRaw = ucActionSingle * single(actionScale);
    currentLimitedForAgent = localClamp(currentRaw, single(agentCurrentLimit));
    currentWithOffset = localApplyCurrentOffset(currentLimitedForAgent, single(currentOffset));
    ucCurrentCmdSingle = localClamp(currentWithOffset, single(finalCurrentLimit));
end

previousAction = ucActionSingle;
actionError = double(ucActionSingle) - double(matlabPolicyAction);
omegaSingle = [omega1; omega2];
end

function obs = localBuildObservation(theta1, theta2, omega1, omega2, previousAction)
theta1Error = -theta1;
theta2Error = -atan2(sin(theta2 - single(pi)), cos(theta2 - single(pi)));
omega1Error = -omega1;
omega2Error = -omega2;

obs = single(zeros(7, 1));
obs(1) = sin(theta1Error);
obs(2) = cos(theta1Error);
obs(3) = sin(theta2Error);
obs(4) = cos(theta2Error);
obs(5) = omega1Error;
obs(6) = omega2Error;
obs(7) = previousAction;
end

function action = localActorForwardSingle(obs, W1, b1, W2, b2, W3, b3)
h1 = max(single(W1) * obs + single(b1(:)), single(0));
h2 = max(single(W2) * h1 + single(b2(:)), single(0));
z = single(W3) * h2 + single(b3(:));
action = tanh(z);
action = min(max(action(1), single(-1)), single(1));
end

function current = localApplyCurrentOffset(current, currentOffset)
if current > single(0)
    current = current + currentOffset;
elseif current < single(0)
    current = current - currentOffset;
end
end

function value = localClamp(value, limitAbs)
value = min(max(value, -limitAbs), limitAbs);
end

function [y, state] = localTustinDiffLowPass(u, state, Ts)
fcut = single(100);
Tf = single(1) / (single(2) * single(pi) * fcut);
a = single(2) * Tf / Ts;
k = single(1) / (a + single(1));
b0 = (single(2) / Ts) * k;
a1 = (single(1) - a) * k;

y = b0 * u + state;
state = -b0 * u - a1 * y;
end
