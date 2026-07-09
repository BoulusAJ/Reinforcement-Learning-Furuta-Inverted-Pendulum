function cfg = makeFurutaDetailed1c500HzLongScratch7000TD3Config()
%MAKEFURUTADETAILED1C500HZLONGSCRATCH7000TD3CONFIG
% Long scratch TD3 run on the 1c detailed model path. This mirrors the
% original 500Hz_long training family, but uses the detailed 1c train/analysis
% files and extends training to 7000 episodes.

cfg = makeFurutaMathWorksStylePICurrent1c500HzLongDetailedTD3Config();

cfg.Training.UseInitialAgent = false;
cfg.Training.ResetInitialAgentExperienceBuffer = true;
cfg.Training.MaxEpisodes = 7000;
cfg.Training.UseParallel = true;
cfg.Training.RequestedWorkers = 22;
cfg.Training.UseFastRestart = true;

cfg.Limits.CurrentMax = 1.5;
cfg.Action.CurrentScale = cfg.Limits.CurrentMax;
cfg.Action.TorqueScale = cfg.Motor.km * cfg.Limits.CurrentMax;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1c_500hz_long_detailed_scratch7000";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1c_500hz_long_detailed_scratch7000";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
