# Direct TD3 Swing-Up Branch Archive

Branch: `direct-td3-swingup`

This branch records the transition from the earlier upright-stabilization/DDPG
work to direct TD3 swing-up and balance. Its main result was a successful
simulation-trained controller and the first useful hardware-transfer evidence.
Later model-fidelity and robustness work continued on `weto-inputs`.

## Main result

The strongest controller from this branch was:

```text
run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

The agent learned combined swing-up and upright balance on the simpler
analytical current-command model at 500 Hz. It later became the July 9
demonstration policy and the policy deployed by `dev/nucleo-policy-deploy`.

Hardware tests showed that the learned behavior transferred far enough to
attempt and later complete swing-up, but balancing exposed current chatter,
static-friction mismatch, action limiting, and timing/model-fidelity issues.

## Why the TD3 setup improved

The branch followed the structure of the MathWorks TD3 Quanser QUBE examples
more closely than the earlier training setup. Important changes included:

- TD3 twin critics and delayed actor updates,
- episode-end learning bursts,
- larger replay buffer and mini-batches,
- explicit warm-start behavior,
- separate training and deterministic fixed-case evaluation,
- configuration-based run folders and saved evaluation metadata.

This did not prove that one option alone caused success. The important result
was that the example-aligned agent, observation, reward, reset, and evaluation
setup trained much more reliably than the earlier DDPG/local-stabilization path.

## Observation vector

The direct TD3 policy uses seven observations:

```text
sin(theta1Error)
cos(theta1Error)
sin(theta2Error)
cos(theta2Error)
omega1Error
omega2Error
previousAction
```

The sine/cosine representation avoids presenting the angle-wrap discontinuity
directly to the network. `previousAction` is the previous normalized agent
action `u[k-1]`, not the previous current command after scaling and limiting.
Including it gives the policy information about its recent command and improves
the Markov representation of the sampled system with held actions, filtering,
and actuator dynamics. It is also required by the action-change reward term.

Raw arm position still has to be used for travel-limit safety because sin/cos
features alone cannot distinguish multiple turns.

## Model and command paths

### `*_1b*`

The successful `500Hz_long` policy was trained with the `1b` family. Its action
path is:

```text
normalized action -> current command -> PI controller -> DC motor -> torque
```

The training model used the simpler analytical Furuta plant. A Simscape plant
was available for comparison. This model predates the later detailed friction,
quantization, filtering, and communication additions.

### `*_2*`

The `_2` experiments used voltage as the agent command and removed the PI
current controller from the action path. This approach also produced a good
simulation result, but it was not validated on hardware or on the later
detailed plant.

## Work completed on this branch

- Documented why the earlier DDPG approach was paused and why TD3 was selected.
- Reproduced and studied the MathWorks QUBE TD3 reference workflow.
- Added the direct swing-up observation, reward, reset, training, and evaluation
  infrastructure.
- Trained and compared 200 Hz, 500 Hz, current-command, and voltage-command
  policies.
- Added fixed-case and broad-grid evaluation with actuator and safety metrics.
- Compared analytical and Simscape plant behavior.
- Added initial model-vs-hardware logging and comparison tools.
- Documented ZHAW firmware/current-loop parameters and early hardware transfer.
- Prepared the June 24 review with Thomas Weinmann.

## Known limitations

- The successful training plant was still idealized.
- Analytical and Simscape broad evaluations did not agree sufficiently.
- Static friction, dead zone, sensor processing, delays, and current-loop details
  were not yet modeled consistently.
- The learned combined controller could be aggressive and oscillatory near
  upright.
- Some early 500 Hz evaluation artifacts used the wrong worker initialization
  and were corrected later on `weto-inputs`.
- Training and result directories are historical and not organized as a clean
  public release.

## Key documents

- [Direct TD3 swing-up plan](docs/direct_td3_swingup_plan_2026-06-11.md)
- [DDPG-to-TD3 transition](docs/td3_transition_2026-06-10.md)
- [MathWorks-style TD3 run results](docs/mathworks_style_td3_runs_2026-06-16.md)
- [TD3 overnight results](docs/td3_overnight_results_2026-06-11.md)
- [RL reference comparison](docs/rl_reference_comparison_2026-06-11.md)
- [Hardware transfer status](docs/hardware_transfer_status_2026-06-23.md)
- [Model-vs-hardware workflow](docs/model_vs_hardware_test_workflow.md)
- [ZHAW drehpendel parameter comparison](docs/zhaw_drehpendel_parameter_comparison_2026-06-18.md)
- [June 24 Weinmann meeting preparation](outputs/weinmann_meeting_2026-06-24/)

## Continuation and archive decision

The work concluded with the June 24 meeting with Thomas Weinmann from ZHAW.
His advice led to controlled network-size and observation experiments, followed
by more detailed actuator, sensor, friction, and hardware-oriented modeling.
That continuation is documented on branch `weto-inputs`.

Archive this branch after the README is pushed. Do not merge it wholesale into
the final repository. Retain the successful `500Hz_long` provenance, the
MathWorks-style TD3 and observation lessons, selected generic training/evaluation
tools, and the early hardware-transfer conclusions.
