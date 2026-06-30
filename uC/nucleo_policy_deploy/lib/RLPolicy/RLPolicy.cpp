#include "RLPolicy.h"

#include "rl_policy_config.h"

#if RL_POLICY_CONTROLLER_ENABLE
#include "rl_policy_weights.h"

#include <cmath>

#if RL_POLICY_USE_EIGEN
#include "Eigen.h"
#endif

namespace {

inline float relu(float x)
{
    return x > 0.0f ? x : 0.0f;
}

inline float clamp(float x, float lo, float hi)
{
    if (x < lo)
        return lo;
    if (x > hi)
        return hi;
    return x;
}

} // namespace

float RLPolicy::forward(const float observation[InputSize]) const
{
#if RL_POLICY_USE_EIGEN
    using namespace rl_policy_weights;

    Eigen::Matrix<float, INPUT_SIZE, 1> obs;
    for (int i = 0; i < INPUT_SIZE; ++i)
        obs(i) = observation[i];

    Eigen::Matrix<float, HIDDEN1_SIZE, 1> h1;
    for (int r = 0; r < HIDDEN1_SIZE; ++r) {
        float s = b1[r];
        for (int c = 0; c < INPUT_SIZE; ++c)
            s += W1[r][c] * obs(c);
        h1(r) = relu(s);
    }

    Eigen::Matrix<float, HIDDEN2_SIZE, 1> h2;
    for (int r = 0; r < HIDDEN2_SIZE; ++r) {
        float s = b2[r];
        for (int c = 0; c < HIDDEN1_SIZE; ++c)
            s += W2[r][c] * h1(c);
        h2(r) = relu(s);
    }

    float z = b3[0];
    for (int c = 0; c < HIDDEN2_SIZE; ++c)
        z += W3[0][c] * h2(c);

    return clamp(tanhf(z), -1.0f, 1.0f);
#else
    using namespace rl_policy_weights;

    float h1[HIDDEN1_SIZE];
    float h2[HIDDEN2_SIZE];

    for (int r = 0; r < HIDDEN1_SIZE; ++r) {
        float s = b1[r];
        for (int c = 0; c < INPUT_SIZE; ++c)
            s += W1[r][c] * observation[c];
        h1[r] = relu(s);
    }

    for (int r = 0; r < HIDDEN2_SIZE; ++r) {
        float s = b2[r];
        for (int c = 0; c < HIDDEN1_SIZE; ++c)
            s += W2[r][c] * h1[c];
        h2[r] = relu(s);
    }

    float z = b3[0];
    for (int c = 0; c < HIDDEN2_SIZE; ++c)
        z += W3[0][c] * h2[c];

    return clamp(tanhf(z), -1.0f, 1.0f);
#endif
}

float RLPolicy::actionToCurrent(float action) const
{
    return action * rl_policy_weights::ACTION_CURRENT_SCALE_A;
}

float RLPolicy::applyCurrentOffset(float current) const
{
#if RL_POLICY_CURRENT_OFFSET_ENABLE
    if (current > 0.0f)
        return current + RL_POLICY_CURRENT_OFFSET_A;
    if (current < 0.0f)
        return current - RL_POLICY_CURRENT_OFFSET_A;
#endif
    return current;
}

float RLPolicy::clampCurrent(float current, float limitAbs) const
{
    return clamp(current, -limitAbs, limitAbs);
}
#endif
