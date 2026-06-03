%% Analytische Approximation

% param = get_parameter();
% J = param.J1zz + param.m1*param.l1^2
% J_with_pendulum = J + param.m2*param.L1^2 - 1.2000e-05
% 2.9469e-04

%% Symmetrischer Quader

rho = 2750
b = 30e-3
h = 15e-3
l = 140e-3
m = b*h*l*rho

Jz = m/12 * (l^2 + b^2)
% 2.9597e-04