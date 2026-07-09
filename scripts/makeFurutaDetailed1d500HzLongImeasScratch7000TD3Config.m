function cfg = makeFurutaDetailed1d500HzLongImeasScratch7000TD3Config()
%MAKEFURUTADETAILED1D500HZLONGIMEASSCRATCH7000TD3CONFIG
% Long scratch TD3 run on the 1d detailed model path with measured current
% I_meas as the 8th observation. This mirrors the 1c detailed scratch7000
% run, but uses the 1d train/analysis files and 8-observation agent.

cfg = makeFurutaMathWorksStylePICurrent1c500HzLongDetailedTD3Config();

cfg.Model.TrainingName = "inv_rot_pen_RL_cntr_simscape_sim_1d_train";
cfg.Model.EvaluationName = "inv_rot_pen_RL_cntr_simscape_sim_1d_analysis";
cfg.Model.Name = cfg.Model.TrainingName;
cfg.Model.TrainingAgentBlock = cfg.Model.TrainingName + "/RL Agent";
cfg.Model.EvaluationAgentBlock = cfg.Model.EvaluationName + "/RL Agent";
cfg.Model.AgentBlock = cfg.Model.TrainingAgentBlock;
cfg.Model.TrainingFile = fullfile(cfg.ProjectRoot, "scripts", cfg.Model.TrainingName + ".slx");
cfg.Model.EvaluationFile = fullfile(cfg.ProjectRoot, "scripts", cfg.Model.EvaluationName + ".slx");

cfg.Observation.Names = [ ...
    "sinTheta1Error", "cosTheta1Error", ...
    "sinTheta2Error", "cosTheta2Error", ...
    "omega1Error", "omega2Error", ...
    "previousAction", "I_meas"];
cfg.Observation.Dimension = 8;
cfg.Observation.OmegaScale = 25;
cfg.Observation.AngularVelocityScale = cfg.Observation.OmegaScale;
cfg.Reward.ObservationUsesSinCos = true;
cfg.Reward.ObservationOmegaIsScaled = true;
cfg.Reward.ObservationOmegaScale = cfg.Observation.OmegaScale;

cfg.Training.UseInitialAgent = false;
cfg.Training.ResetInitialAgentExperienceBuffer = true;
cfg.Training.MaxEpisodes = 7000;
cfg.Training.UseParallel = true;
cfg.Training.RequestedWorkers = 10;
cfg.Training.UseFastRestart = true;

cfg.Limits.CurrentMax = 1.5;
cfg.Action.CurrentScale = cfg.Limits.CurrentMax;
cfg.Action.TorqueScale = cfg.Motor.km * cfg.Limits.CurrentMax;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1d_500hz_long_imeas_scratch7000";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1d_500hz_long_imeas_scratch7000";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
