clc, clear variables
%% Abtastzeit / PWM-Frequenz
fs = 20e3;                             %[Hz] Abtastfrequenz und PWM-Frequenz
Ts = 1/fs;                             %[s]  Abtastzeit SLDRT
s  = zpk('s');

%% Bode options
bo = bodeoptions;
bo.FreqUnits = 'Hz';
bo.PhaseWrapping = 'on';
bo.Grid = 'on';

%% limits
u_max  = 24;                           %[V]     Spannungsbegrenzung
i_max = 1;                             %[A]     Strombegrenzung
om_max = 200;                          %[rad/s] Drehzahlbegrenzung
phi2_max = 30 * pi/180;                %[rad]   Winkelbegrenzung

%% DC-motor
km = 97.5e-3;                          %[Nm/A] Drehzahlkonstante
R  = 4.12*1.1;                         %[Ohm]  Spulen Widerstand
L  = 1.31e-3;                          %[H]    Spulen Induktivität
G_u2i = 1 / (L*s + R);

%% RC-Filter Strommessung
Rf = 1e3;                              %1kOhm RC-Filter Strommessung
Cf = 100e-9;                           %100nF RC-Filter Strommessung
G_i2if = 1 / (Rf*Cf*s + 1);

%% Current PI-control
Tt = Ts;                               %mittlere Totzeit Abtastung und PWM-Delay

Tn_i = L/R;                            %Nachstellzeit: dominante Zeitkonstante kompensieren
Kp_i = db2mag(12);                     %Proportional-Verstärkung: 60...70° Phasenreserve
C_i_PI = Kp_i * (Tn_i*s + 1)/(Tn_i*s); %PI-Regler

%% Speed Controller

load G_i2phi_frd.mat % save G_i2phi_frd G_i2phi_frd

% Velocity Lowpass
Tf = 1/(2*pi*100);
G_phi2omf = s / (Tf*s + 1);
G_om2omf  = 1 / (Tf*s + 1);

% Plant (Regelstrecke)
G_om = G_i2phi_frd * G_phi2omf;

% Controller (Regler)

% PI
Tn_om = 1/(2*pi*1);
Kp_om = db2mag(-5) / 2;
C_om = Kp_om * (Tn_om*s + 1) / (Tn_om*s);

% Notch
omf = 2*pi*680;
D = 0.1;
C_om_filt = (s^2 + 2*D*omf*s + omf^2) / (s^2 + 2*omf*s + omf^2);
C_om = C_om * C_om_filt;

% Open-Loop, Sensitivity and Complementary Sensitivity
L_om = C_om * G_om;
S_om = 1 / (1 + L_om);
T_om = 1 - S_om;

figure(1)
subplot(121)
margin(L_om, 2*pi*L_om.Frequency), grid on
subplot(122)
bodemag(S_om, T_om, 2*pi*L_om.Frequency), grid on
legend('Location', 'best')


%% Notes

% - The pendulum encoder has a resolution of 1024 increments, with a positive
%   sign for positive rotation.
% - Short-angle wrapping is performed using atan2(sin(phi2), cos(phi2)).
% - For safety reasons, the current is limited to 1 A.
% - A logic block for enabling and disabling the angle controller is
%   implemented.
% - For simplicity, friction is neglected.
% - When controlling the pendulum in the downward position, a negative sign
%   must be applied after the angle controller; for the upward position, a
%   positive sign must be used.
% - When the pendulum is controlled in the upward position, the outer motor
%   velocity controller requires a negative sign. This results in a negative
%   loop gain, so the drawing rules for negative loop gain must be taken
%   into account.
% - For the outer motor velocity controller, the inner velocity controller
%   must be considered.


%% New Parameters

% Enable- and Disable Angle in rad
phi2_enable  = 30*pi/180;
phi2_disable = 10*pi/180;

% Parameter model
L1 = 0.0855;      % Length motor arm in m
Jp = 6.063e-05;   % Inertia pendulum in kg*m^2
m2 = 0.028;       % Mass pendulum in kg
l2 = 0.0805;      % Length from pendulum joint to center of mass in m
b2 = 0 * 4.4e-05; % Friction coefficient in Nm/(rad/sec) 
g  = 9.81;        % Gravity constant in m/sec^2


%% Controller pendulum down




%% Controller pendulum up


