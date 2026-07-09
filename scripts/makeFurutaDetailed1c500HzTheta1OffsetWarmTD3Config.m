function cfg = makeFurutaDetailed1c500HzTheta1OffsetWarmTD3Config()
%MAKEFURUTADETAILED1C500HZTHETA1OFFSETWARMTD3CONFIG
% Fine-tune the original 500Hz_long agent on the 1c detailed model near the
% observed theta1 offset balance region, keeping the original replay buffer.
%
% localResetFcnFurutaCurriculum uses theta1_0 = -theta1Error0. Therefore the
% range below starts the physical arm angle near +22..+42 deg.

cfg = makeFurutaMathWorksStylePICurrent1c500HzLongDetailedTD3Config();

cfg.Training.UseInitialAgent = true;
cfg.Training.ResetInitialAgentExperienceBuffer = false;
cfg.Training.MaxEpisodes = 2000;
cfg.Training.SaveAgentValue = 700;

cfg.Agent.ExplorationNoiseStd = 0.10;
cfg.Agent.ExplorationNoiseStdMin = 0.02;
cfg.Agent.ExplorationNoiseDecayRate = 2e-6;

cfg.Training.Reset.Name = "detailed_1c_theta1_offset_warm";
cfg.Training.Reset.Theta1ErrorRange = deg2rad([-42 -22]);
cfg.Training.Reset.Theta2ErrorRange = deg2rad([-5 5]);
cfg.Training.Reset.Omega1ErrorRange = [-1 1];
cfg.Training.Reset.Omega2ErrorRange = [-1 1];

cfg.Safety.EnablePendulumTravelLimit = true;
cfg.Safety.MaxAbsPendulumTravel = 3*pi;  % 1.5 full rotations from episode start.
cfg.Safety.EnableUprightReachTimeout = true;
cfg.Safety.AgentSampleTime = cfg.Agent.SampleTime;
cfg.Safety.UprightReachTimeout_s = 1.0;
cfg.Safety.UprightReachTolerance = deg2rad(15);
cfg.Safety.UprightReachTimeoutRequiresCurrent = true;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1c_500hz_theta1_offset_warm";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1c_500hz_theta1_offset_warm";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
