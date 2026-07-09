function cfg = makeFurutaDetailed1c500HzTheta1OffsetGentleTD3Config()
%MAKEFURUTADETAILED1C500HZTHETA1OFFSETGENTLETD3CONFIG
% Gentle fine-tune of the original 500Hz_long policy on the 1c detailed model.
%
% The zero-exploration smoke test showed that the loaded policy is stable in
% this theta1-offset reset region. This config keeps the policy weights, clears
% the old replay buffer, and uses small exploration plus lower learning rates
% to adapt without quickly destroying the working upright behavior.

cfg = makeFurutaDetailed1c500HzTheta1OffsetWarmTD3Config();

cfg.Training.ResetInitialAgentExperienceBuffer = true;

cfg.Agent.ExplorationNoiseStd = 0.03;
cfg.Agent.ExplorationNoiseStdMin = 0.005;
cfg.Agent.ExplorationNoiseDecayRate = 2e-6;

cfg.Agent.ActorLearnRate = 2e-4;
cfg.Agent.CriticLearnRate = 5e-4;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1c_500hz_theta1_offset_gentle";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1c_500hz_theta1_offset_gentle";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
