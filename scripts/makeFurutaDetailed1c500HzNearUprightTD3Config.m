function cfg = makeFurutaDetailed1c500HzNearUprightTD3Config()
%MAKEFURUTADETAILED1C500HZNEARUPRIGHTTD3CONFIG
% 1000-episode near-upright detailed-model fine-tuning sanity check.
%
% This run keeps the detailed 1c model and 500 Hz agent rate, starts from the
% original deployed 500Hz_long agent, and only resets near the upright
% position. It is intended to answer one narrow question before changing the
% observation/reward structure: can the detailed model be stabilized near
% upright with the existing policy and reward family?

cfg = makeFurutaMathWorksStylePICurrent1c500HzLongDetailedTD3Config();

cfg.Training.UseInitialAgent = true;
cfg.Training.ResetInitialAgentExperienceBuffer = true;
cfg.Training.MaxEpisodes = 1000;
cfg.Training.SaveAgentValue = 700;

cfg.Training.Reset.Name = "detailed_near_upright_only";
cfg.Training.Reset.Theta1ErrorRange = deg2rad([-5 5]);
cfg.Training.Reset.Theta2ErrorRange = deg2rad([-5 5]);
cfg.Training.Reset.Omega1ErrorRange = [-1 1];
cfg.Training.Reset.Omega2ErrorRange = [-1 1];

cfg.Safety.EnablePendulumTravelLimit = true;
cfg.Safety.MaxAbsPendulumTravel = 3*pi;  % 1.5 full rotations from episode start.
cfg.Safety.EnableUprightReachTimeout = true;
cfg.Safety.AgentSampleTime = cfg.Agent.SampleTime;
cfg.Safety.UprightReachTimeout_s = 3.0;
cfg.Safety.UprightReachTolerance = deg2rad(15);

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1c_500hz_long_detailed_near_upright";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1c_500hz_long_detailed_near_upright";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
