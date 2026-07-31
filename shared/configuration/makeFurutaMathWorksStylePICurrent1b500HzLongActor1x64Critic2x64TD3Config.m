function cfg = makeFurutaMathWorksStylePICurrent1b500HzLongActor1x64Critic2x64TD3Config()
%MAKEFURUTAMATHWORKSSTYLEPICURRENT1B500HZLONGACTOR1X64CRITIC2X64TD3CONFIG 500 Hz actor-small long TD3 run.
%
% Controlled Weto-input follow-up: keep the long 500 Hz PI/current 1b setup,
% use a one-hidden-layer actor, and restore the MATLAB default-style critic.

cfg = makeFurutaMathWorksStylePICurrent1b500HzLongTD3Config();

cfg.Agent.NetworkStyle = "custom_mlp";
cfg.Agent.ActorHiddenLayerSizes = 64;
cfg.Agent.CriticHiddenLayerSizes = [64 64];
cfg.Agent.NetworkDescription = "custom_mlp_actor_1x64_critic_2x64";

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1b_500hz_long_actor1x64_critic2x64";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1b_500hz_long_actor1x64_critic2x64";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
