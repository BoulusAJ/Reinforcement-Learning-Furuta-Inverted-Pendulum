#pragma once

#include "IIRFilter.h"
#include "RLPolicy.h"
#include "ThreadFlag.h"
#include "mbed.h"
#include "rtos.h"

class RLPolicyThread
{
public:
    RLPolicyThread(float sampleTime, float agentCurrentLimitAbs);
    virtual ~RLPolicyThread();

    void start_loop();

    void updateMeasurement(float theta1, float theta2, float omega1, float omega2);
    void setEnabled(bool enabled);
    void setShadowMode(bool shadowMode);
    void setCurrentLimit(float agentCurrentLimitAbs);

    float getPolicyAction();
    float getPolicyCurrentCommand();
    float getPreviousAction();

private:
    Thread thread;
    Ticker ticker;
    ThreadFlag threadFlag;
    rtos::Mutex mutex;
    RLPolicy policy;

    float Ts;
    float agentCurrentLimitAbs;
    bool enabled{false};
    bool shadowMode{true};

    float theta1{0.0f};
    float theta2{0.0f};
    float omega1{0.0f};
    float omega2{0.0f};
    float previousAction{0.0f};
    float policyAction{0.0f};
    float policyCurrentCommand{0.0f};
    IIRFilter omega1Filter;
    IIRFilter omega2Filter;

    void loop();
    void sendSignal() { thread.flags_set(threadFlag); }
    void buildObservation(float obs[RLPolicy::InputSize], float theta1In, float theta2In, float omega1In, float omega2In, float previousActionIn) const;
    static float wrapToPi(float x);
};
