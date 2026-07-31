function cfg = makeFurutaMathWorksStylePICurrent1b500HzLongTD3Config()
%MAKEFURUTAMATHWORKSSTYLEPICURRENT1B500HZLONGTD3CONFIG Longer 1b PI/current TD3 run.
%
% Same reward and 1b PI/current model path as the 500 Hz run, with training
% quantities scaled for the higher agent sample rate.

cfg = makeFurutaMathWorksStylePICurrent1bTD3Config();

cfg.Agent.ExperienceBufferLength = 2.5e6;
cfg.Agent.NumWarmStartSteps = 2500;

cfg.Training.MaxEpisodes = 5000;
cfg.Training.StepsUntilDataIsSent = 2500;
cfg.Training.SaveAgentValue = 1800;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1b_500hz_long";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1b_500hz_long";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
