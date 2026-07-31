function cfg = makeFurutaMathWorksStyleWideTD3Config()
%MAKEFURUTAMATHWORKSSTYLEWIDETD3CONFIG Overnight wider-reset TD3 experiment.

cfg = makeFurutaMathWorksStyleTD3Config();

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_wide";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_wide";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";

cfg.Training.MaxEpisodes = 3000;
cfg.Training.SaveAgentValue = 700;

cfg.Training.Reset.Name = "mathworks_style_wide_random";
cfg.Training.Reset.Theta1ErrorRange = deg2rad([-45 45]);
cfg.Training.Reset.Theta2ErrorRange = deg2rad([-90 90]);
cfg.Training.Reset.Omega1ErrorRange = [-2 2];
cfg.Training.Reset.Omega2ErrorRange = [-2 2];
end
