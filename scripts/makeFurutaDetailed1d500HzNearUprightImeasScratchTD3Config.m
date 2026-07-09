function cfg = makeFurutaDetailed1d500HzNearUprightImeasScratchTD3Config()
%MAKEFURUTADETAILED1D500HZNEARUPRIGHTIMEASSCRATCHTD3CONFIG
% Near-upright 1d detailed-model scratch run with measured current in obs.
%
% This is a short diagnostic run before another long swing-up attempt. It
% checks whether an 8-observation policy, including measured current I_meas,
% can learn upright balance on the detailed 1d model from scratch.

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

cfg.Training.UseInitialAgent = false;
cfg.Training.ResetInitialAgentExperienceBuffer = false;
cfg.Training.MaxEpisodes = 1500;
cfg.Training.SaveAgentValue = 700;

cfg.Training.Reset.Name = "detailed_1d_near_upright_imeas_scratch";
cfg.Training.Reset.Theta1ErrorRange = deg2rad([-5 5]);
cfg.Training.Reset.Theta2ErrorRange = deg2rad([-5 5]);
cfg.Training.Reset.Omega1ErrorRange = [-1 1];
cfg.Training.Reset.Omega2ErrorRange = [-1 1];

cfg.Safety.EnablePendulumTravelLimit = true;
cfg.Safety.MaxAbsPendulumTravel = 3*pi;  % 1.5 full rotations from episode start.
cfg.Safety.EnableUprightReachTimeout = true;
cfg.Safety.AgentSampleTime = cfg.Agent.SampleTime;
cfg.Safety.UprightReachTimeout_s = 1.0;
cfg.Safety.UprightReachTolerance = deg2rad(15);
cfg.Safety.UprightReachTimeoutRequiresCurrent = true;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1d_500hz_near_upright_imeas_scratch";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1d_500hz_near_upright_imeas_scratch";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
