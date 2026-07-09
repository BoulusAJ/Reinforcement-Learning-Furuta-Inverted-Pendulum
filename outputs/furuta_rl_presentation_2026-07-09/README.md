# Furuta RL Presentation Prep - 2026-07-09

Purpose: short presentation for the Furuta inverted pendulum RL work, demo,
lessons learned, repository handover, and future suggestions.

Use these files:

- `slide_bullet_points.md` - copyable slide text, without PowerPoint formatting.
- `speaker_notes.md` - what to say for each slide.
- `demo_and_handover_checklist.md` - what to showcase live and what to point to
  in the repository.
- `dos_donts_future_work.md` - compact lessons learned and next-step
  recommendations.

Recommended presentation length:

```text
10-15 min talk
3-5 min demo
5-10 min questions
```

Main story:

```text
The project started as an attempt to train an RL controller for a Furuta
inverted pendulum in simulation. The useful result is that a TD3 policy trained
on a simpler model transferred far enough to attempt swing-up on real hardware.
The remaining hard problem is robust, low-jitter capture and balance under
hardware-like actuator, sensor, friction, and current-loop dynamics.
```

Best files to open during the talk:

```text
docs/hardware_swingup_scaled_current_tests_2026-07-07.md
docs/detailed_model_training_results_2026-07-05.md
docs/weto_inputs_progress_2026-07-01.md
docs/domain_randomization_preparation.md
outputs/furuta_rl_presentation_2026-07-09/slide_bullet_points.md
```

Best plots to show:

```text
results/model_vs_hardware/comparisons/20260707_173214_selected_500hz_long_hardware_swing_ups/plots/overlay.png
results/model_vs_hardware/comparisons/20260707_173214_selected_500hz_long_hardware_swing_ups/plots/average.png
results/model_vs_hardware/comparisons/20260708_230429_hardware_scale1p0_lim3a_vs_detailed_sim_v1_closed_loop/plots/overlay.png
results/model_vs_hardware/comparisons/20260622_205659_test1_hardware_vs_model/plots/overlay.png
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long/training_progress.png
results/TD3/run_20260708_222715_td3_mathworks_style_pi_current_1c_500hz_long_detailed_scratch7000/training_progress.png
```

Best demo options:

```text
1. Show saved hardware swing-up runs and averaged overlay.
2. Show the Simulink SLDRT/current-command path if hardware is connected.
3. Show how a run is saved and compared using scripts/analysis.
4. Show repository structure and key docs for handover.
```
