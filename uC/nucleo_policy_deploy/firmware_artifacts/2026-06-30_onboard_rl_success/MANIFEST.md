# 2026-06-30 Onboard RL Success

Milestone firmware from the successful Nucleo policy demonstrator.

## Source

Built in the worktree that became branch `dev/nucleo-policy-deploy`. Commit
`8b711dd` contains this manifest and the archived deployment source.

## Test Notes

- Onboard RL policy ran on the Nucleo with shadow mode disabled.
- Swing-up and upright balance worked.
- MATLAB/Simulink network-only check matched the Simulink Policy block with max
  error around `14e-7`.
- `furutaUcPolicyMirrorStepArrays` matched Simulink observation/action/omega
  behavior closely; `ucCurrentCmd` controlled swing-up and balance from SLDRT.
- Nucleo `rl_policy_current_cmd` matched the Simulink-side command after adding
  about two agent-sample delay compensation in the scope comparison.
- The deployed agent was the older combined swing-up-and-balance TD3 policy.
- Its action used a 4 A scale, while this firmware limited the policy command to
  0.5 A before the current offset. The supply was limited to about 1.5-2 A; the
  final 4 A software clamp was a separate last-resort bound.
- The 0.5 A clamp reduced balancing oscillation attributed to static friction
  omitted from training. Swing-up still worked, with more back-and-forth swings.

## Important Config

```cpp
#define RL_POLICY_CONTROLLER_ENABLE 1
#define RL_POLICY_SHADOW_MODE_DEFAULT 0
#define RL_POLICY_DEFAULT_RATE_HZ 500.0f
#define RL_POLICY_AGENT_CURRENT_LIMIT_A_DEFAULT 0.5f
#define RL_POLICY_FINAL_CURRENT_LIMIT_A_DEFAULT 4.0f
#define RL_POLICY_CURRENT_OFFSET_ENABLE 1
#define RL_POLICY_CURRENT_OFFSET_A 0.0205f
#define RL_POLICY_UART_EXTENDED_RESPONSE 0
#define RL_POLICY_UART_THIRD_FLOAT_MODE RL_POLICY_UART_THIRD_FLOAT_POLICY_CURRENT_CMD
```

## Artifacts

```text
firmware.bin  101,968 bytes
firmware.elf  2,708,580 bytes
```

SHA256:

```text
firmware.bin  25353430bbeddeeac24ad4994697465a28541194967e046abdd1b533cf38a1e4
firmware.elf  195f98d0a32afcc99e531d52b27d70732d40f57d9b4cb5e13657281330ddefaa
```
