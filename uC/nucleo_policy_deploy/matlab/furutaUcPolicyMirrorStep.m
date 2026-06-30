function [ucActionSingle, ucCurrentCmdSingle, actionError, obsSingle, omegaSingle] = furutaUcPolicyMirrorStep(packetInput, packetOutput, matlabPolicyAction, weights, resetState)
%FURUTAUCPOLICYMIRRORSTEP Mirror the Nucleo RL policy step in MATLAB.
%
% Intended use in SLDRT/Simulink:
%   packetInput       first entries from Packet Input:
%                     [raw_theta1; raw_theta2; measured_current; ...]
%   packetOutput      Packet Output command:
%                     [current_cmd; enable]
%   matlabPolicyAction raw normalized action from the MATLAB/Simulink Policy block
%   weights           exported weights struct from actor_export_nucleo.mat
%   resetState        true at the start of a run/test
%
% Outputs:
%   ucActionSingle      normalized action, calculated with single precision
%   ucCurrentCmdSingle  Nucleo-style current command after scale, offset, clamp
%   actionError         double(ucActionSingle) - double(matlabPolicyAction)
%   obsSingle           7x1 observation used by the uC-style policy
%   omegaSingle         [omega1; omega2] from the uC-style speed filters

persistent previousAction omega1State omega2State initialized

if nargin < 5
    resetState = false;
end

TsPolicy = localGetScalar(weights, "SampleTime", single(0.002));
currentLimit = single(0.5);
currentOffset = single(0.0205);
actionScale = localGetScalar(weights, "ActionScale", single(4.0));
evaluateWhenDisabled = true;

if isempty(initialized) || resetState
    previousAction = single(0);
    omega1State = single(0);
    omega2State = single(0);
    initialized = true;
end

packetInput = single(packetInput(:));
packetOutput = single(packetOutput(:));
matlabPolicyAction = double(matlabPolicyAction);

rawTheta1 = packetInput(1);
rawTheta2 = packetInput(2);

enable = true;
if numel(packetOutput) >= 2
    enable = packetOutput(2) ~= single(0);
end

theta1 = rawTheta1;
theta2 = -rawTheta2;

[omega1, omega1State] = localTustinDiffLowPass(theta1, omega1State, TsPolicy);
[omega2, omega2State] = localTustinDiffLowPass(theta2, omega2State, TsPolicy);

obsSingle = localBuildObservation(theta1, theta2, omega1, omega2, previousAction);

shouldEvaluate = enable || evaluateWhenDisabled;
ucActionSingle = single(0);
ucCurrentCmdSingle = single(0);
if shouldEvaluate
    ucActionSingle = localActorForwardSingle(obsSingle, weights);
    currentRaw = ucActionSingle * actionScale;
    currentWithOffset = localApplyCurrentOffset(currentRaw, currentOffset);
    ucCurrentCmdSingle = min(max(currentWithOffset, -currentLimit), currentLimit);
end

previousAction = ucActionSingle;
actionError = double(ucActionSingle) - matlabPolicyAction;
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

function action = localActorForwardSingle(obs, weights)
W1 = single(weights.W1);
b1 = single(weights.b1(:));
W2 = single(weights.W2);
b2 = single(weights.b2(:));
W3 = single(weights.W3);
b3 = single(weights.b3(:));

h1 = max(W1 * obs + b1, single(0));
h2 = max(W2 * h1 + b2, single(0));
z = W3 * h2 + b3;
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

function [y, state] = localTustinDiffLowPass(u, state, Ts)
% Matches IIRFilter::differentiatingLowPass1TustinUpdate/apply.
fcut = single(100);
Tf = single(1) / (single(2) * single(pi) * fcut);
a = single(2) * Tf / Ts;
k = single(1) / (a + single(1));
b0 = (single(2) / Ts) * k;
a1 = (single(1) - a) * k;

y = b0 * u + state;
state = -b0 * u - a1 * y;
end

function value = localGetScalar(weights, fieldName, defaultValue)
if isfield(weights, fieldName)
    value = single(weights.(fieldName));
else
    value = defaultValue;
end
end
