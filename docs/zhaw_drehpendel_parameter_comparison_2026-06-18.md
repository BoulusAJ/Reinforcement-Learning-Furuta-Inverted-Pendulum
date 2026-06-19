# ZHAW `drehpendel` Firmware vs Current RL Model Parameters

Date: 2026-06-18

## Reference Added

The ZHAW firmware repository was added as a git submodule:

- Path: `references/drehpendel`
- URL: `https://github.com/altb71/drehpendel.git`
- Branch: `com_via_slk_platform_io`
- Checked commit: `53c2173`

`.gitmodules` pins the submodule to the `com_via_slk_platform_io` branch.

## Current Project Parameter Source

The current RL project still uses the copied ZHAW MATLAB reference model:

- Central config: `scripts/makeFurutaConfig.m`
- Workspace initialization: `scripts/initFurutaModelWorkspace.m`
- Physical parameters: `references/zhaw_rotary_pendulum_lab/lab_model/get_parameter.m`

The core mechanical parameters are:

| Parameter | Current RL value | Source |
| --- | ---: | --- |
| Motor resistance `R` | `4.12 * 1.1 = 4.532 Ohm` | `get_parameter.m` |
| Motor inductance `L` | `1.31e-3 H` | `get_parameter.m` |
| Torque constant `km` | `97.5e-3 Nm/A` | `get_parameter.m` |
| Gravity `g` | `9.80665 m/s^2` | `get_parameter.m` |
| Rotary arm mass `m1` | `0.1222 kg` | `get_parameter.m` |
| Rotary arm COM `l1` | `0.027248 m` | `get_parameter.m` |
| Rotary arm joint-to-pendulum `L1` | `0.0855 m` | `get_parameter.m` |
| Rotary inertia `J1zz` | `1.127084e-5 kg*m^2` | `get_parameter.m` |
| Pendulum mass `m2` | `0.028 kg` | `get_parameter.m` |
| Pendulum length `L2` | `0.161 m` | `get_parameter.m` |
| Pendulum COM `l2` | `0.0805 m` | `get_parameter.m` |
| Pendulum inertia `J2xx` | `2.835e-7 kg*m^2` | `get_parameter.m` |
| Pendulum inertia `J2yy/J2zz` | about `6.061e-5 kg*m^2` | `get_parameter.m` |
| Arm damping `b1` | `1e-6` | `get_parameter.m` |
| Pendulum damping `b2` | `4.4e-5` | `get_parameter.m` |

## New Firmware Interface Parameters

The new firmware does not redefine the rigid-body Furuta geometry. It mainly defines the real embedded interface:

| Parameter | Firmware value | Current RL/sim value | Difference |
| --- | ---: | ---: | --- |
| Host/control communication period | `Ts = 200e-6 s` / `5 kHz` | Agent normally `5e-3 s` / `200 Hz`; special PI/current config `2e-3 s` / `500 Hz` | Hardware command loop is much faster than our RL policy rate. Host adapter must hold/interpolate RL current commands. |
| Inner current/PWM loop period | `Ts_fast = 50e-6 s` / `20 kHz` | Plant sample `1/20e3 = 50e-6 s` | Matches plant/PWM simulation step. |
| PWM period | `50 us` / `20 kHz` | `50 us` plant sample | Matches. |
| Supply voltage | `24 V` | `cfg.Limits.VoltageMax = 24 V` | Matches. |
| Dead-zone/offset voltage | `2.0 V` | `pwm_offset = 0.09`, so effective offset `2.16 V` | Close, but not identical. |
| Current PI proportional gain | `KP_I = 2.5` | default `db2mag(8) = 2.512`; course script `db2mag(12) = 3.981` | Current project default matches firmware closely, not the older corrected course script. |
| Current PI time constant | `TN_I = 0.0013 / 4.5320 = 2.87e-4 s` | `1.31e-3 / (4.12*1.1) = 2.89e-4 s` | Matches within rounding. |
| Current PI integral gain | `KI_I = KP_I / TN_I`, about `8714` | `Kp_i_over_Tn_i`, about `8689` with default 8 dB | Close. |
| Current controller rolloff | `1/(2*pi*3000)` | Not explicitly mirrored in `initFurutaModelWorkspace.m` | Possible actuator-bandwidth mismatch. |
| Current command filtering | 2nd order low-pass at `500 Hz`, damping `0.9` | Not explicitly in current workspace init | Important if RL learns sharp current changes. |
| Encoder notch | `680 Hz`, damping `0.6` | `680 Hz`, damping `0.1` | Same center frequency, different damping. |
| Motor encoder | `4*4096 = 16384 counts/rev` | Not explicit in RL config | Needed for hardware observation quantization/noise. |
| Pendulum encoder | `4*1024 = 4096 counts/rev` | Course comments mention 1024 increments; RL model continuous | Needed for hardware observation quantization/noise. |
| Pendulum encoder sign | firmware returns `-angle` | RL observation uses custom theta2 error convention | Must verify sign convention before deploying. |
| Current measurement | `(ADC*3.3 - 1.5) * -1/(50*7e-3)` A | Sim current is ideal/model signal | Hardware has offset, sign, and gain calibration. |
| Command protocol | host sends one float current command plus one enable byte; firmware returns motor angle, pendulum angle, current as three floats | Sim agent action is normalized and mapped to torque/current/voltage internally | Deployment wrapper must map normalized action to current command and handle enable/watchdog. |
| Watchdog | `0.3 s` communication timeout disables motor | Sim has no serial watchdog | Deployment must send packets continuously even when action is held. |

## Main Takeaways

1. Mechanical parameters appear consistent with the current ZHAW model. I did not find a separate mass/length/inertia model in the firmware branch; the branch is an embedded current-control and IO layer.

2. The action interface should be treated as a current-command interface, not a voltage-command interface. The firmware expects a current setpoint from the host and closes the current loop internally at 20 kHz.

3. The current RL config allows `CurrentMax = 4 A`, while the older course hardware script documented `i_max = 1 A` as a safe current limit. The firmware itself does not clamp the host current command before the PI controller. For lab deployment, add a conservative host-side current clamp until the safe value is confirmed on the physical setup.

4. The newest firmware current controller is very close to `initFurutaModelWorkspace(..., CurrentControllerKpDb=8)`, not the older `rotary_pendulum_ini_corrected.m` value of 12 dB.

5. Before applying RL on the lab agent, the sim should include or at least account for: held lower-rate RL actions, firmware-side current low-pass filtering, encoder quantization/signs, current sensor scaling/sign, the 0.3 s watchdog, and a physical enable/safety gate.

