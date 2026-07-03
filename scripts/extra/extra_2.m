% Enable- and Disable Angle in rad
phi2_enable  = 30 * pi/180;
phi2_disable = 10 * pi/180;

% Differentiating Filter
s = zpk('s');
Tf = 1 / (2*pi*100);
G_diff = c2d(s / (Tf*s + 1), Ts, 'tustin');

%%
fc_diff_theta1 = 100;  % Hz, keep motor as-is initially
fc_diff_theta2 = 100;   % Hz, more conservative pendulum estimate

Tf1 = 1 / (2*pi*fc_diff_theta1);
Tf2 = 1 / (2*pi*fc_diff_theta2);

% G_diff_theta1 = c2d(s / (Tf1*s + 1), Ts, "tustin");
% G_diff_theta2 = c2d(s / (Tf2*s + 1), Ts, "tustin");

G_diff_theta1 = c2d(s / (Tf1*s + 1), cfg.Agent.SampleTime, "tustin");
G_diff_theta2 = c2d(s / (Tf2*s + 1), cfg.Agent.SampleTime, "tustin");
G_filt_theta1 = c2d(1 / (Tf1*s + 1), cfg.Agent.SampleTime, "tustin");
G_filt_theta2 = c2d(1 / (Tf2*s + 1), cfg.Agent.SampleTime, "tustin");
%%
G_diff_theta1_c = ss(-1/Tf1, 1/Tf1, -1/Tf1, 1/Tf1);
G_diff_theta2_c = ss(-1/Tf2, 1/Tf2, -1/Tf2, 1/Tf2);

G_diff_theta1_ss = c2d(G_diff_theta1_c, cfg.Agent.SampleTime, "tustin");
G_diff_theta2_ss = c2d(G_diff_theta2_c, cfg.Agent.SampleTime, "tustin");
%%
Ts_fast = 50e-6;
f_notch_encoder_Hz = 680;
D_notch_encoder = 0.6;

s = zpk("s");
w_notch = 2*pi*f_notch_encoder_Hz;

G_encoder_notch = ...
    (s^2 + w_notch^2) / ...
    (s^2 + 2*D_notch_encoder*w_notch*s + w_notch^2);

G_encoder_notch_d = c2d(G_encoder_notch, Ts_fast, "tustin");
G_encoder_notch_d_ss = ss(G_encoder_notch_d);

%%
% Current setpoint low-pass filter matching uC firmware
Ts_fast = 50e-6;          % 20 kHz fast loop
f_lpf_i_cmd_Hz = 500;     % firmware current-setpoint LPF cutoff
D_lpf_i_cmd = 0.9;        % damping

s = zpk("s");
w_lpf_i_cmd = 2*pi*f_lpf_i_cmd_Hz;

G_i_cmd_lpf = w_lpf_i_cmd^2 / ...
    (s^2 + 2*D_lpf_i_cmd*w_lpf_i_cmd*s + w_lpf_i_cmd^2);

G_i_cmd_lpf_d = c2d(G_i_cmd_lpf, Ts_fast, "tustin");

%%
% PI output roll-off filter matching uC firmware
Ts_fast = 50e-6;          % 20 kHz fast loop
f_pi_rolloff_Hz = 3000;   % firmware PI output roll-off
tau_ro_i = 1 / (2*pi*f_pi_rolloff_Hz);

s = zpk("s");

G_pi_rolloff = 1 / (tau_ro_i*s + 1);
G_pi_rolloff_d = c2d(G_pi_rolloff, Ts_fast, "tustin");

%%
param.Encoder.Theta1.ResolutionRad = 2*pi / (4*4096);
param.Encoder.Theta2.ResolutionRad = 2*pi / (4*1024);

%%
currentBias_A = 0.0026;            % A, measured mean offset
currentNoiseStd_A = 0.0084;        % A, measured detrended noise std

%%
I_static_comp_A = 0.0205;
param.Motor.km = param.km;
param.Friction.Theta1.B = 1e-5;                 % N*m*s/rad, tune/randomize later
param.Friction.Theta1.Tc = param.Motor.km * 0.015;
param.Friction.Theta1.Ts = param.Motor.km * I_static_comp_A;
param.Friction.Theta1.OmegaS = 0.10;            % rad/s
param.Friction.Theta1.OmegaEps = 0.01;          % rad/s
param.Friction.Theta1.viscousScalingFactor = 7.5; % latest % 7 another good overall option
param.Friction.Theta1.coulombStaticScalingFactor = 2.3; % latest % 2.3 another good overall option
% looks to be the best overall, when comparimg it vs 20260622_201704_hardware from results\model_vs_hardware\test1_constant_current_0p2a_disable_0p8s


%%
%load C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum\results\model_vs_hardware\test1_constant_current_0p2a_disable_0p8s\20260622_201704_hardware\run.mat signals
