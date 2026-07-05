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
    options.InitialOmega (2,1) double = [0; 0]
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
omega0 = options.InitialOmega;

% PWM and constraints from lab_model/inv_rot_pen_ini.m. New configs keep
% cfg.Limits.VoltageMax unified with u_max; legacy saved configs stored the
% raw 24 V supply here and did not include PwmOffset.
if isfield(cfg.Limits, "PwmOffset")
    pwm_offset = cfg.Limits.PwmOffset;
    u_max = cfg.Limits.VoltageMax;
else
    pwm_offset = 0.09;
    u_max = cfg.Limits.VoltageMax * (1 - pwm_offset);
end
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

detailedWs = localDetailedHardwareWorkspace(cfg, param, Ts);
if isfield(detailedWs, "param")
    param = detailedWs.param;
end

ws = struct();
ws.cfg = cfg;
ws.Ts = Ts;
ws.theta0 = theta0;
ws.omega0 = omega0;
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
ws.FurutaRewardDiagnosisBus = createFurutaRewardDiagnosisBus(AssignToBase=false);
ws = localMergeStructs(ws, detailedWs);

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

function detailedWs = localDetailedHardwareWorkspace(cfg, param, Ts)
detailedWs = struct();

if ~isfield(cfg, "DetailedModel") || ...
        ~isfield(cfg.DetailedModel, "Enabled") || ...
        ~cfg.DetailedModel.Enabled
    return;
end

s = zpk("s");

fc_diff_theta1 = cfg.DetailedModel.fc_diff_theta1_Hz;
fc_diff_theta2 = cfg.DetailedModel.fc_diff_theta2_Hz;
Tf1 = 1 / (2*pi*fc_diff_theta1);
Tf2 = 1 / (2*pi*fc_diff_theta2);

G_diff_theta1 = c2d(s / (Tf1*s + 1), cfg.Agent.SampleTime, "tustin");
G_diff_theta2 = c2d(s / (Tf2*s + 1), cfg.Agent.SampleTime, "tustin");
G_filt_theta1 = c2d(1 / (Tf1*s + 1), cfg.Agent.SampleTime, "tustin");
G_filt_theta2 = c2d(1 / (Tf2*s + 1), cfg.Agent.SampleTime, "tustin");

G_diff_theta1_c = ss(-1/Tf1, 1/Tf1, -1/Tf1, 1/Tf1);
G_diff_theta2_c = ss(-1/Tf2, 1/Tf2, -1/Tf2, 1/Tf2);
G_diff_theta1_ss = c2d(G_diff_theta1_c, cfg.Agent.SampleTime, "tustin");
G_diff_theta2_ss = c2d(G_diff_theta2_c, cfg.Agent.SampleTime, "tustin");

Ts_fast = cfg.DetailedModel.TsFast;
f_notch_encoder_Hz = cfg.DetailedModel.EncoderNotchFrequencyHz;
D_notch_encoder = cfg.DetailedModel.EncoderNotchDamping;
w_notch = 2*pi*f_notch_encoder_Hz;
G_encoder_notch = ...
    (s^2 + w_notch^2) / ...
    (s^2 + 2*D_notch_encoder*w_notch*s + w_notch^2);
G_encoder_notch_d = c2d(G_encoder_notch, Ts_fast, "tustin");
G_encoder_notch_d_ss = ss(G_encoder_notch_d);

f_lpf_i_cmd_Hz = cfg.DetailedModel.CurrentCommandLpfFrequencyHz;
D_lpf_i_cmd = cfg.DetailedModel.CurrentCommandLpfDamping;
w_lpf_i_cmd = 2*pi*f_lpf_i_cmd_Hz;
G_i_cmd_lpf = w_lpf_i_cmd^2 / ...
    (s^2 + 2*D_lpf_i_cmd*w_lpf_i_cmd*s + w_lpf_i_cmd^2);
G_i_cmd_lpf_d = c2d(G_i_cmd_lpf, Ts_fast, "tustin");

f_pi_rolloff_Hz = cfg.DetailedModel.PiRolloffFrequencyHz;
tau_ro_i = 1 / (2*pi*f_pi_rolloff_Hz);
G_pi_rolloff = 1 / (tau_ro_i*s + 1);
G_pi_rolloff_d = c2d(G_pi_rolloff, Ts_fast, "tustin");

param.Motor.km = param.km;
param.Encoder.Theta1.ResolutionRad = 2*pi / cfg.DetailedModel.EncoderTheta1CountsPerRev;
param.Encoder.Theta2.ResolutionRad = 2*pi / cfg.DetailedModel.EncoderTheta2CountsPerRev;
param.Friction.Theta1 = cfg.DetailedModel.Friction.Theta1;
param.Friction.Theta1.Tc = param.Motor.km * cfg.DetailedModel.Friction.Theta1.CoulombCurrent_A;
param.Friction.Theta1.Ts = param.Motor.km * cfg.DetailedModel.I_static_comp_A;

detailedWs.param = param;
detailedWs.fc_diff_theta1 = fc_diff_theta1;
detailedWs.fc_diff_theta2 = fc_diff_theta2;
detailedWs.Tf1 = Tf1;
detailedWs.Tf2 = Tf2;
detailedWs.G_diff_theta1 = G_diff_theta1;
detailedWs.G_diff_theta2 = G_diff_theta2;
detailedWs.G_filt_theta1 = G_filt_theta1;
detailedWs.G_filt_theta2 = G_filt_theta2;
detailedWs.G_diff_theta1_c = G_diff_theta1_c;
detailedWs.G_diff_theta2_c = G_diff_theta2_c;
detailedWs.G_diff_theta1_ss = G_diff_theta1_ss;
detailedWs.G_diff_theta2_ss = G_diff_theta2_ss;
detailedWs.Ts_fast = Ts_fast;
detailedWs.f_notch_encoder_Hz = f_notch_encoder_Hz;
detailedWs.D_notch_encoder = D_notch_encoder;
detailedWs.G_encoder_notch = G_encoder_notch;
detailedWs.G_encoder_notch_d = G_encoder_notch_d;
detailedWs.G_encoder_notch_d_ss = G_encoder_notch_d_ss;
detailedWs.f_lpf_i_cmd_Hz = f_lpf_i_cmd_Hz;
detailedWs.D_lpf_i_cmd = D_lpf_i_cmd;
detailedWs.G_i_cmd_lpf = G_i_cmd_lpf;
detailedWs.G_i_cmd_lpf_d = G_i_cmd_lpf_d;
detailedWs.f_pi_rolloff_Hz = f_pi_rolloff_Hz;
detailedWs.tau_ro_i = tau_ro_i;
detailedWs.G_pi_rolloff = G_pi_rolloff;
detailedWs.G_pi_rolloff_d = G_pi_rolloff_d;
detailedWs.currentBias_A = cfg.DetailedModel.currentBias_A;
detailedWs.currentNoiseStd_A = cfg.DetailedModel.currentNoiseStd_A;
detailedWs.I_static_comp_A = cfg.DetailedModel.I_static_comp_A;
detailedWs.DetailedModelConfig = cfg.DetailedModel;
if isfield(cfg, "DomainRandomization")
    detailedWs.DomainRandomizationConfig = cfg.DomainRandomization;
end
end

function out = localMergeStructs(out, extra)
names = fieldnames(extra);
for idx = 1:numel(names)
    out.(names{idx}) = extra.(names{idx});
end
end
