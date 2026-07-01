function cfg = makeFurutaMathWorksStylePICurrent1c500HzLongActor1x64Critic2x64ArcObsTD3Config()
%MAKEFURUTAMATHWORKSSTYLEPICURRENT1C500HZLONGACTOR1X64CRITIC2X64ARCOBSTD3CONFIG 500 Hz arc-observation TD3 run.
%
% Weto-input follow-up: keep the 500 Hz long actor 1x64 / critic 2x64 setup,
% but use the 1c Simulink models with reduced arc-distance observations.

cfg = makeFurutaMathWorksStylePICurrent1bTD3Config( ...
    TrainingModelName="inv_rot_pen_RL_cntr_simscape_sim_1c_train", ...
    EvaluationModelName="inv_rot_pen_RL_cntr_simscape_sim_1c_analytical_active");

cfg.Agent.ExperienceBufferLength = 2.5e6;
cfg.Agent.NumWarmStartSteps = 2500;
cfg.Agent.NetworkStyle = "custom_mlp";
cfg.Agent.ActorHiddenLayerSizes = 64;
cfg.Agent.CriticHiddenLayerSizes = [64 64];
cfg.Agent.NetworkDescription = "custom_mlp_actor_1x64_critic_2x64_arcobs";

cfg.Observation.Names = [ ...
    "theta1ArcNorm", ...
    "theta2ArcNorm", ...
    "omega1ScaledNorm", ...
    "omega2ScaledNorm", ...
    "previousAction"];
cfg.Observation.Dimension = 5;
cfg.Observation.AngularVelocityScale = 25;
cfg.Reward.AngularVelocityScale = cfg.Observation.AngularVelocityScale;

cfg.Training.MaxEpisodes = 5000;
cfg.Training.StepsUntilDataIsSent = 2500;
cfg.Training.SaveAgentValue = 1800;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1c_500hz_long_actor1x64_critic2x64_arcobs";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1c_500hz_long_actor1x64_critic2x64_arcobs";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
