% Enable- and Disable Angle in rad
phi2_enable  = 30 * pi/180;
phi2_disable = 10 * pi/180;

% Differentiating Filter
s = zpk('s');
Tf = 1 / (2*pi*100);
G_diff = c2d(s / (Tf*s + 1), Ts, 'tustin');