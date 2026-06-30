#include "RLPolicyThread.h"

#include "rl_policy_config.h"

#include <chrono>
#include <cmath>

using namespace std::chrono;
using MutexLock = rtos::ScopedMutexLock;

RLPolicyThread::RLPolicyThread(float sampleTime, float agentCurrentLimitAbs)
    : thread(osPriorityHigh, OS_STACK_SIZE)
    , Ts(sampleTime)
    , agentCurrentLimitAbs(agentCurrentLimitAbs)
{
    omega1Filter.differentiatingLowPass1TustinInit(100.0f, Ts);
    omega2Filter.differentiatingLowPass1TustinInit(100.0f, Ts);
}

RLPolicyThread::~RLPolicyThread() {}

void RLPolicyThread::start_loop()
{
    thread.start(callback(this, &RLPolicyThread::loop));
    ticker.attach(callback(this, &RLPolicyThread::sendSignal), microseconds{static_cast<int64_t>(Ts * 1e6f)});
}

void RLPolicyThread::updateMeasurement(float theta1In, float theta2In, float omega1In, float omega2In)
{
    MutexLock lock(mutex);
    theta1 = theta1In;
    theta2 = theta2In;
    omega1 = omega1In;
    omega2 = omega2In;
}

void RLPolicyThread::setEnabled(bool enabledIn)
{
    MutexLock lock(mutex);
    enabled = enabledIn;
    if (!enabled && !RL_POLICY_EVALUATE_WHEN_DISABLED) {
        previousAction = 0.0f;
        policyAction = 0.0f;
        policyCurrentCommand = 0.0f;
    }
}

void RLPolicyThread::setShadowMode(bool shadowModeIn)
{
    MutexLock lock(mutex);
    shadowMode = shadowModeIn;
}

void RLPolicyThread::setCurrentLimit(float agentCurrentLimitAbsIn)
{
    MutexLock lock(mutex);
    agentCurrentLimitAbs = fabsf(agentCurrentLimitAbsIn);
}

float RLPolicyThread::getPolicyAction()
{
    MutexLock lock(mutex);
    return policyAction;
}

float RLPolicyThread::getPolicyCurrentCommand()
{
    MutexLock lock(mutex);
    return policyCurrentCommand;
}

float RLPolicyThread::getPreviousAction()
{
    MutexLock lock(mutex);
    return previousAction;
}

void RLPolicyThread::loop()
{
    while (true) {
        ThisThread::flags_wait_any(threadFlag);

        float obs[RLPolicy::InputSize];
        bool localShouldEvaluate;
        float localAgentCurrentLimit;
        float localTheta1;
        float localTheta2Raw;
        float localPreviousAction;
        {
            MutexLock lock(mutex);
            localShouldEvaluate = enabled || RL_POLICY_EVALUATE_WHEN_DISABLED;
            localAgentCurrentLimit = agentCurrentLimitAbs;
            localTheta1 = theta1;
            localTheta2Raw = theta2;
            localPreviousAction = previousAction;
        }

        const float localTheta2 = -localTheta2Raw;
        const float localOmega1 = omega1Filter.apply(localTheta1);
        const float localOmega2 = omega2Filter.apply(localTheta2);
        buildObservation(obs, localTheta1, localTheta2, localOmega1, localOmega2, localPreviousAction);

        float action = 0.0f;
        float currentCommand = 0.0f;
        if (localShouldEvaluate) {
            action = policy.forward(obs);
            const float currentRaw = policy.actionToCurrent(action);
            const float currentLimitedForAgent = policy.clampCurrent(currentRaw, localAgentCurrentLimit);
            const float currentWithOffset = policy.applyCurrentOffset(currentLimitedForAgent);
            currentCommand = policy.clampCurrent(currentWithOffset, RL_POLICY_FINAL_CURRENT_LIMIT_A_DEFAULT);
        }

        {
            MutexLock lock(mutex);
            policyAction = action;
            policyCurrentCommand = currentCommand;
            previousAction = action;
        }
    }
}

void RLPolicyThread::buildObservation(float obs[RLPolicy::InputSize], float theta1In, float theta2In, float omega1In, float omega2In, float previousActionIn) const
{
    // Mirrors the Simulink observation chain: theta2 is sign-corrected before
    // this point, then (theta2 - pi) is wrapped and subtracted from zero.
    const float theta1Error = -theta1In;
    constexpr float PI = 3.14159265358979323846f;
    const float theta2Error = -wrapToPi(theta2In - PI);
    const float omega1Error = -omega1In;
    const float omega2Error = -omega2In;

    obs[0] = sinf(theta1Error);
    obs[1] = cosf(theta1Error);
    obs[2] = sinf(theta2Error);
    obs[3] = cosf(theta2Error);
    obs[4] = omega1Error;
    obs[5] = omega2Error;
    obs[6] = previousActionIn;
}

float RLPolicyThread::wrapToPi(float x)
{
    return atan2f(sinf(x), cosf(x));
}
