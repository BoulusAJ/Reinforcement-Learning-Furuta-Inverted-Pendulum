function ws = initFurutaModelWorkspace(cfg, options)
%INITFURUTAMODELWORKSPACE Initialize variables expected by Furuta models.
%
% This wrapper intentionally preserves the variable names used by the
% reference Simulink models while avoiding the side effects of running the
% full reference init scripts.

arguments
    cfg struct = makeFurutaConfig()
    options.AssignToBase (1,1) logical = true
    options.InitialTheta (2,1) double = [0; pi + pi/9]
    options.CurrentControllerKpDb (1,1) double = 8
    options.UseReferencePath (1,1) logical = true
end

if options.UseReferencePath
    if ~isfolder(cfg.Reference.LabModelDir)
        error("initFurutaModelWorkspace:MissingReferenceDir", ...
            "Reference lab model directory does not exist: %s", cfg.Reference.LabModelDir);
    end
    addpath(cfg.Reference.LabModelDir);
end

param = get_parameter();

Ts = cfg.Model.PlantSampleTime;
theta0 = options.InitialTheta;

% PWM and constraints from lab_model/inv_rot_pen_ini.m.
pwm_offset = 0.09;
u_max = cfg.Limits.VoltageMax * (1 - pwm_offset);
i_max = 4;
omega_max = 5290 * (u_max / 60) / 60 * 2*pi;

% Current controller quantities used by the reference Simulink models.
Tn_i = param.L / param.R;
Kp_i = db2mag(options.CurrentControllerKpDb);
Kp_i_over_Tn_i = Kp_i / Tn_i;
param.i_max_setpoint = cfg.Limits.CurrentMax;

% Velocity low-pass used in the hardware-oriented controller path.
Tf = 1 / (2*pi*100);

% Notch filter at input, matching the reference script.
s = zpk("s");
omf = 2*pi*680;
D = 0.1;
C_om_filt = (s^2 + 2*D*omf*s + omf^2) / (s^2 + 2*omf*s + omf^2);

% LQR baselines from lab_model/inv_rot_pen_ini.m.
[K_unten, P_unten, V_unten] = localLqrBaseline([0; 0], param, 0.5 * 1);
[K_oben, P_oben, V_oben] = localLqrBaseline([0; pi], param, 0.5 * 10);
K = K_oben;

ws = struct();
ws.cfg = cfg;
ws.Ts = Ts;
ws.theta0 = theta0;
ws.param = param;
ws.pwm_offset = pwm_offset;
ws.u_max = u_max;
ws.i_max = i_max;
ws.omega_max = omega_max;
ws.Tn_i = Tn_i;
ws.Kp_i = Kp_i;
ws.Kp_i_over_Tn_i = Kp_i_over_Tn_i;
ws.Tf = Tf;
ws.omf = omf;
ws.D = D;
ws.C_om_filt = C_om_filt;
ws.K_unten = K_unten;
ws.P_unten = P_unten;
ws.V_unten = V_unten;
ws.K_oben = K_oben;
ws.P_oben = P_oben;
ws.V_oben = V_oben;
ws.K = K;
ws.rewardParams = cfg.Reward;
ws.safetyParams = cfg.Safety;

if options.AssignToBase
    names = fieldnames(ws);
    for idx = 1:numel(names)
        assignin("base", names{idx}, ws.(names{idx}));
    end
end
end

function [K, P, V] = localLqrBaseline(thetaEq, param, r)
[A, B] = linearize_furuta_equilibrium(thetaEq, param);
B = B * param.km;
Q = diag([1 10 0.001 0.001]);
[K, ~, P] = lqr(A, B, Q, r);
dc = dcgain(ss(A - B*K, B, eye(4), 0));
V = 1 / dc(1);
end
