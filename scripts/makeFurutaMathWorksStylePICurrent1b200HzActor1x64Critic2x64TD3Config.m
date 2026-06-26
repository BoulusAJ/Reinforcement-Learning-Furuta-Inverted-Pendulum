function cfg = makeFurutaMathWorksStylePICurrent1b200HzActor1x64Critic2x64TD3Config()
%MAKEFURUTAMATHWORKSSTYLEPICURRENT1B200HZACTOR1X64CRITIC2X64TD3CONFIG 200 Hz actor-small TD3 run.
%
% Controlled Weto-input follow-up: keep the deployment actor small with one
% 64-unit hidden layer, but restore the MATLAB default-style critic capacity
% with two 64-unit hidden layers.

cfg = makeFurutaMathWorksStylePICurrent1bTD3Config();

cfg.Agent.SampleTime = 1 / 200;
cfg.Agent.NetworkStyle = "custom_mlp";
cfg.Agent.ActorHiddenLayerSizes = 64;
cfg.Agent.CriticHiddenLayerSizes = [64 64];
cfg.Agent.NetworkDescription = "custom_mlp_actor_1x64_critic_2x64";

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1b_200hz_actor1x64_critic2x64";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1b_200hz_actor1x64_critic2x64";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
