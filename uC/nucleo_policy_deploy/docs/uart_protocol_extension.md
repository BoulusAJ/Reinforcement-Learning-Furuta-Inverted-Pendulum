# UART Protocol Extension For Policy Shadow Testing

The current `drehpendel` firmware protocol is:

## Host To Nucleo

```text
current_cmd: float32, 4 bytes
enable:      uint8,   1 byte
```

Total: `5` bytes.

## Nucleo To Host: Compact 3-Float Response

```text
motor_angle:          float32
pendulum_angle:       float32
selected_third_float: float32
```

Total: `12` bytes.

The third float is selected at compile time:

```cpp
#define RL_POLICY_UART_EXTENDED_RESPONSE 0

#define RL_POLICY_UART_THIRD_FLOAT_MEASURED_CURRENT 0
#define RL_POLICY_UART_THIRD_FLOAT_POLICY_ACTION 1
#define RL_POLICY_UART_THIRD_FLOAT_POLICY_CURRENT_CMD 2
#define RL_POLICY_UART_THIRD_FLOAT_MODE RL_POLICY_UART_THIRD_FLOAT_POLICY_CURRENT_CMD
```

Modes:

```text
MEASURED_CURRENT:
  original drehpendel behavior

POLICY_ACTION:
  third float is normalized rl_policy_action in [-1, 1]

POLICY_CURRENT_CMD:
  third float is rl_policy_current_cmd, matching the value applied by the
  realtime thread in shadow-off mode
```

## Nucleo To Host: Extended Shadow Response

This response is compiled only when both flags are enabled:

```cpp
#define RL_POLICY_CONTROLLER_ENABLE 1
#define RL_POLICY_UART_EXTENDED_RESPONSE 1
```

If `RL_POLICY_CONTROLLER_ENABLE` is `0`, the firmware uses the original
3-float response even if `RL_POLICY_UART_EXTENDED_RESPONSE` is left at `1`.

The policy demonstrator adds:

```text
policy_action:      float32  normalized action in [-1, 1]
policy_current_cmd: float32  policy current command after action scale and clamp
```

Extended response:

```text
motor_angle:        float32
pendulum_angle:     float32
current:            float32
policy_action:      float32
policy_current_cmd: float32
```

Total: `20` bytes.

## Simulink Packet Input Settings

For extended shadow comparison, update Packet Input to expect:

```text
5 singles
20 bytes
little endian
no packet identifier
```

Signal order:

```text
1 motor_angle
2 pendulum_angle
3 measured_current
4 policy_action
5 policy_current_cmd
```

For compact 3-float comparison at the original packet size, keep Packet Input
as:

```text
3 singles
12 bytes
little endian
no packet identifier
```

Signal order:

```text
1 motor_angle
2 pendulum_angle
3 selected_third_float
```

If `RL_POLICY_UART_THIRD_FLOAT_MODE` is set to
`RL_POLICY_UART_THIRD_FLOAT_POLICY_CURRENT_CMD`, compare signal 3 directly
against the MATLAB mirror `ucCurrentCmd`.

Keep Packet Output unchanged:

```text
single current_cmd
uint8 enable
5 bytes total
```

This input packet is the same in all compile modes:

```text
RL_POLICY_CONTROLLER_ENABLE = 0:
  current_cmd drives the current loop
  enable enables/disables the motor

RL_POLICY_CONTROLLER_ENABLE = 1 and RL_POLICY_SHADOW_MODE_DEFAULT = 1:
  current_cmd still drives the current loop
  enable enables/disables the motor
  policy output is returned only for comparison
  if RL_POLICY_EVALUATE_WHEN_DISABLED = 1, policy output is still computed when enable = 0

RL_POLICY_CONTROLLER_ENABLE = 1 and RL_POLICY_SHADOW_MODE_DEFAULT = 0:
  current_cmd is received but ignored for motor current
  policy_current_cmd drives the current loop
  enable enables/disables the motor
```

## Why Shadow Mode

In shadow mode, the host still drives `current_cmd`, but the Nucleo computes
the policy output from its onboard implementation. This lets you compare:

```text
Simulink Policy block action
MATLAB raw forward action
Nucleo Eigen/plain-C action
```

before allowing the onboard policy to command current.
