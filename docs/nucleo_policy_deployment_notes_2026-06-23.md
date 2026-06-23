# Nucleo Policy Deployment Notes - 2026-06-23

This note summarizes the side discussion about deploying the trained TD3 actor
policy on the Nucleo F446RE as a demonstrator.

## Context

Policy/run under discussion:

```text
results/TD3/run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long
```

Relevant saved configuration:

```text
Agent sample time: 0.002 s = 500 Hz
Observation dimension: 7
NetworkStyle: default
NumHiddenUnit: 64
Action current scale: 4 A
```

The deployed controller only needs the TD3 actor/policy. The critic networks
are training-only value estimators and are not needed on hardware.

## Policy Structure

The actor is expected to be a small feedforward network:

```text
[ 7 ] -> [ 64 ] -> [ 64 ] -> [ 1 ]
 input    ReLU     ReLU     tanh
```

Input observation:

```text
1 sin(theta1Error)
2 cos(theta1Error)
3 sin(theta2Error)
4 cos(theta2Error)
5 omega1Error
6 omega2Error
7 previousAction
```

Output:

```text
a_rl in [-1, 1]
I_cmd = 4.0 * a_rl
```

For hardware, `I_cmd` should still pass through a safety clamp before being
applied to the firmware current loop.

## Operation Count

For the assumed `7 -> 64 -> 64 -> 1` network:

```text
W1: 64 x 7   -> 448 multiplications
W2: 64 x 64  -> 4096 multiplications
W3: 1 x 64   -> 64 multiplications
Total        -> 4608 multiplications
```

Additions are roughly the same order:

```text
about 4608 additions
128 ReLU comparisons
1 tanh
```

At 500 Hz:

```text
about 2.3 million multiplications/s
about 2.3 million additions/s
```

This should be feasible on the Nucleo F446RE, which has a Cortex-M4F with
single-precision floating-point support.

## Eigen vs Plain C

`Eigen` means implementing inference using fixed-size C++ matrix/vector types.
Example:

```cpp
h1 = (W1 * obs + b1).cwiseMax(0.0f);
```

`Brute force` means implementing the forward pass directly using static arrays
and loops:

```cpp
for (int i = 0; i < 64; ++i) {
    float s = b1[i];
    for (int j = 0; j < 7; ++j) {
        s += W1[i][j] * obs[j];
    }
    h1[i] = s > 0.0f ? s : 0.0f;
}
```

Recommendation for first demonstrator:

```text
Use plain static float arrays and fixed for-loops.
Compile with GCC -O3.
Do not fully manually unroll everything first.
```

Reasoning:

- the network is tiny,
- loop overhead is negligible,
- `-O3` may partially unroll fixed loops,
- plain arrays are easy to verify and port,
- fully unrolled code is harder to inspect and maintain,
- Eigen can work but may add compile/code-size complexity.

If timing is not sufficient, then consider:

```text
1. manually unroll selected loops,
2. use CMSIS-DSP,
3. use fixed-size Eigen carefully,
4. generate fully unrolled code automatically.
```

## Export And Verification Plan

Recommended safe deployment path:

```text
1. Export actor weights from MATLAB.
2. Reimplement actor forward pass in MATLAB from raw weights.
3. Verify raw MATLAB forward pass matches the RL actor output.
4. Export weights to C arrays.
5. Implement actor_forward() in C/C++ on Nucleo.
6. Run in shadow mode first.
7. Compare Nucleo policy output to MATLAB/SLDRT policy output.
8. Only then enable current output with strict safety clamps.
```

The forward pass is:

```text
z1 = W1 * obs + b1
h1 = relu(z1)
z2 = W2 * h1 + b2
h2 = relu(z2)
z3 = W3 * h2 + b3
a  = tanh(z3)
```

For this policy, final action scaling inside the actor is effectively
`[-1, 1]`, so hardware current scaling should be applied after inference:

```text
I_cmd = 4.0 * a
```

then clamped to the approved hardware current limit.

## Important Embedded Details

The network math is probably not the main risk. The important matching details
are:

```text
sample time = 0.002 s / 500 Hz
theta and omega sign conventions
theta2 upright wrapping
velocity estimation/filtering
previousAction definition
current scaling
safety clamps and enable logic
```

`previousAction` should be the previous normalized action in `[-1, 1]`, not the
previous current command in amps.

Use single-precision math on firmware:

```text
sinf, cosf, atan2f, tanhf
```

Avoid dynamic allocation and serial printing inside the real-time loop.

## Timing Test

Before enabling motor output, measure computation time:

```text
toggle GPIO high
compute observation and policy
toggle GPIO low
measure pulse width with oscilloscope or logic analyzer
```

The full loop must comfortably fit below:

```text
2 ms at 500 Hz
```

## Neural Policy Reduction

Neural policy reduction is possible, but not needed until timing measurements
show it is necessary.

Options:

```text
1. Train a smaller actor from scratch, e.g. 7 -> 32 -> 32 -> 1.
2. Distill the existing 64-64 actor into a smaller supervised network.
3. Prune the actor, though this is less attractive for embedded deployment.
```

Parameter counts:

```text
64-64 actor: about 4737 parameters, about 18.5 kB as float32
32-32 actor: about 1313 parameters
16-16 actor: about 417 parameters
```

Recommendation:

```text
First export and measure the existing 64-64 actor.
Only reduce the network if timing or memory actually becomes a problem.
```

## Bottom Line

It is realistic to run this trained actor policy on the Nucleo F446RE at 500 Hz
as a demonstrator. The controller should deploy only the actor, not the critic.
The safest implementation path is plain static float arrays with fixed loops,
verified first against MATLAB and then tested on the Nucleo in shadow mode
before enabling current output.
