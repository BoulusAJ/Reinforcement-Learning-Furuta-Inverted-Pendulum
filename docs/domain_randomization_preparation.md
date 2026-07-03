# Domain Randomization Preparation

Date: 2026-07-01

This note records model variables and implementation reminders for future
domain-randomized training. It is also useful if domain randomization is not
used immediately, because the Simulink model now has explicit current
measurement noise parameters.

## Base-To-Detailed Model Summary

The base model treated the Furuta plant and actuator path relatively
idealistically. The detailed model is moving toward the actual hardware signal
chain: measured sensors, firmware filters, current-loop dynamics, actuator
dead-zone compensation, and non-ideal plant friction.

Main updates from the base model:

- added current measurement bias and noise with `currentBias_A` and
  `currentNoiseStd_A`,
- added command-side static-friction/dead-zone compensation through
  `I_static_comp_A`,
- added physical theta1 friction in the plant dynamics using smooth viscous,
  Coulomb, and static/Stribeck-like terms,
- added encoder quantization parameters for the motor and pendulum encoders,
- documented that firmware encoder angles are unwrapped, reset-relative, and
  that the pendulum encoder sign is inverted in firmware,
- added the firmware-style 680 Hz encoder notch filter in the 20 kHz fast
  loop,
- added the firmware current-setpoint low-pass filter before the current PI
  controller,
- documented the current PI loop with its 20 kHz rate, backward-Euler
  integrator, integrator/output saturation, and 3 kHz output roll-off,
- documented the voltage/PWM `+2 V` dead-zone compensation after the PI
  controller,
- documented the communication-rate behavior between the 200/500 Hz SLDRT/RL
  command and the 20 kHz firmware loop,
- added hardware-style velocity estimation using differentiated filtered
  encoder angles instead of ideal plant velocity,
- identified high-priority future domain-randomization targets such as
  friction, current scaling, dead zone, current limit, delay/filtering, encoder
  quantization, and current measurement noise.

In short, the detailed model changes the simulation from an ideal plant plus
current command into a hardware-facing model with actuator, sensor, firmware,
and plant nonidealities represented explicitly enough to support later domain
randomization.

## Current Measurement Noise Variables

The Simulink model now contains two variables for current measurement modeling:

```matlab
currentBias_A
currentNoiseStd_A
```

Intended interpretation:

```matlab
i_meas = i_true + currentBias_A + currentNoiseStd_A * noise
```

where `noise` is a zero-mean unit-variance random signal inside Simulink, or an
equivalent sample-time-aware noise source.

Measured reference values from `data/system_measurements/uncontrolled_current.mat`:

```text
currentBias_A     approximately 0.0026 A
currentNoiseStd_A approximately 0.0084 A
```

The measured noise is centered closely enough for a Gaussian baseline model,
but it has heavier tails than an ideal normal distribution. For training, this
is still a reasonable first approximation as long as it is documented as a
simplified measurement-noise model.

## Future MATLAB Wiring

When updating the training scripts later, these variables should be initialized
for ordinary non-randomized runs and optionally randomized per episode in the
reset function.

For a fixed nominal run:

```matlab
in = setVariable(in, "currentBias_A", 0.0026);
in = setVariable(in, "currentNoiseStd_A", 0.0084);
```

For domain randomization:

```matlab
currentBias_A = sampleUniform(curriculumParams.CurrentBiasRange_A);
currentNoiseStd_A = sampleUniform(curriculumParams.CurrentNoiseStdRange_A);

in = setVariable(in, "currentBias_A", currentBias_A);
in = setVariable(in, "currentNoiseStd_A", currentNoiseStd_A);
```

Candidate conservative ranges:

```text
CurrentBiasRange_A     = [-0.010, 0.010]
CurrentNoiseStdRange_A = [0.004, 0.020]
```

The reset function should keep working when these fields are absent, so older
configs and fixed evaluations remain compatible.

## Reminder

Episode-level randomization should sample `currentBias_A` and
`currentNoiseStd_A`. Step-level randomness should stay inside the Simulink noise
source. In other words, the reset function chooses the noise model for the
episode; the model generates the actual noise samples during simulation.

