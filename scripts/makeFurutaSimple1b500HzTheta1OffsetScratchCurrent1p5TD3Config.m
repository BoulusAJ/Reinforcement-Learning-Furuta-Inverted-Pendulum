function cfg = makeFurutaSimple1b500HzTheta1OffsetScratchCurrent1p5TD3Config()
%MAKEFURUTASIMPLE1B500HZTHETA1OFFSETSCRATCHCURRENT1P5TD3CONFIG
% Scratch comparison run on the original simple 1b 500Hz_long model path.
% This mirrors the detailed 1c theta1-offset scratch diagnostic, but uses the
% same simple Simulink files/config family that produced the original
% 500Hz_long agent.
%
% localResetFcnFurutaCurriculum uses theta1_0 = -theta1Error0. Therefore the
% range below starts the physical arm angle near +22..+42 deg.

cfg = makeFurutaMathWorksStylePICurrent1b500HzLongTD3Config();

cfg.Training.UseInitialAgent = false;
cfg.Training.ResetInitialAgentExperienceBuffer = true;
cfg.Training.MaxEpisodes = 2000;
cfg.Training.SaveAgentValue = 700;
cfg.Training.UseParallel = true;
cfg.Training.RequestedWorkers = 10;

cfg.Limits.CurrentMax = 1.5;
cfg.Action.CurrentScale = cfg.Limits.CurrentMax;
cfg.Action.TorqueScale = cfg.Motor.km * cfg.Limits.CurrentMax;

cfg.Training.Reset.Name = "simple_1b_theta1_offset_scratch_current_1p5";
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

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1b_500hz_theta1_offset_scratch_current_1p5";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1b_500hz_theta1_offset_scratch_current_1p5";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
