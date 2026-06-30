#include "IO_handler.h"
#include "mbed.h"
#include "realtime_thread.h"
#include "rl_policy_config.h"

// Note:
// - This mirrors drehpendel/src/main.cpp and only adds the policy thread
//   sample time/current limit configuration.

int main()
{
    // Input-Output handler
    IO_handler io_handler;

    // Real-time thread with sampling time Ts
    float Ts = 200.0e-6f;
    float Ts_fast = 50.0e-6f;

#if RL_POLICY_CONTROLLER_ENABLE
    float Ts_policy = 1.0f / RL_POLICY_DEFAULT_RATE_HZ;
    float policy_current_limit = RL_POLICY_AGENT_CURRENT_LIMIT_A_DEFAULT;

    realtime_thread rt_thread(io_handler, Ts, Ts_fast, Ts_policy, policy_current_limit);
#else
    realtime_thread rt_thread(io_handler, Ts, Ts_fast);
#endif
    rt_thread.start_loop();

    while (true)
        ThisThread::sleep_for(500ms);
}
