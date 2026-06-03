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

% Pendulum down (theta2 ≈ 0)
G_om2phi2 = -(m2*L1*l2)*s / ( (Jp + m2*l2^2)*s^2 + b2*s + m2*g*l2 );

% Plant: Negative sign, needs to be implemented!
G_phi2 = -G_om2phi2 % Neglect speed controll loop dynamics

% PI controller
Tn_phi2 = 1 / 9;
C_phi2 = (Tn_phi2*s + 1) / (Tn_phi2*s)

% Loop (does not include Kp)
L_phi2 = minreal( C_phi2 * G_phi2 )

% Normalised Loop
[z, p, ks] = zpkdata(L_phi2, 'v')
L_phi2_tilde = (s - z) / ((s - p(1)) * (s + p(1)))

% Break-in and breakaway point candidates
sB = roots([1, -2*z, p(1)^2]) % sB^2 - 2*z * sB + p(1)^2 != 0
% Only sB(1) is a valid break-in point

% Double pole at break-in point
k_sB1 = abs(sB(1) - p(1)) * abs(sB(1) + p(1)) / abs(sB(1) - z)
Kp_phi2 = k_sB1 / ks
damp(feedback(Kp_phi2 * L_phi2, 1))

% % Check via Koni's function
% [sA_, pA_, sB_] = EvalRL(z, p)

figure(2)
% rlocus(L_phi2, (0:0.001:100)), grid on
rlocus(L_phi2), grid on
axis([-40 10 -20 20])


%% Controller pendulum up

% Pendulum up (theta2 ≈ pi)
G_om2phi2 =  (m2*L1*l2)*s / ( (Jp + m2*l2^2)*s^2 + b2*s - m2*g*l2 );

% Plant: Substraction of pi needs to be implemented!
G_phi2 = G_om2phi2 % Neglect speed controll loop dynamics

% PI controller
Tn_phi2 = 1 / 18;
C_phi2 = (Tn_phi2*s + 1) / (Tn_phi2*s)

% Loop (does not include Kp)
L_phi2 = minreal( C_phi2 * G_phi2 )

% Normalised Loop
[z, p, ks] = zpkdata(L_phi2, 'v')
L_phi2_tilde = (s - z) / ((s - p(1)) * (s + p(1)))

% Break-in and breakaway point candidates
sB = roots([1, -2*z, p(1)^2]) % sB^2 - 2*z * sB + p(1)^2 != 0
% sB(1) is a break-in point
% sB(2) is a breakaway point

% Double pole at break-in point
k_sB1 = abs(sB(1) - p(1)) * abs(sB(1) + p(1)) / abs(sB(1) - z)
Kp_phi2 = k_sB1 / ks
damp(feedback(Kp_phi2 * L_phi2, 1))

% Double pole at breakaway point
k_sB2 = abs(sB(2) - p(1)) * abs(sB(2) + p(1)) / abs(sB(1) - z)
Kp_phi2 = k_sB2 / ks
damp(feedback(Kp_phi2 * L_phi2, 1))

% Find the max ot the circle of the root-loci
Kp_phi2 = ((k_sB1 - k_sB2) / 2 + k_sB2) / ks
damp(feedback(Kp_phi2 * L_phi2, 1))

% % Check via Koni's function
% [sA_, pA_, sB_] = EvalRL(z, p)

figure(3)
% rlocus(L_phi2, (0:0.001:100)), grid on
rlocus(L_phi2), grid on
axis([-40 10 -20 20])


%% Additional motor speed controller when pendulum up (only to show the students)

% Approximate the speed closed-loop
wcl = 2*pi*53.7;
Dcl = 0.6;
T_om_mod = wcl^2 / (s^2 + 2*Dcl*wcl*s + wcl^2);

figure(4)
bode(T_om, T_om_mod, 2*pi*L_om.Frequency), grid on
legend('Location', 'best')

% Angle Controller
C_phi2 = Kp_phi2 * (Tn_phi2*s + 1) / (Tn_phi2*s)

% Plant: Negative sign, needs to be implemented!
G_v = -feedback(C_phi2 * T_om_mod, G_om2phi2);

% P controller
Kp_v = 0.0116;
C_v = Kp_v;

% Loop and Sensitivity
L_v = minreal(G_v); % (does not include Kp)
S_v = feedback(1, C_v * L_v);

figure(5)
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
