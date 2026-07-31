function [inside, info] = isInLqrCaptureRegion(theta1, theta2, omega1, omega2, options)
%ISINLQRCAPTUREREGION Test whether a Furuta state is inside the upright LQR capture region.
%
% The default test uses the upright LQR from the ZHAW Furuta reference model:
%
%   x = [theta1_error; theta2_upright_error; omega1; omega2]
%   V = x' * P_oben * x
%
% The state is considered inside if V <= rho, the LQR current command stays
% within CurrentLimit, and all optional guard limits are satisfied. If
% options.Rho is empty, rho is computed from CurrentLimit:
%
%   rho = CurrentLimit^2 / (K_oben * inv(P_oben) * K_oben')
%
% Inputs theta1/theta2 are in radians. By default theta2 is the measured
% pendulum angle using the repo/course convention:
%
%   theta2 = 0      pendulum hanging downward
%   theta2 = pi     pendulum upright
%
% Internally the upright error is:
%
%   theta2_error = atan2(sin(theta2 - pi), cos(theta2 - pi))
%
% A positive theta2_error means the measured theta2 is above pi in the
% positive rotation direction. The corresponding LQR state is:
%
%   x = [theta1 - Theta1Offset; theta2_error; omega1; omega2]
%
% Set Theta2IsError=true if theta2 is already this upright error instead of
% the measured pendulum angle.
%
% Example:
%
%   [inside, info] = isInLqrCaptureRegion(0, pi + deg2rad(10), 0, -1.4, ...
%       Rho=0.08, CurrentLimit=1.5);
%
% info.RhoMaxCurrent and info.RhoMax are the maximum rho implied by
% CurrentLimit.

arguments
    theta1
    theta2
    omega1
    omega2
    options.CurrentLimit (1,1) double = 1.5
    options.Rho double = []
    options.Theta1Offset double = 0
    options.Theta2IsError (1,1) logical = false
    options.Theta1Guard double = []
    options.Theta2Guard double = []
    options.Omega1Guard double = []
    options.Omega2Guard double = []
    options.K double = []
    options.P double = []
end

[K, P, rhoCurrentLimit] = localLqrCaptureData(options.CurrentLimit, options.K, options.P);
if isempty(options.Rho)
    rho = rhoCurrentLimit;
else
    rho = options.Rho;
end

theta1Error = theta1 - options.Theta1Offset;
if options.Theta2IsError
    theta2Error = theta2;
else
    theta2Error = atan2(sin(theta2 - pi), cos(theta2 - pi));
end

x = [theta1Error(:).'; theta2Error(:).'; omega1(:).'; omega2(:).'];
if size(x, 2) ~= numel(theta1Error) || ...
        numel(theta1Error) ~= numel(theta2Error) || ...
        numel(theta1Error) ~= numel(omega1) || ...
        numel(theta1Error) ~= numel(omega2)
    error("isInLqrCaptureRegion:InputSizeMismatch", ...
        "theta1, theta2, omega1, and omega2 must have the same number of elements.");
end

V = sum(x .* (P * x), 1);
iLqr = -K * x;

ellipsoidOk = V <= rho;
currentOk = abs(iLqr) <= options.CurrentLimit;
theta1Ok = localGuardOk(theta1Error, options.Theta1Guard);
theta2Ok = localGuardOk(theta2Error, options.Theta2Guard);
omega1Ok = localGuardOk(omega1, options.Omega1Guard);
omega2Ok = localGuardOk(omega2, options.Omega2Guard);

inside = ellipsoidOk & currentOk & theta1Ok & theta2Ok & omega1Ok & omega2Ok;

info = struct( ...
    X=x, ...
    V=reshape(V, size(theta1)), ...
    Rho=rho, ...
    RhoMax=rhoCurrentLimit, ...
    RhoMaxCurrent=rhoCurrentLimit, ...
    RhoCurrentLimit=rhoCurrentLimit, ...
    K=K, ...
    P=P, ...
    ILqr=reshape(iLqr, size(theta1)), ...
    EllipsoidOk=reshape(ellipsoidOk, size(theta1)), ...
    CurrentOk=reshape(currentOk, size(theta1)), ...
    Theta1Ok=reshape(theta1Ok, size(theta1)), ...
    Theta2Ok=reshape(theta2Ok, size(theta1)), ...
    Omega1Ok=reshape(omega1Ok, size(theta1)), ...
    Omega2Ok=reshape(omega2Ok, size(theta1)));

inside = reshape(inside, size(theta1));
end

function ok = localGuardOk(value, guard)
if isempty(guard)
    ok = true(size(value(:).'));
else
    ok = abs(value(:).') <= guard;
end
end

function [K, P, rhoCurrentLimit] = localLqrCaptureData(currentLimit, K, P)
if isempty(K) || isempty(P)
    repoRoot = localFindRepoRoot();
    labPath = fullfile(repoRoot, "references", "zhaw_rotary_pendulum_lab", "lab_model");
    addpath(labPath);

    param = get_parameter();
    [A, B] = linearize_furuta_equilibrium([0; pi], param);
    B = B * param.km;

    Q = diag([1 10 0.001 0.001]);
    R = 0.5 * 10;
    [K, P] = lqr(A, B, Q, R);
end

rhoCurrentLimit = currentLimit^2 / (K / P * K');
end

function root = localFindRepoRoot()
root = string(pwd);
while root ~= ""
    if isfolder(fullfile(root, ".git"))
        return
    end
    parent = string(fileparts(root));
    if parent == root
        break
    end
    root = parent;
end
error("isInLqrCaptureRegion:RepoRootNotFound", ...
    "Could not find repository root from current directory.");
end
