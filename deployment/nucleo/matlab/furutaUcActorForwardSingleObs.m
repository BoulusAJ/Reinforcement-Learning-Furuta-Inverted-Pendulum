function [ucActionSingle, actionError] = furutaUcActorForwardSingleObs(observation, matlabPolicyAction, W1, b1, W2, b2, W3, b3)
%FURUTAUCACTORFORWARDSINGLEOBS Single-precision exported actor forward pass.
%
% Use this for the network-only check:
%   same 7x1 observation -> Simulink Policy block
%                         -> exported/uC-style actor
%
% This intentionally does not build the observation, filter speeds, apply
% previous-action logic, scale current, or apply the current offset.

obs = single(observation(:));

h1 = max(single(W1) * obs + single(b1(:)), single(0));
h2 = max(single(W2) * h1 + single(b2(:)), single(0));
z = single(W3) * h2 + single(b3(:));

ucActionSingle = tanh(z);
ucActionSingle = min(max(ucActionSingle(1), single(-1)), single(1));

if nargin >= 8 && ~isempty(matlabPolicyAction)
    actionError = double(ucActionSingle) - double(matlabPolicyAction);
else
    actionError = NaN;
end
end