## Plant Friction And Dead-Zone Compensation

The model changes should keep command-side compensation and physical plant
friction separate.

Command-side dead-zone/static-friction feedforward compensation belongs before
the torque input to the physical plant:

```matlab
I_static_comp_A = 0.0205;
I_cmd_comp = I_cmd + signnum(I_cmd) * I_static_comp_A;
tau = param.Motor.km * I_cmd_comp;
```

This is not the same as physical friction. It is a controller/uC command-path
offset that helps overcome a small current dead zone or breakaway friction on
the real setup.

`I_static_comp_A` should be included in domain randomization. It is a
command-path compensation value, not a fixed physical constant, and the real
best value may shift with temperature, friction state, wiring, or current-loop
details. Randomizing it also teaches the policy to tolerate under-compensated
and over-compensated actuator behavior.

Inside the physical plant MATLAB Function block, add velocity-opposing
theta1 friction to the dynamics:

```matlab
[M, C, G, D] = calculate_dynamics_furuta(theta, omega, param);

tauFric1 = frictionTorque(omega(1), param.Friction.Theta1);
tauFric = [tauFric1; 0];

alpha = M \ ([tau; 0] - (C + D) * omega - G - tauFric);
```

Suggested first-pass theta1 friction parameters:

```matlab
I_static_comp_A = 0.0205;

param.Friction.Theta1.B = 1e-5;                 % N*m*s/rad, tune/randomize later
param.Friction.Theta1.Tc = param.Motor.km * 0.015;
param.Friction.Theta1.Ts = param.Motor.km * I_static_comp_A;
param.Friction.Theta1.OmegaS = 0.10;            % rad/s
param.Friction.Theta1.OmegaEps = 0.01;          % rad/s
```

Use a smooth Coulomb/static friction expression rather than a hard
`sign(omega)` discontinuity:

```matlab
function tauF = frictionTorque(omega, fric)
    viscous = fric.B * omega;

    coulombStatic = ...
        (fric.Tc + (fric.Ts - fric.Tc) * exp(-(abs(omega) / fric.OmegaS)^2)) * ...
        tanh(omega / fric.OmegaEps);

    tauF = viscous + coulombStatic;
end
```

Empirical update from later model-vs-hardware experimentation: the current best
overall match to
`results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/20260622_201704_hardware`
used scaled theta1 viscous and Coulomb/static terms:

```matlab
tauF = viscous * 7 + coulombStatic * 2.3;
```

Treat these scale factors as a calibration result for the current detailed
analytical model, not as final physical constants. They should be revisited
after more hardware cases are compared. If they are used in training, expose
them explicitly as tunable or randomizable friction scale parameters instead
of burying the multipliers inside the MATLAB Function block.

Start with theta1 friction only. Add theta2 friction later only if hardware
logs or model-vs-hardware comparisons show that it matters.

## Future Training Script Checklist

When it is time to update MATLAB training scripts and configs, add these
pieces deliberately:

- initialize fixed nominal values for `currentBias_A`,
  `currentNoiseStd_A`, `I_static_comp_A`, `G_diff_theta1`,
  `G_diff_theta2`, and `param.Friction.Theta1`,
- expose optional reset/config ranges for current sensor bias/noise,
  dead-zone compensation current, Coulomb/static friction, viscous damping,
  and smoothing velocity scales,
- extend `localResetFcnFurutaCurriculum` so it samples these values per
  episode only when the corresponding fields exist,
- call `setVariable` for any standalone Simulink variables used by blocks,
  and make sure `param.Friction.Theta1` is updated if the model reads friction
  through `param`,
- keep fixed evaluation deterministic unless an evaluation is explicitly meant
  to test randomized plant variants,
- log the sampled randomized values per episode or evaluation case once
  debugging needs it.

Candidate first randomization ranges, to refine after model-vs-hardware tests:

