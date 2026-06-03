%% Praktikum P3/P4 DC-Motor
clc, clear variables
%% Abtastzeit / PWM-Frequenz
fs = 20e3;                                              %[Hz] Abtastfrequenz und PWM-Frequenz
Ts = 1/fs;                                              %[s]  Abtastzeit SLDRT
s  = zpk('s');

%% Bode options
bo = bodeoptions;
bo.FreqUnits = 'Hz';
bo.PhaseWrapping = 'on';
bo.Grid = 'on';

%% limits
u_max  = 24;                                            %[V]     Spannungsbegrenzung
i_max  = 3;                                             %[A]     Strombegrenzung
om_max = 200;                                           %[rad/s] Drehzahlbegrenzung

%% DC-motor
km = 97.5e-3;                                           %[Nm/A] Drehzahlkonstante
R  = 4.12*1.1;                                          %[Ohm]  Spulen Widerstand
L  = 1.31e-3;                                           %[H]    Spulen Induktivität
G_u2i = 1 / (L*s + R);

%% RC-Filter Strommessung
Rf = 1e3;                                               %1kOhm RC-Filter Strommessung
Cf = 100e-9;                                            %100nF RC-Filter Strommessung
G_i2if = 1 / (Rf*Cf*s + 1);

%% Current PI-control
Tt = Ts;                                                %mittlere Totzeit Abtastung und PWM-Delay

Tn_i = L/R;                                             %Nachstellzeit: dominante Zeitkonstante kompensieren
Kp_i = db2mag(12);                                      %Proportional-Verstärkung: 60...70° Phasenreserve
C_i_PI = Kp_i * (Tn_i*s + 1)/(Tn_i*s);                  %PI-Regler

L_i = C_i_PI * G_u2i * G_i2if * exp(-Tt*s);             %Open-Loop
T_i = feedback(C_i_PI * G_u2i * exp(-Tt*s), G_i2if);    %Komplementäre Sensitivität
S_i = feedback(1, L_i);                                 %Sensitivität

figure(1)
margin(L_i)

figure(2)
bodemag(T_i,S_i, bo)
legend('T','S','Location','best')
title('Closed Loop Current-Control')

f_bw_i = bandwidth(T_i)/(2*pi)                          %Bandbreite Closed Loop

%% Speed P-Control
J = 1063e-7;                                            %[kg*m^2] total inertia
om_bw = 2*pi*1;                                         %[Hz]     closed loop bandwidth
Tf = 1/(2*pi*10);                                       %[s]      speed-filter time constant

G_phi2omf = s / (Tf*s + 1);
Kp_om = om_bw * J/km;

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

figure(3)
margin(L_om, 2*pi*L_om.Frequency), grid on

figure(4)
bodemag(S_om, T_om, 2*pi*L_om.Frequency), grid on
legend('Location', 'best')

% Calculate step response from frd
[time, step_resp] = get_step_resp_from_frd(T_om, Ts);

figure(5)
plot(time, step_resp), grid on
ylabel('Velocity (rad/sec)'), xlabel('Time (sec)')
xlim([0 0.08])


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

i_max = 1;              % Max. current in A (rel. safe)
phi2_max = 30 * pi/180; % Angle limit for outer motor velocity controller

param = get_parameter()

% Extracted Parameters
L1 = 0.0855;      % Length motor arm in m
Jp = 6.063e-05;   % Inertia pendulum in kg*m^2
m2 = 0.028;       % Mass pendulum in kg
l2 = 0.0805;      % Length from pendulum joint to center of mass in m
b2 = 0 * 4.4e-05; % Friction coefficient in Nm/(rad/sec) 
g  = 9.81;        % Gravity constant in m/sec^2


%% Approximate the speed closed-loop

wcl = 2*pi*53.7;
Dcl = 0.6;
T_om_mod = wcl^2 / (s^2 + 2*Dcl*wcl*s + wcl^2);

figure(6)
bode(T_om, T_om_mod, 2*pi*L_om.Frequency), grid on
legend('Location', 'best')


%% Model of the pendulum

% On_the_Dynamics_of_the_Furuta_Pendulum.pdf Eq. 29
%   m2 * L1 * l2 * cos(theta2) * ddot_theta1 + (J2zz + m2 * l2^2) * ddot_theta2 ...
%   + 0.5 * dot_theta1^2 * sin(2*theta2) * (-m2 * l2^2 - J2yy + J2xx) ...
%   + b2 * dot_theta2 + m2 * g * l2 * sin(theta2) = 0;

% Linearization about pendulum-up (theta2 ~= pi)
%   (J2zz + m2*l2^2) * ddot_dtheta2 + b2 * dot_dtheta2 - m2*g*l2 * dtheta2 =   m2*L1*l2 * ddot_dtheta1;
%   with dtheta1 = theta1, dtheta2 = theta2 - pi (linearization around upright)

% Linearization about pendulum-down (theta2 ~= 0)
%   (J2zz + m2*l2^2) * ddot_dtheta2 + b2 * dot_dtheta2 + m2*g*l2 * dtheta2 = - m2*L1*l2 * ddot_dtheta1
%   with dtheta1 = theta1, dtheta2 = theta2 (around zero)


