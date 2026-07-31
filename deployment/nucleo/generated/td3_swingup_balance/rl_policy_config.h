#pragma once

// Switches for the Nucleo policy demonstrator.
// Shadow mode computes policy output but does not use it to drive current.

// 0: compile the realtime thread in original drehpendel current-command mode.
//    The RL policy thread, NN weights, and extended UART response are not used.
// 1: compile the RL policy demonstrator additions.
#define RL_POLICY_CONTROLLER_ENABLE 1

#define RL_POLICY_USE_EIGEN 1
#define RL_POLICY_DEFAULT_RATE_HZ 500.0f
#define RL_POLICY_SHADOW_MODE_DEFAULT 0
#define RL_POLICY_AGENT_CURRENT_LIMIT_A_DEFAULT 0.5f
#define RL_POLICY_FINAL_CURRENT_LIMIT_A_DEFAULT 4.0f
#define RL_POLICY_CURRENT_LIMIT_A_DEFAULT RL_POLICY_AGENT_CURRENT_LIMIT_A_DEFAULT

// Mirrors the Simulink current-command path that adds a small sign-dependent
// offset before sending i_cmd to the Nucleo.
#define RL_POLICY_CURRENT_OFFSET_ENABLE 1
#define RL_POLICY_CURRENT_OFFSET_A 0.0205f
// #define RL_POLICY_CURRENT_OFFSET_A 0.00f

// 1: keep evaluating the NN when the motor enable input is false.
//    Motor current is still disabled by realtime_thread; this only keeps
//    policy_action/policy_current_cmd available for shadow comparison while
//    moving the pendulum by hand.
#define RL_POLICY_EVALUATE_WHEN_DISABLED 1

// UART response extension:
// 0: original drehpendel response, 3 floats:
//    motor_angle, pendulum_angle, selected third float
// 1: extended response, 5 floats:
//    motor_angle, pendulum_angle, current, policy_action, policy_current_cmd
#define RL_POLICY_UART_EXTENDED_RESPONSE 0

// Used only when RL_POLICY_UART_EXTENDED_RESPONSE is 0.
// 0: third float = measured current, original drehpendel behavior
// 1: third float = policy_action, normalized [-1, 1]
// 2: third float = policy_current_cmd, same value applied in shadow-off mode
#define RL_POLICY_UART_THIRD_FLOAT_MEASURED_CURRENT 0
#define RL_POLICY_UART_THIRD_FLOAT_POLICY_ACTION 1
#define RL_POLICY_UART_THIRD_FLOAT_POLICY_CURRENT_CMD 2
#define RL_POLICY_UART_THIRD_FLOAT_MODE RL_POLICY_UART_THIRD_FLOAT_POLICY_CURRENT_CMD
