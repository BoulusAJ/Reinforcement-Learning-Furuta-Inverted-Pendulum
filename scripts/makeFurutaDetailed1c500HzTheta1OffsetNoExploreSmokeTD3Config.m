function cfg = makeFurutaDetailed1c500HzTheta1OffsetNoExploreSmokeTD3Config()
%MAKEFURUTADETAILED1C500HZTHETA1OFFSETNOEXPLORESMOKETD3CONFIG
% Smoke-test the loaded 500Hz_long policy on the 1c theta1-offset reset.
%
% This run is intended to answer whether the loaded policy can already survive
% the offset upright reset region. It uses zero exploration, clears the replay
% buffer, and sets NumWarmStartSteps above the whole run length so the agent
% should collect experience without updating the networks.

cfg = makeFurutaDetailed1c500HzTheta1OffsetWarmTD3Config();

cfg.Training.MaxEpisodes = 100;
cfg.Training.ResetInitialAgentExperienceBuffer = true;
cfg.Training.UseFastRestart = true;

cfg.Agent.ExplorationNoiseStd = 0.0;
cfg.Agent.ExplorationNoiseStdMin = 0.0;
cfg.Agent.ExplorationNoiseDecayRate = 0.0;
cfg.Agent.NumWarmStartSteps = ...
    ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime) * cfg.Training.MaxEpisodes + 1;

cfg.Evaluation.UseShortEvaluation = true;
cfg.Evaluation.UseFullEvaluation = false;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1c_500hz_theta1_offset_noexplore_smoke";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1c_500hz_theta1_offset_noexplore_smoke";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
