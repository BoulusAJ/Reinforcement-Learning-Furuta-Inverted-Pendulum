#include "realtime_thread.h"

#include "rl_policy_config.h"

#include <cstdint>
#include <cstring>

realtime_thread::realtime_thread(IO_handler &io, float Ts, float Ts_fast)
    : realtime_thread(io, Ts, Ts_fast, 0.0f, 0.0f)
{
}

realtime_thread::realtime_thread(IO_handler &io, float Ts, float Ts_fast, float Ts_policy, float policy_current_limit)
    : thread(osPriorityHigh1, OS_STACK_SIZE)
    , Ts(Ts)
    , io_handler(io)
    , serialPipe(USBTX, USBRX, BAUD, 8, 5)
    , fast_rt_thread(io, Ts_fast)
#if RL_POLICY_CONTROLLER_ENABLE
    , rl_policy_thread(Ts_policy, policy_current_limit)
#endif
    // , m_SerialStream(PB_10, PC_5, 30, 2000000)
    // , m_Chirp(F0_HZ, (1.0f / 2.0f) / Ts, T1_SEC, Ts)
{
#if !RL_POLICY_CONTROLLER_ENABLE
    (void)Ts_policy;
    (void)policy_current_limit;
#endif
}

realtime_thread::~realtime_thread() {}

void realtime_thread::loop(void)
{
    char rx_buf[4 + 1]; // 1 float (4 bytes) + 1 enable byte

#if RL_POLICY_CONTROLLER_ENABLE && RL_POLICY_UART_EXTENDED_RESPONSE
    char tx_buf[4 + 4 + 4 + 4 + 4]; // 5 floats: motor_angle, pendulum_angle, current, policy_action, policy_current_cmd
#else
    char tx_buf[4 + 4 + 4]; // 3 floats: motor_angle, pendulum_angle, current
#endif

    bool is_enabled = false;

    uint32_t watchdog_counter = (uint32_t)(WATCHDOG_TIMEOUT_SEC / Ts + 0.5f);

    // m_Timer.start();
    // m_time_previous_us = m_Timer.elapsed_time();

    while (true) {
        ThisThread::flags_wait_any(threadFlag);

        // // Measure delta time since last cycle (unused, kept as reference)
        // const microseconds time_us = m_Timer.elapsed_time();
        // const float dtime_us = duration_cast<microseconds>(time_us - m_time_previous_us).count();
        // m_time_previous_us = time_us;

        if (serialPipe.readable()) {

            io_handler.set_enable_rtt_do(true);

            // Read values (setpoint and enable) from UART
            const int nread = serialPipe.get(rx_buf, sizeof(rx_buf), true);
            if (nread != static_cast<int>(sizeof(rx_buf))) {
                // Error or incomplete frame: treat as "no valid communication" for watchdog
                if (watchdog_counter > 0) {
                    watchdog_counter--;
                    if (watchdog_counter == 0 && is_enabled) {
                        // Watchdog timeout: no valid communication for WATCHDOG_TIMEOUT_SEC seconds
                        is_enabled = false;
                        io_handler.set_enable_motor(false);
                        fast_rt_thread.updateState(false, 0.0f);
#if RL_POLICY_CONTROLLER_ENABLE
                        rl_policy_thread.setEnabled(false);
#endif
                    }
                }
                continue;
            }

            // We have a valid fresh packet -> reset watchdog
            watchdog_counter = (uint32_t)(WATCHDOG_TIMEOUT_SEC / Ts + 0.5f);

            // From host: 1 float value (4 bytes) + enable (1 byte) are sent
            float current_cmd = 0.0f;
            memcpy(&current_cmd, &rx_buf[0], sizeof(float)); // assumes little-endian
            const bool enable_cmd = (rx_buf[4] == 1);        // uint8 value -> bool

            // Enable is simply set by the command itself
            is_enabled = enable_cmd;
            io_handler.set_enable_motor(is_enabled);
#if RL_POLICY_CONTROLLER_ENABLE
            rl_policy_thread.setEnabled(is_enabled);
#endif

            // Drive fast loop according to current enable state
            float current = 0.0f;
            float motor_angle = 0.0f;
            float pendulum_angle = 0.0f;
#if RL_POLICY_CONTROLLER_ENABLE
            float rl_policy_current_cmd = rl_policy_thread.getPolicyCurrentCommand();
            const float current_cmd_applied =
                (RL_POLICY_SHADOW_MODE_DEFAULT != 0) ? current_cmd : rl_policy_current_cmd;
#else
            const float current_cmd_applied = current_cmd;
#endif

            if (is_enabled)
                fast_rt_thread.updateStateAndReturnMeasurements(true, current_cmd_applied, current, motor_angle, pendulum_angle);
            else
                fast_rt_thread.updateStateAndReturnMeasurements(false, 0.0f, current, motor_angle, pendulum_angle);

#if RL_POLICY_CONTROLLER_ENABLE
            rl_policy_thread.updateMeasurement(motor_angle, pendulum_angle, 0.0f, 0.0f);

            const float rl_policy_action = rl_policy_thread.getPolicyAction();
            rl_policy_current_cmd = rl_policy_thread.getPolicyCurrentCommand();
#endif

            float third_tx_value = current;
#if RL_POLICY_CONTROLLER_ENABLE && !RL_POLICY_UART_EXTENDED_RESPONSE
#if RL_POLICY_UART_THIRD_FLOAT_MODE == RL_POLICY_UART_THIRD_FLOAT_POLICY_ACTION
            third_tx_value = rl_policy_action;
#elif RL_POLICY_UART_THIRD_FLOAT_MODE == RL_POLICY_UART_THIRD_FLOAT_POLICY_CURRENT_CMD
            third_tx_value = rl_policy_current_cmd;
#endif
#endif

            // Write encoder values + selected third value back to host.
            memcpy(&tx_buf[0], &motor_angle, sizeof(float));
            memcpy(&tx_buf[4], &pendulum_angle, sizeof(float));
            memcpy(&tx_buf[8], &third_tx_value, sizeof(float));
#if RL_POLICY_CONTROLLER_ENABLE && RL_POLICY_UART_EXTENDED_RESPONSE
            memcpy(&tx_buf[12], &rl_policy_action, sizeof(float));
            memcpy(&tx_buf[16], &rl_policy_current_cmd, sizeof(float));
#endif
            serialPipe.put(tx_buf, sizeof(tx_buf), true);

            io_handler.set_enable_rtt_do(false);

        } else {
            if (watchdog_counter > 0) {
                watchdog_counter--;
                if (watchdog_counter == 0 && is_enabled) {
                    // Watchdog timeout: no communication for WATCHDOG_TIMEOUT_SEC seconds
                    // -> force motor and current loop disabled
                    is_enabled = false;
                    io_handler.set_enable_motor(false);
                    fast_rt_thread.updateState(false, 0.0f);
#if RL_POLICY_CONTROLLER_ENABLE
                    rl_policy_thread.setEnabled(false);
#endif
                }
            }
        }
    }
}

void realtime_thread::start_loop(void)
{
    fast_rt_thread.start_loop();
#if RL_POLICY_CONTROLLER_ENABLE
    rl_policy_thread.start_loop();
#endif

    thread.start(callback(this, &realtime_thread::loop));
    ticker.attach(callback(this, &realtime_thread::sendSignal), microseconds{static_cast<int64_t>(Ts * 1e6f)});
}
