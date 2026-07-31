# Weto Inputs Branch Archive

Branch: `dev/weto-inputs`

This was the primary experiment and results branch for applying the suggestions
from the June 24 project meeting with Thomas Weinmann (ZHAW). Its purpose was to
test smaller TD3 networks and alternate observations in controlled runs, then
evaluate whether greater plant and signal-chain fidelity improved transfer and
training. It also became the working branch for hardware comparisons and the
July 9 project presentation.

Some preparatory work was deliberately developed on `dev/weto-inputs-side` to
avoid conflicts with runs and unpushed state on another PC. That branch was
merged here on July 3 in commit `a56a612`. The final branch therefore contains
both the side branch's preparation files and the experiments performed directly
on `dev/weto-inputs`; the chronology below distinguishes them.

## Chronology

### Before the Weinmann input

The successful baseline already existed before the detailed-model work:

```text
run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

This is the combined TD3 swing-up-and-balance agent later demonstrated in the
July 9 presentation and deployed on the Nucleo branch. It was trained at 500 Hz
on the simpler analytical `1b` plant.

The `_2` model family is also from the earlier work. It uses voltage as the
agent command and therefore has no PI current controller in the agent action
path. It produced a good policy in the simpler simulation, but that policy was
not validated on hardware or on the later detailed plant.

### Thomas Weinmann's input

The suggestions were treated as controlled experiments, changing one main
factor at a time:

1. Reduce actor and critic size.
2. Try a smaller observation representation.
3. Improve reward structure, including state-dependent penalties near upright.
4. Improve actuator and sensor fidelity, then consider parameter/domain
   randomization.
5. Consider additional actuator state such as measured current or saturated
   voltage where the original observation hides important dynamics.

### Work prepared on `dev/weto-inputs-side`

The side branch prepared the initial 1x64 training configurations and the first
detailed-model path without modifying active work elsewhere. It contributed:

- 200 Hz and 500 Hz 1x64 TD3 training setups and comparison criteria;
- uncontrolled-current noise analysis and reference measurements;
- the initial detailed `1c` analytical, training, analysis, and comparison
  models;
- encoder, filter, friction, current-loop, and domain-randomization notes;
- ramp-consistent velocity-filter initialization;
- the result-comparison helper and the `5011` detailed-training handoff.

These were preparation and handoff artifacts. The completed experiment results
and conclusions were produced on the main `dev/weto-inputs` line after the merge.

See branch `dev/weto-inputs-side` and
[`docs/weto_input_side_workflow.md`](docs/weto_input_side_workflow.md).

### Work performed on `dev/weto-inputs`

The early network experiments showed that a one-layer 64-unit actor could learn
the task if the critics remained stronger. A one-layer 64-unit critic was too
small. The 1x64 actor / 2x64 critic policy was viable but more oscillatory and
not better overall than `500Hz_long`.

The pure unsigned arc-distance observation experiment also failed. Removing
angle direction, especially for the arm angle, made centering and limit
avoidance much harder. The main branch collected these run results, continued
the detailed `1c` scratch and fine-tuning experiments, added the `1d`
measured-current and scaled-velocity variants, and recorded hardware swing-up
comparisons.

### Detailed plant and July 9 preparation

After the meeting, the side branch prepared much of the first detailed model;
after it was merged, `dev/weto-inputs` used and extended that model to test existing
and newly trained agents. This improved evaluation realism and exposed likely
sim-to-real issues, but training on the detailed plant did not produce a
successful swing-up-and-balance agent.

From-scratch policies often learned to keep swinging without capturing upright.
Fine-tuning the working `500Hz_long` policy could quickly destroy its initially
useful behavior. Adding measured current did not produce a successful policy in
the tested setup. These results contributed to leaving the single-policy
swing-up-and-balance direction and moving toward RL swing-up followed by an LQR
balancing controller after the July 9 presentation.

This branch was also used to prepare the July 9 presentation. It therefore
contains presentation artifacts, result snapshots, and working Simulink files
that were not cleaned into a release structure.

## Simulink Model Families

### `*_1b*`

The `1b` files are the simpler current-command models used for the successful
`500Hz_long` agent. Their action path contains:

```text
current command -> PI current controller -> DC motor -> torque -> Furuta plant
```

Both analytical and Simscape mechanical plants are present. The analytical
plant was active for training and matched the Simscape behavior closely for the
tested setup. It used the earlier equations and did not yet include the later
friction and sensor/actuator details.

### `*_1c*`

The `1c` files contain the detailed plant and updated analytical equations. The
added signal-chain details include:

- current noise,
- PI current controller,
- discrete second-order current-command low-pass filter `G_i_cmd_lpf_d`,
- encoder quantization,
- encoder notch filter `G_encoder_notch_d_ss`,
- state-space velocity filters `G_diff_theta1_ss` and `G_diff_theta2_ss`,
- filter-state initialization compatible with the reset function,
- rate-transition blocks,
- static-friction compensation.

The standard `1c` observation vector has seven elements and uses the previous
action. Its omega observations are not scaled and clipped.

These models were useful for evaluating how existing policies might behave on a
more realistic plant. They made training substantially harder, and the tested
scratch and fine-tuning runs did not learn reliable capture and balance.

### `*_1d*`

The `1d` files extend `1c` with an eighth observation, measured current
`i_meas`. They also scale and clip both angular-velocity observations. The
tested `1d` runs did not produce a usable policy, although this does not by
itself prove that measured current is an unhelpful observation.

### `*_1c_alt*`

The alternate `1c` files use the reduced observation vector:

```text
theta1_arc_norm = acos(cos(theta1_error)) / pi
theta2_arc_norm = acos(cos(theta2_error)) / pi
omega1_scaled_norm = clip(omega1_error / AngularVelocityScale, -1, 1)
omega2_scaled_norm = clip(omega2_error / AngularVelocityScale, -1, 1)
u
```

The `u` channel comes from the existing error/previous-action signal path. These
models use `rewardFcnFurutaArcObs`. The unsigned angle distances discard side
information; the resulting run was unsuccessful and should not be continued in
that form.

### `*_2*`

The `_2` files predate the Weinmann-input work. They use a voltage-commanded
plant without the PI current controller. This path produced a good result in the
simple simulation but was not tested on hardware or the detailed model.

## What Worked

- The pre-existing `1b` `500Hz_long` agent solved combined swing-up and balance
  on the simpler model and was later demonstrated on hardware.
- A smaller 1x64 actor remained viable when paired with 2x64 critics.
- The detailed 1c/1d models improved evaluation realism and made actuator,
  friction, filtering, observation, and timing mismatches visible.
- The model-vs-hardware scripts and hardware-current scaling tests produced
  useful transfer evidence.
- The work established that policy-preserving adaptation matters: unrestricted
  TD3 fine-tuning can damage a working controller.

## What Did Not Work

- A symmetric 1x64 actor/critic setup was too weak in the tested run.
- The unsigned arc observation removed too much directional information.
- Detailed 1c training did not learn reliable upright capture and balance.
- Fine-tuning `500Hz_long` on the detailed model was unstable and could collapse.
- The tested 1d measured-current runs failed their fixed evaluations.
- Increasing model complexity did not make training more successful within the
  available project time.

## Detailed Notes

- [Weto inputs progress](docs/weto_inputs_progress_2026-07-01.md)
- [1x64 network experiments](docs/weto_1x64_training_experiment_2026-06-26.md)
- [Detailed-model training results](docs/detailed_model_training_results_2026-07-05.md)
- [Domain-randomization and model-fidelity preparation](docs/domain_randomization_preparation.md)
- [Hardware swing-up current-scaling tests](docs/hardware_swingup_scaled_current_tests_2026-07-07.md)
- [Weto side workflow](docs/weto_input_side_workflow.md)
- [5011 training handoff](docs/5011_training_handoff.md)
- [July 9 presentation folder](outputs/furuta_rl_presentation_2026-07-09/)

## Archive Decision

Archive this branch after this README is pushed. Do not spend handover time
cleaning every Simulink or result file in place. For the final repository,
selectively retain:

- the `500Hz_long` baseline and its provenance,
- the model-family explanation above,
- detailed-model and model-vs-hardware conclusions,
- relevant evaluation scripts,
- the July 9 presentation and concise supporting evidence.

Archive `dev/weto-inputs-side` separately as the provenance of the preparation
work, but do not import it again: its useful commits were already merged here.

The later MATLAB analytical swing-up plus LQR work is maintained on
`dev/swing-up`. The embedded deployment pipeline is maintained on
`dev/nucleo-policy-deploy`.
