function cfg = makeFurutaMatlabSwingupOde3StudentTD3Config()
%MAKEFURUTAMATLABSWINGUPODE3STUDENTTD3CONFIG Laptop-oriented TD3 training.
%
% From-scratch teaching configuration:
%   - established Simulink reference-minus-measurement observations
%   - 100 Hz actor and fixed-step ode3 analytical plant at 1 kHz
%   - one 64-unit actor layer and two 2x64 critics
%   - at most ten batch-128 updates after each episode
%   - fixed ten-case capture evaluation every 50 episodes

cfg = makeFurutaMatlabSwingupOde3TD3Config();

cfg.Agent.UseDevice = "cpu";
cfg.Agent.ActorHiddenLayerSizes = 64;
cfg.Agent.CriticHiddenLayerSizes = [64 64];
cfg.Agent.LearningFrequency = -1;
cfg.Agent.MiniBatchSize = 128;
cfg.Agent.NumEpoch = 1;
cfg.Agent.MaxMiniBatchPerEpoch = 10;
cfg.Agent.NumWarmStartSteps = 1000;
cfg.Agent.ExperienceBufferLength = 1e5;

cfg.Training.MaxEpisodes = 3000;
cfg.Training.EpisodeDuration = 3;
cfg.Training.UseParallel = false;
cfg.Training.SaveAgentValue = 80;

cfg.Done.MaxSteps = ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime);
cfg.Termination = cfg.Done;
cfg.IsDone = cfg.Done;
cfg.Reward.EnableTimeout = cfg.Done.EnableTimeout;
cfg.Reward.MaxSteps = cfg.Done.MaxSteps;
cfg.Reward.CaptureBonus = 100;
cfg.Reward.UnsafePenalty = 100;
cfg.Reward.TimeoutPenalty = 10;

cfg.Training.SavePrefix = ...
    "FurutaTD3_matlab_ode3_student_100hz_actor1x64_critic2x64";
cfg.Training.RunName = "run_" + string(datetime("now", ...
    "Format", "yyyyMMdd_HHmmss")) + "_td3_matlab_ode3_student_100hz";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
