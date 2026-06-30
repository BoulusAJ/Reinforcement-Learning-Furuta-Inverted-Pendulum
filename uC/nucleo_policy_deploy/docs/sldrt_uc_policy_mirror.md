# SLDRT uC Policy Mirror

Use `furutaUcPolicyMirrorStep` to compare three policy paths while running
SLDRT:

```text
1 MATLAB/Simulink Policy block action
2 MATLAB mirror of the Nucleo implementation, single precision
3 Nucleo-returned rl_policy_action over UART
```

## Network-Only Check

Before debugging packet inputs, speed filters, or the Nucleo, compare only the
exported actor network:

```matlab
[ucAction, actionError] = furutaUcActorForwardSingleObs(observation, ...
    matlabPolicyAction, ucW1, ucb1, ucW2, ucb2, ucW3, ucb3);
```

Feed `observation` with the exact same 7-element vector that goes into the
Simulink Policy block. This checks only:

```text
weights
layer order
ReLU/ReLU/tanh
single precision forward pass
```

It intentionally does not check theta sign conventions, speed filters,
previous-action generation, current scaling, or UART behavior.

Load the exported weights before opening/running the model:

```matlab
addpath(genpath("uC/nucleo_policy_deploy/matlab"))
loadFurutaUcPolicyMirrorParams
```

This puts plain numeric variables in the base workspace:

```text
ucW1, ucb1, ucW2, ucb2, ucW3, ucb3
ucActionScale, ucTsPolicy, ucCurrentLimit, ucCurrentOffset, ucFinalCurrentLimit
```

## MATLAB Function Block Call

Use a MATLAB Function block with inputs:

```text
packetInput
packetOutput
matlabPolicyAction
resetState
```

and parameters:

```text
ucW1, ucb1, ucW2, ucb2, ucW3, ucb3
ucActionScale, ucTsPolicy, ucCurrentLimit, ucCurrentOffset, ucFinalCurrentLimit
```

Call the codegen-friendly variant:

```matlab
[ucAction, ucCurrentCmd, actionError, ucObs, ucOmega] = ...
    furutaUcPolicyMirrorStepArrays(packetInput, packetOutput, ...
        matlabPolicyAction, resetState, ...
        ucW1, ucb1, ucW2, ucb2, ucW3, ucb3, ...
        ucActionScale, ucTsPolicy, ucCurrentLimit, ucCurrentOffset, ...
        ucFinalCurrentLimit);
```

`packetInput` should contain at least:

```text
1 raw theta1 from Packet Input
2 raw theta2 from Packet Input before the Simulink -1 gain
3 measured current
```

`packetOutput` should be:

```text
1 current_cmd sent to the Nucleo
2 enable sent to the Nucleo
```

The mirror intentionally follows the uC implementation:

```text
theta2 = -raw_theta2
theta2Error = 0 - atan2(sin(theta2 - pi), cos(theta2 - pi))
omega = c2d(s/(Tf*s + 1), Ts_policy, 'tustin') applied at Ts_policy
actor forward pass uses single precision weights and activations
current_raw = 4 A * action
current_limited_for_agent = clamp(current_raw, +/- ucCurrentLimit)
current_with_offset = current_limited_for_agent + 0.0205 A * sign(current_limited_for_agent)
current_cmd = clamp(current_with_offset, +/- ucFinalCurrentLimit)
```

This is the same current path used by the firmware:

```text
RL_POLICY_AGENT_CURRENT_LIMIT_A_DEFAULT = 0.5 A
RL_POLICY_FINAL_CURRENT_LIMIT_A_DEFAULT = 4.0 A
```

Compare:

```text
ucAction      vs Simulink Policy block normalized action
ucAction      vs Nucleo returned rl_policy_action
actionError   should approach zero if the MATLAB Policy block uses the same observation
ucCurrentCmd  vs Nucleo returned rl_policy_current_cmd
```