```text
IStaticCompRange_A       = [0.000, 0.030]
IStaticCompTightRange_A  = [0.010, 0.030]
Theta1CoulombCurrent_A   = [0.010, 0.030]
Theta1StaticCurrent_A    = [0.015, 0.035]
Theta1ViscousBRange      = [0.5, 2.0] * nominal_B
Theta1OmegaSRange_rad_s  = [0.05, 0.20]
Theta1OmegaEpsRange_rad_s = [0.005, 0.030]
```

Use the wider `IStaticCompRange_A` when robustness to missing or imperfect
compensation is the goal. Use the tighter range when the experiment should stay
near the observed hardware compensation value of `0.0205 A`.

## Param Fields To Consider Later

When the training scripts are updated for domain randomization, also consider
randomizing selected fields from the model `param` struct. Do this gradually:
start with the parameters most likely to explain hardware mismatch, then expand
only if evaluation shows the policy is still brittle.

Current nominal values to remember:

```matlab
param.R = 4.5320;
param.L = 0.0013;
param.km = 0.0975;
param.L0a = 0.1930;
param.L0b = 0.0190;
param.r0a = 0.0650;
param.r0b = 0.0045;
param.g = 9.8066;
param.r1 = 0.0045;
param.m1 = 0.1222;
param.L1 = 0.0855;
param.l1 = 0.0272;
param.J1zz = 1.1271e-05;
param.b1 = 1.0000e-06;
param.r2 = 0.0045;
param.m2 = 0.0280;
param.L2 = 0.1610;
param.l2 = 0.0805;
param.J2xx = 2.8350e-07;
param.J2yy = 6.0624e-05;
param.J2zz = 6.0624e-05;
param.b2 = 4.4000e-05;
param.i_max_setpoint = 4;
param.Friction = struct(...);
```

The model also uses encoder parameters for angle quantization:

```matlab
param.Encoder.Theta1.CountsPerRev = 4 * 4096;  % firmware: ENCODER_MOTOR_COUNTS_PER_TURN
param.Encoder.Theta2.CountsPerRev = 4 * 1024;  % firmware: ENCODER_PENDULUM_COUNTS_PER_TURN

param.Encoder.Theta1.ResolutionRad = 2*pi / param.Encoder.Theta1.CountsPerRev;
param.Encoder.Theta2.ResolutionRad = 2*pi / param.Encoder.Theta2.CountsPerRev;
```

Numerically, these are approximately:

```text
theta1 motor resolution    = 2*pi / (4*4096) = 0.0003835 rad/count
theta2 pendulum resolution = 2*pi / (4*1024) = 0.0015340 rad/count
```

Firmware behavior to mirror:

- `motor_angle` and `pendulum_angle` are unwrapped radians, not wrapped to
  `[-pi, pi]` or `[0, 2*pi]`,
- both are accumulated from encoder count deltas into a long counter,
- `pendulum_angle` is sign-inverted in firmware via `read_encoder_pendulum()`,
- both angles are zeroed relative to the encoder position at firmware reset or
  encoder reset,
- before UART/Simulink use, both encoder angle signals pass through a 680 Hz
  notch filter in the 20 kHz fast loop.

Therefore, do not wrap the measured sensor angle before filtering or
differentiation. If the RL observation needs a bounded pendulum error, wrap the
controller-facing error later:

```matlab
theta2Error = atan2(sin(theta2_meas_unwrapped - pi), ...
                    cos(theta2_meas_unwrapped - pi));
```

The firmware encoder notch is:

```matlab
Ts_fast = 50e-6;          % 20 kHz
f_notch_encoder_Hz = 680;
D_notch_encoder = 0.6;

s = zpk("s");
w_notch = 2*pi*f_notch_encoder_Hz;

G_encoder_notch = ...
    (s^2 + w_notch^2) / ...
    (s^2 + 2*D_notch_encoder*w_notch*s + w_notch^2);

G_encoder_notch_d = c2d(G_encoder_notch, Ts_fast, "tustin");
```

The hardware also has a separate current-setpoint low-pass filter:

```text
second-order current-setpoint low-pass:
  cutoff = 500 Hz
  damping = 0.9
  sample time = 50 us
```

