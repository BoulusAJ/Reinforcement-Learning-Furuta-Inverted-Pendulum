# Branch status

Branch: `dev/nucleo-policy-deploy`

## Result

This branch produced a working Nucleo F446RE demonstrator. On 2026-06-30 the
TD3 actor ran onboard at 500 Hz and controlled both swing-up and upright
balance. MATLAB/Simulink and Nucleo policy outputs matched closely. Scope traces
aligned best with about two policy samples (4 ms) of delay compensation.

The deployed agent is the older combined swing-up-and-balance policy from
`run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long`. Its
normalized action is scaled by 4 A. The successful firmware configuration
limited the policy command to 0.5 A before adding the 0.0205 A offset. The power
supply was limited to about 1.5-2 A, while the final 4 A software clamp was only
a separate last-resort bound.

The 0.5 A clamp was introduced to reduce aggressive full-range current
oscillation during balancing. The behavior was attributed to static friction
that was not modeled during training. Swing-up still succeeded at 0.5 A, but it
usually needed more back-and-forth swings.

## Still open

- Rebuild the archived source with a documented PlatformIO/mbed toolchain.
- Recheck observation signs and filtering when exporting a different agent.
- Measure and explain the observed 4 ms timing offset.
- Repeat safety validation before using a new policy on hardware.

## Keep for main

- MATLAB actor export and forward-pass verification.
- C++ actor inference and generated-weight format.
- MATLAB mirror used to compare Nucleo and Simulink behavior.
- Shadow mode, current-command fallback, and UART diagnostics.
- Policy-thread timing and safety-clamp structure.
- The successful firmware manifest and its verified hashes.

This branch should be archived after final documentation. The uC pipeline should
later be copied selectively into `main`; the complete historical branch should
not be merged wholesale.
