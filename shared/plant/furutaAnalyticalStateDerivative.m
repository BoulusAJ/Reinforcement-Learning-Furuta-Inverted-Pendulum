function dx = furutaAnalyticalStateDerivative(x, motorTorque, param)
%FURUTAANALYTICALSTATEDERIVATIVE Four-state nonlinear Furuta dynamics.
%
% State convention:
%   x = [theta1; theta2; omega1; omega2]
%   theta2 = 0 is hanging down and theta2 = pi is upright.

% motorTorque acts on the rotary arm. No electrical or current-controller
% dynamics are included; those are intentionally replaced by tau = km*i.

theta = x(1:2);
omega = x(3:4);

[M, C, G, D] = localDynamicsMatrices(theta, omega, param);
alpha = M \ ([motorTorque; 0] - (C + D) * omega - G);

dx = [omega; alpha];
end

function [M, C, G, D] = localDynamicsMatrices(theta, omega, param)
s2 = sin(theta(2));
c2 = cos(theta(2));
s2c2 = sin(2 * theta(2));
w1 = omega(1);
w2 = omega(2);

M11 = param.J1zz + param.m1 * param.l1^2 + param.m2 * param.L1^2 ...
    + (param.J2yy + param.m2 * param.l2^2) * s2^2 ...
    + param.J2xx * c2^2;
M12 = param.m2 * param.L1 * param.l2 * c2;
M22 = param.J2zz + param.m2 * param.l2^2;
M = [M11, M12; M12, M22];

C11 = w2 * s2c2 * (param.m2 * param.l2^2 + param.J2yy - param.J2xx);
C12 = -param.m2 * param.L1 * param.l2 * s2 * w2;
C21 = 0.5 * w1 * s2c2 * (-param.m2 * param.l2^2 - param.J2yy + param.J2xx);
C = [C11, C12; C21, 0];

G = [0; param.m2 * param.g * param.l2 * sin(theta(2))];
D = diag([param.b1, param.b2]);
end