This current filter is separate from the encoder-angle notch.

## Firmware Current Loop Details To Mirror

The uC current loop is not a plain ideal current source. When improving model
fidelity, mirror these pieces gradually.

Rate and communication behavior:

```text
SLDRT/RL current command rate: 500 Hz or 200 Hz
uC fast loop/current loop rate: 20 kHz
Ts_fast = 50e-6 s
```

The current command received by firmware should be modeled as:

```text
agent/SLDRT current command
  -> cast to single precision
  -> zero-order hold from communication rate to 20 kHz
  -> optional communication/measurement delay
  -> second-order current-setpoint low-pass
  -> PI current controller
```

A useful first delay model is one communication sample:

```text
500 Hz command path: about 2 ms
200 Hz command path: about 5 ms
```

Current-setpoint low-pass before PI:

```text
cutoff = 500 Hz
damping = 0.9
sample time = 50 us
```

Measured current conversion in firmware:

```matlab
current = (adc * 3.3 - 1.5) * -1.0 / (50 * 7e-3);
```

Current PI parameters:

```matlab
Ts_fast = 50e-6;
KP_I = 2.5;
TN_I = 0.0013 / 4.5320;
KI_I = KP_I / TN_I;
TAU_RO_I = 1 / (2*pi*3000);
```

Training-script preparation reminder: update or explicitly verify the PI
controller initialization against these uC firmware values before the next
hardware-fidelity training run.

The previous MATLAB initialization calculated closely related values via:

```matlab
Tn_i = param.L / param.R;
Kp_i = db2mag(CurrentControllerKpDb);  % default was 8 dB
Kp_i_over_Tn_i = Kp_i / Tn_i;
```

With the current nominal motor parameters, `db2mag(8)` gives approximately
`2.512`, very close to the uC value `KP_I = 2.5`. Keep this history in the docs
so future changes do not look like an unexplained retune.

Approximate numerical values:

```text
TN_I      approximately 0.0002869 s
KI_I      approximately 8714
KI_I*Ts   approximately 0.436 per fast-loop tick
TAU_RO_I  approximately 53 us
```

The PI error is:

```matlab
current_error = lowPass2CurrentSetpoint.apply(current_setpoint) - current;
```

The PI controller uses:

```text
backward-Euler integrator,
integrator clamp,
output clamp,
3 kHz output roll-off,
output limits approximately +-22 V.
```

Integrator/update shape:

```matlab
IPart = saturate(IPart + KI_I * Ts_fast * current_error, uIMin, uIMax);
u_raw = KP_I * current_error + IPart;
```

The output then passes through a first-order roll-off filter discretized with
Tustin and is saturated:

```matlab
uf = saturate(bf * (u_raw + u_old) - af * uf, uMin, uMax);
uMin = -22;
uMax =  22;
```

Important deviations from a simple textbook PI:

- current setpoint is low-pass filtered before PI,
- integrator is clamped to output limits,
- output is saturated,
- output has a 3 kHz roll-off filter,
- firmware can add voltage dead-zone compensation after the PI,
- PWM uses sign and absolute voltage,
- controller states reset whenever enable is false,
- firmware does not appear to clamp the incoming current command in amps.

Firmware voltage/PWM behavior when voltage dead-zone compensation is enabled:

```matlab
if u > 0
    dir = 0;
else
    dir = 1;
end

pwm = clamp((abs(u) + 2.0) / 24.0, 0.0, 1.0);
```

The `+2 V` offset is separate from the current-command compensation
`I_static_comp_A`. It acts after the PI controller in the voltage/PWM path and
means the actuator is not a perfectly linear voltage source.

Target model chain for the current path:

```text
current_cmd from agent
  -> single precision
  -> zero-order hold from SLDRT/RL rate to 20 kHz
  -> optional UART/measurement delay
  -> 500 Hz second-order low-pass
  -> subtract measured current
  -> PI with backward-Euler integrator
  -> integrator/output saturation at +-22 V
  -> 3 kHz output roll-off
  -> sign + abs + 2 V voltage offset
  -> PWM/voltage saturation using 24 V supply
  -> motor electrical dynamics
  -> torque
```

