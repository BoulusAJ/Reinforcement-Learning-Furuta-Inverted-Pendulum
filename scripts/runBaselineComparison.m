function runBaselineComparison()
%RUNBASELINECOMPARISON Compare baseline and RL controllers on common cases.
%
% Fill in after the baseline controller and Simulink model are available.

cfg = makeFurutaConfig();

disp("Baseline comparison scaffold");
disp("1. Run LQR/PID baseline on fixed initial-condition sweep.");
disp("2. Run deterministic RL policy on the same sweep.");
disp("3. Export angle response, action response, reward, and safety metrics.");
disp("Results directory: " + cfg.Training.ResultsDir);
end