%% Controller pendulum down

is_pendulum_up = 0;
phi2_enable  = 90*pi/180;
phi2_disable = 70*pi/180;

% Pendulum down (theta2 ≈ 0)
G_om2phi2 = -(m2*L1*l2)*s / ( (Jp + m2*l2^2)*s^2 + b2*s + m2*g*l2 );

% Plant (negative sign)
% G_phi2 = - T_om_mod * G_om2phi2;
G_phi2 = - G_om2phi2; % Neglect speed controll loop dynamics

% PI controller
Tn_phi2 = 1 / 9;
% C_phi2_tilde = (Tn_phi2*s + 1) / (Tn_phi2*s)

% controlSystemDesigner(G_phi2)

% L_phi2 = minreal(C_phi2_tilde * G_phi2);

% Carefull: Hardcoded here
L_phi2 = 0.7961 * (s+9) / (s^2 + 91.34)

z = -9;
p = 1i * sqrt(91.34);
L_phi2_tilde = (s - z) / ((s - p) * (s + p))

% syms sB z p
% f = collect( 1/(sB - p) + 1/(sB + p) - 1/(sB - z), sB)
% % (p^2 + sB^2 - 2*z*sB)/(- p^2*sB + z*p^2 + sB^3 - z*sB^2)

% Break-in and breakaway point candidates
sB = roots([1, -2*z, p^2])
sB1 = sB(1) % Only sB1 is a valid break-in point

% Double pole at break-in point
k_sB1 = abs(sB1 - p) * abs(sB1 + p) / abs(sB1 - z)
Kp_phi2 = k_sB1 / 0.7961;
pole(feedback(Kp_phi2 * L_phi2, 1))

% Check via Koni's function
[sA_, pA_, sB_] = EvalRL(z, [p, -p])

figure(7)
rlocus(L_phi2, (0:0.01:100)), grid on
axis([-40 10 -20 20])


%% Controller pendulum up

is_pendulum_up = 1;
phi2_enable  = 30*pi/180;
phi2_disable = 10*pi/180;

% Pendulum up (theta2 ≈ pi)
G_om2phi2 =  (m2*L1*l2)*s / ( (Jp + m2*l2^2)*s^2 + b2*s - m2*g*l2 );

% Plant
% G_phi2 = T_om_mod * G_om2phi2;
G_phi2 = G_om2phi2; % Neglect speed controll loop dynamics

% PI controller
Tn_phi2 = 1 / 18;
% C_phi2_tilde = (Tn_phi2*s + 1) / (Tn_phi2*s)

% controlSystemDesigner(G_phi2)

% L_phi2 = minreal(C_phi2_tilde * G_phi2);

% Carefull: Hardcoded here
L_phi2 = 0.7961 * (s+18) / ((s+9.557) * (s-9.557))

z = -18;
p = -9.557;
L_phi2_tilde = (s - z) / ((s - p) * (s + p))

% syms sB z p
% f = collect( 1/(sB - p) + 1/(sB + p) - 1/(sB - z), sB)
% % (p^2 + sB^2 - 2*z*sB)/(- p^2*sB + z*p^2 + sB^3 - z*sB^2)

% Break-in and breakaway point candidates
sB = roots([1, -2*z, p^2])
sB1 = sB(1) % Breakaway point
sB2 = sB(2) % Break-in point

% Double pole at break-in point
k_sB1 = abs(sB1 - p) * abs(sB1 + p) / abs(sB1 - z)
Kp_phi2 = k_sB1 / 0.7961
pole(feedback(Kp_phi2 * L_phi2, 1))

% Double pole at breakaway point
k_sB2 = abs(sB2 - p) * abs(sB2 + p) / abs(sB2 - z)
Kp_phi2 = k_sB2 / 0.7961
pole(feedback(Kp_phi2 * L_phi2, 1))

% Find the max ot the circle of the root-loci
Kp_phi2 = (k_sB2 + (k_sB1 - k_sB2) / 2) / 0.7961
pole(feedback(Kp_phi2 * L_phi2, 1))

% Check via Koni's function
[sA_, pA_, sB_] = EvalRL(z, [p, -p])

figure(8)
rlocus(L_phi2, (0:0.01:100)), grid on
axis([-40 10 -20 20])


%% Additional motor speed controller when pendulum up

C_phi2 = Kp_phi2 * (Tn_phi2*s + 1) / (Tn_phi2*s)

% Plant
G_v = -feedback(C_phi2 * T_om_mod, G_om2phi2);

% P
Kp_v = 0.0116;
C_v = Kp_v;

% controlSystemDesigner(G_v)

L_v = minreal(C_v * G_v);
S_v = feedback(1, L_v);

figure(9)
rlocus(L_v), grid on
axis([-400 120 -300 300])

% sort( ( sign(real(pole(S_v))) .* abs(pole(S_v)) ).' )
damp(S_v)

% figure(10)
% % pzmap(L_v), grid on
% subplot(121)
% margin(C_v * G_v), grid on
% subplot(122)
% bodemag(S_v), grid on
