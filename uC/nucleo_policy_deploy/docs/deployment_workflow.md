# Deployment Workflow

This workflow turns a trained MATLAB TD3 final-agent file into a small C++
actor implementation for the Nucleo firmware.

## 1. Export Actor Weights

Run from the repository root:

```matlab
run("uC/nucleo_policy_deploy/matlab/example_export_policy_for_nucleo.m")
```

This loads:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long/FurutaTD3_mathworks_style_pi_current_1b_500hz_long_final.mat
```

and writes:

```text
uC/nucleo_policy_deploy/lib/RLPolicy/rl_policy_weights.h
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long/actor_export_nucleo.mat
```

The generated header contains:

```text
W1, b1
W2, b2
W3, b3
ACTION_CURRENT_SCALE_A
POLICY_SAMPLE_TIME_S
```

## 2. Verify MATLAB Raw Forward Pass

The export script also calls:

```matlab
verifyFurutaActorExport(...)
```

This compares:

```text
getAction(getActor(agent), observation)
```

against:

```text
furutaActorForwardRaw(observation, exportedWeights)
```

Do not continue to firmware until the max error is small, ideally around
`1e-6` to `1e-5`.

If the check fails, likely causes are:

- learnable parameter order mismatch,
- weight matrix transposition,
- hidden size not actually `64`,
- unexpected final scaling layer.

For SLDRT shadow debugging, see `docs/sldrt_uc_policy_mirror.md`. It provides
a MATLAB function that mirrors the Nucleo single-precision policy path from
Packet Input/Packet Output signals.

## 3. Firmware Integration

The C++ pieces are:

```text
lib/RLPolicy/
lib/RLPolicyThread/
lib/realtime_thread/
src/main.cpp
include/rl_policy_config.h
```

For a real build, copy or merge these pieces into the `drehpendel` firmware
repository, which already contains:

```text
IO_handler
fast_realtime_thread
ThreadFlag
SerialPipe
Eigen
PlatformIO/mbed setup
```

The `lib/realtime_thread` files are deliberately based on the existing
`drehpendel/lib/realtime_thread` names and loop structure. The non-RL parts
should remain as close as practical to the original firmware; the policy thread,
shadow-mode current selection, and optional UART return fields are the intended
differences.

## 4. Current-Command Fallback

To compile without the RL controller and behave like the original drehpendel
current-command firmware, set:

```cpp
#define RL_POLICY_CONTROLLER_ENABLE 0
```

In this mode:

```text
host/SLDRT current_cmd drives the current loop
enable input still enables/disables the motor
RLPolicyThread is not compiled or started
rl_policy_weights.h is not included
UART response stays at the original 3 floats / 12 bytes
```

Use this when you want to flash the prototype tree but test the same behavior
as the base drehpendel program.

## 5. Shadow Mode First

Start with:

```cpp
#define RL_POLICY_CONTROLLER_ENABLE 1
#define RL_POLICY_SHADOW_MODE_DEFAULT 1
#define RL_POLICY_UART_EXTENDED_RESPONSE 1
#define RL_POLICY_EVALUATE_WHEN_DISABLED 1
```

In this mode:

```text
host/SLDRT current command still drives the current loop
enable input still enables/disables the motor
Nucleo computes policy_action and policy_current_cmd
Nucleo returns policy_action and policy_current_cmd over UART
```

With `RL_POLICY_EVALUATE_WHEN_DISABLED = 1`, the Nucleo still evaluates the
NN when `enable = 0`. This is useful for moving the pendulum by hand and
comparing the onboard policy output against MATLAB/Simulink. The motor current
path still remains disabled while `enable = 0`.

Compare the Nucleo policy output against:

- the Simulink generated Policy block,
- the MATLAB raw forward function,
- logged observations.

Only switch away from shadow mode after this comparison is boringly close.

## 6. Onboard Policy Control

After shadow-mode verification:

```cpp
#define RL_POLICY_CONTROLLER_ENABLE 1
#define RL_POLICY_SHADOW_MODE_DEFAULT 0
```

Then the firmware applies:

```text
policy_current_raw = 4 A * policy_action
policy_current_limited_for_agent = clamp(policy_current_raw, +/- agent_current_limit)
policy_current_with_offset = policy_current_limited_for_agent + 0.0205 A * sign(policy_current_limited_for_agent)
policy_current_cmd = clamp(policy_current_with_offset, +/- final_current_limit)
```

The UART input packet remains unchanged in this mode:

```text
current_cmd is still received but is not applied to the current loop
enable input still enables/disables the motor
```

The `0.0205 A * sign(...)` offset mirrors the Simulink current-command path.
It can be disabled with:

```cpp
#define RL_POLICY_CURRENT_OFFSET_ENABLE 0
```

Use a conservative current limit first:

```cpp
#define RL_POLICY_AGENT_CURRENT_LIMIT_A_DEFAULT 0.2f
```

then increase carefully if behavior is correct.

## 7. Observation Convention To Verify

The actor expects:

```text
1 sin(theta1Error)
2 cos(theta1Error)
3 sin(theta2Error)
4 cos(theta2Error)
5 omega1Error
6 omega2Error
7 previousAction
```

The prototype code currently uses:

```cpp
theta1Error = -theta1;
theta2 = -raw_pendulum_angle;
theta2Error = 0 - wrapToPi(theta2 - pi);
omega1 = G_diff(theta1);
omega2 = G_diff(theta2);
omega1Error = 0 - omega1;
omega2Error = 0 - omega2;
previousAction = previous normalized policy action;
```

where `G_diff` is implemented in the Nucleo policy thread with the existing
`IIRFilter` library using the same first-order differentiating low-pass shape:

```text
G_diff = c2d(s / (Tf*s + 1), Ts_policy, 'tustin')
Tf = 1 / (2*pi*100)
```

These signs must be checked against the SLDRT/Simulink observation signals
before using onboard policy control.

## 8. Velocity Estimation Caveat

The existing firmware measures angles and current. It does not currently expose
or maintain filtered velocities for the RL policy.

The prototype UART adapter estimates velocities by finite difference at the
UART service rate. This is acceptable for a first shadow-mode comparison but
should be replaced by a better filtered velocity estimate before serious
onboard policy control.

## 9. Critic Networks

The TD3 critics are not deployed. They are only used during training. The
microcontroller only needs the actor:

```text
observation -> actor -> action
```

## 10. Timing Note

During the first successful onboard RL test on 2026-06-30, the Nucleo
`rl_policy_current_cmd` and the Simulink-side command matched in shape, but the
scope comparison aligned best when the Simulink signal was delayed by about two
agent samples:

```text
2 * 0.002 s = 4 ms
```

Likely contributors are the UART request/response timing and the separate
`realtime_thread` / `RLPolicyThread` scheduling. This was documented rather than
optimized immediately because onboard swing-up and balance worked.
