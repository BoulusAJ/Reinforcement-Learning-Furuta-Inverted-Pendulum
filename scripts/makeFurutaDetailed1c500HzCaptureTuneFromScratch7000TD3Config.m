function cfg = makeFurutaDetailed1c500HzCaptureTuneFromScratch7000TD3Config()
%MAKEFURUTADETAILED1C500HZCAPTURETUNEFROMSCRATCH7000TD3CONFIG
% Fine-tune the latest detailed 1c scratch7000 agent with extra upright
% capture/balance shaping. The starting policy already learned swing-up-like
% energy injection; this run tries to teach capture and stabilization.

cfg = makeFurutaDetailed1c500HzLongScratch7000TD3Config();

latestRunDir = fullfile( ...
    cfg.ResultsRoot, "TD3", ...
    "run_20260708_222715_td3_mathworks_style_pi_current_1c_500hz_long_detailed_scratch7000");

cfg.Training.UseInitialAgent = true;
cfg.Training.InitialAgentRunDir = latestRunDir;
cfg.Training.InitialAgentPath = fullfile( ...
    latestRunDir, ...
    "FurutaTD3_mathworks_style_pi_current_1c_500hz_long_detailed_scratch7000_final.mat");
cfg.Training.ResetInitialAgentExperienceBuffer = true;
cfg.Training.MaxEpisodes = 2000;
cfg.Training.SaveAgentValue = 1300;

cfg.Agent.ExplorationNoiseStd = 0.08;
cfg.Agent.ExplorationNoiseStdMin = 0.01;
cfg.Agent.ExplorationNoiseDecayRate = 2e-6;
cfg.Agent.ActorLearnRate = 2e-4;
cfg.Agent.CriticLearnRate = 5e-4;

cfg.Reward.EnableUprightCaptureShaping = true;
cfg.Reward.UprightCaptureAngle = deg2rad(25);
cfg.Reward.UprightCaptureTheta2Scale = deg2rad(10);
cfg.Reward.UprightCaptureOmega1Scale = 5;
cfg.Reward.UprightCaptureOmega2Scale = 5;
cfg.Reward.UprightCaptureBonusWeight = 0.8;
cfg.Reward.UprightCaptureTheta2Weight = 0.8;
cfg.Reward.UprightCaptureOmega1Weight = 0.05;
cfg.Reward.UprightCaptureOmega2Weight = 0.25;
cfg.Reward.UprightCaptureSmoothnessWeight = 0.1;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1c_500hz_capture_tune_from_scratch7000";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1c_500hz_capture_tune_from_scratch7000";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