The measured/agent-facing velocity path should use the same differentiating
filter as the hardware-oriented controller path rather than ideal plant
velocity directly:

```matlab
% Differentiating filter
s = zpk("s");
Tf = 1 / (2*pi*100);
G_diff = c2d(s / (Tf*s + 1), Ts, "tustin");
```

If separate velocity filters are used for the motor and pendulum encoders,
initialize and assign them explicitly:

```matlab
fc_diff_theta1 = 100;  % Hz, initial hardware-style baseline
fc_diff_theta2 = 100;  % Hz, may be reduced if pendulum quantization ripple is too high

Tf_diff_theta1 = 1 / (2*pi*fc_diff_theta1);
Tf_diff_theta2 = 1 / (2*pi*fc_diff_theta2);

G_diff_theta1 = c2d(s / (Tf_diff_theta1*s + 1), Ts, "tustin");
G_diff_theta2 = c2d(s / (Tf_diff_theta2*s + 1), Ts, "tustin");
```

Future training scripts should assign `G_diff_theta1` and `G_diff_theta2` to
the workspace if the Simulink model uses separate differentiating filters.

Sensor-model structure:

```text
true theta
  -> encoder quantization using param.Encoder.*.ResolutionRad
  -> G_diff
  -> measured omega estimate for controller/agent observation
```

The physical plant dynamics should still use the true integrated `theta` and
`omega`; quantized angles and `G_diff` velocity estimates belong in the sensor
or controller-facing path.

Highest-priority randomization candidates:

- `param.km`: motor torque/current scaling mismatch,
- `param.b1`, `param.b2`: viscous damping mismatch,
- `param.Friction`: Coulomb/static friction and smoothing parameters,
- `param.i_max_setpoint`: effective current authority or command saturation.

Medium-priority candidates:

- `param.R`, `param.L`: current-loop/electrical dynamics if the model uses
  them explicitly,
- `param.Encoder.Theta1.CountsPerRev`,
  `param.Encoder.Theta2.CountsPerRev`: encoder quantization if hardware
  resolution or decoding mode is uncertain,
- `param.m1`, `param.m2`: mass uncertainty,
- `param.l1`, `param.l2`: center-of-mass uncertainty,
- `param.J1zz`, `param.J2xx`, `param.J2yy`, `param.J2zz`: inertia uncertainty.

Lower-priority or usually fixed:

- geometric radii/lengths such as `L0a`, `L0b`, `r0a`, `r0b`, `r1`, `r2`,
  unless measurements are uncertain,
- `param.g`, which should normally stay fixed.

Keep the first randomization ranges modest. A useful first pass is often around
`+-5%` to `+-10%` for measured physical parameters, with wider ranges reserved
for friction, damping, current scaling, and compensation terms.

## Randomization Scope Guidance

Do not randomize too many things at once in the first training runs. Domain
randomization makes the agent learn a family of plants instead of one nominal
plant. If the family is too wide or too messy, TD3 may train slower, become
overly conservative, jitter near upright, or fail to discover a clean swing-up
strategy.

Main risks of excessive randomization:

- training becomes harder because the critic must explain more dynamics,
- the policy may avoid useful aggressive swing-up actions,
- debugging becomes unclear because many causes change at once,
- independent sampling can create unrealistic parameter combinations,
- reward weights and action penalties may behave differently across variants.

Use a phased approach:

```text
Phase 1: high-impact actuator/plant mismatch
  theta1 friction, dead zone, current scaling

Phase 2: actuator path realism
  compensation current, delay/filter, current limit

Phase 3: sensing realism
  velocity filtering, encoder quantization, current noise

Phase 4: physical parameter uncertainty
  masses, inertias, center-of-mass locations, damping
```

Add randomization only when it corresponds to a known mismatch or plausible
uncertainty. After each phase, compare training success, fixed evaluation
failure rate, upright jitter metrics, and hardware-transfer behavior before
adding more randomization.
