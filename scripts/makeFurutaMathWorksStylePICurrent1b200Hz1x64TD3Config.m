function cfg = makeFurutaMathWorksStylePICurrent1b200Hz1x64TD3Config()
%MAKEFURUTAMATHWORKSSTYLEPICURRENT1B200HZ1X64TD3CONFIG 1x64 200 Hz 1b PI/current TD3 run.
%
% Controlled Weto-input experiment: use the same 1b PI/current training and
% analytical-evaluation models with the MathWorks-style wide reset settings,
% but replace the default TD3 network with one 64-unit hidden layer.

cfg = makeFurutaMathWorksStylePICurrent1bTD3Config();

cfg.Agent.SampleTime = 1 / 200;
cfg.Agent.NetworkStyle = "custom_mlp";
cfg.Agent.ActorHiddenLayerSizes = 64;
cfg.Agent.CriticHiddenLayerSizes = 64;
cfg.Agent.NetworkDescription = "custom_mlp_actor_1x64_critic_1x64";

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1b_200hz_1x64";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1b_200hz_1x64";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
