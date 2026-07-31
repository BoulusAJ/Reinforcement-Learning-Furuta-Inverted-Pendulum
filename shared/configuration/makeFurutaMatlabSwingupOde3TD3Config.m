function cfg = makeFurutaMatlabSwingupOde3TD3Config()
%MAKEFURUTAMATLABSWINGUPODE3TD3CONFIG Simulink-convention MATLAB training.
%
% This configuration keeps the fast analytical TD3 setup, but uses the
% established reference-minus-measurement observation convention and an
% ode3-equivalent fixed-step mechanical integrator.

cfg = makeFurutaMatlabSwingupTD3Config();

cfg.MatlabEnvironment.IntegrationMethod = "ode3_bogacki_shampine";
cfg.Observation.ErrorConvention = "reference_minus_measurement";
cfg.Observation.Theta1ErrorDefinition = "0-wrap(theta1)";
cfg.Observation.Theta2ErrorDefinition = "0-wrap(theta2-pi)";
cfg.Observation.OmegaErrorDefinition = "0-omega";

cfg.Reward.CaptureBonus = 100;
cfg.Reward.UnsafePenalty = 100;
cfg.Reward.TimeoutPenalty = 10;

% Fixed cases used by the custom evaluator during training. theta2 is the
% physical pendulum angle: 0 deg is hanging and 180 deg is upright.
cfg.Evaluation.FixedSwingupCases = table( ...
    (1:10)', ...
    [0; -5; 5; 0; 0; -3; 3; -5; 5; 0], ...
    [0; -5; 5; -3; 3; 0; 0; 2; -2; 0], ...
    [0; 0; 0; 0.5; -0.5; 0; 0; 0.5; -0.5; 1.0], ...
    [0; 0; 0; 0; 0; 0.5; -0.5; -0.5; 0.5; -1.0], ...
    VariableNames=["Case", "Theta1Deg", "Theta2Deg", "Omega1", "Omega2"]);
cfg.Evaluation.CustomEvaluationFrequency = 50;

% Stop once the deterministic policy captures all ten fixed cases.
cfg.Training.StopTrainingCriteria = "EvaluationStatistic";
cfg.Training.StopTrainingValue = 1.0;
cfg.Training.UseParallel = false;

cfg.Training.SavePrefix = ...
    "FurutaTD3_matlab_analytical_ode3_simulink_convention_100hz_fast_actor1x64_critic2x64";
cfg.Training.RunName = "run_" + string(datetime("now", ...
    "Format", "yyyyMMdd_HHmmss")) ...
    + "_td3_matlab_analytical_ode3_simulink_convention_100hz_fast";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
