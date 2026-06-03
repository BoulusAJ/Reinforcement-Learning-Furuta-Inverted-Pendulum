# ZHAW Rotary Pendulum Lab References

This folder contains external reference material copied from the ZHAW rotary pendulum lab/course folders. Keep these files as reference inputs. Project-specific RL code, adapted models, and derived scripts should live in the top-level `scripts/`, `models/`, `hardware/`, `data/`, and `results/` folders.

## Folder Layout

| Folder | Original source | Purpose |
|---|---|---|
| `lab_model/` | `inv_rot_pen` | Furuta inverted rotary pendulum model files, analytical dynamics, linearization, Simulink models, measured swing data, and literature notes. |
| `course_lab_p5/` | `P5_RotaryPendulum` | Course lab material for the rotary pendulum, including lab PDFs, figures, MATLAB examples, SLDRT models, and controller-design scripts. |

## Key Files To Study First

| File | Why it matters |
|---|---|
| `lab_model/get_parameter.m` | Physical and motor parameters for the Furuta setup. |
| `lab_model/calculate_dynamics_furuta.m` | Nonlinear mechanical dynamics in mass/Coriolis/gravity/damping form. |
| `lab_model/linearize_furuta_equilibrium.m` | Linearization around down/upright equilibria for baseline controller design. |
| `lab_model/inv_rot_pen_ini.m` | Analytical vs Simscape model comparison and LQR setup. |
| `course_lab_p5/Matlab/rotary_pendulum_ini_corrected.m` | Course-lab controller design, hardware limits, current loop, speed loop, angle controller, and practical notes. |

## Initial Extracted Facts

- Motor resistance: `R = 4.12 * 1.1 Ohm`.
- Motor inductance: `L = 1.31e-3 H`.
- Motor torque constant: `km = 97.5e-3 Nm/A`.
- Sample/PWM frequency in course material: `fs = 20e3 Hz`.
- Course safety limits include `u_max = 24 V`, `i_max = 1 A`, `om_max = 200 rad/s`, and `phi2_max = 30 deg`.
- Pendulum encoder note: 1024 increments, positive sign for positive rotation.
- Angle wrapping note: use `atan2(sin(phi2), cos(phi2))`.

## Use In This RL Project

Use these references to fill in:

- plant parameters in `scripts/makeFurutaConfig.m`,
- baseline LQR/PID controller design,
- simulation model selection in `models/`,
- hardware enable/disable ranges and safety fallback,
- observation/action conventions for RL training.
