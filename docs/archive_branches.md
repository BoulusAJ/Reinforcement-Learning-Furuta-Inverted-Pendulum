# Development Branches

The clean `main` branch contains the files needed to understand, evaluate, and
continue the two final approaches. Earlier experiments remain on development
branches.

| Branch | Purpose and result |
|---|---|
| `dev/upright-stabilization` | Initial DDPG near-upright work. No reliable policy; useful task and evaluation setup. |
| `dev/direct-td3-swingup` | Transition to direct TD3 and the successful `500Hz_long` combined policy. |
| `dev/weto-inputs` | Network, observation, detailed-plant, hardware-comparison, and July 9 presentation work. |
| `dev/weto-inputs-side` | Low-conflict preparation of the detailed model, measurements, and training handoff. Merged into `dev/weto-inputs`. |
| `dev/nucleo-policy-deploy` | Actor export, C++ policy, UART, shadow mode, timing, and successful onboard demonstration. |
| `dev/swing-up` | MATLAB analytical TD3 swing-up, LQR capture region, student configurations, and final comparisons. |

These branches are historical records, not supported release branches. They
contain duplicate models, generated files, and failed experiments that were not
copied into `main`.
