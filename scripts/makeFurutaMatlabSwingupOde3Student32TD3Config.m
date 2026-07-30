function cfg = makeFurutaMatlabSwingupOde3Student32TD3Config()
%MAKEFURUTAMATLABSWINGUPODE3STUDENT32TD3CONFIG 32-neuron laptop experiment.
%
% This restores the successful run's learning workload while reducing the
% actor and critic widths. It trains from scratch using the established
% Simulink observation convention and ode3-equivalent analytical plant.

cfg = makeFurutaMatlabSwingupOde3StudentTD3Config();

cfg.Agent.UseDevice = "cpu";
cfg.Agent.ActorHiddenLayerSizes = 32;
cfg.Agent.CriticHiddenLayerSizes = [32 32];
cfg.Agent.LearningFrequency = -1;
cfg.Agent.MiniBatchSize = 256;
cfg.Agent.NumEpoch = 1;
cfg.Agent.MaxMiniBatchPerEpoch = 25;
cfg.Agent.NumWarmStartSteps = 1000;
cfg.Agent.ExperienceBufferLength = 5e5;

cfg.Training.MaxEpisodes = 6000;
cfg.Training.EpisodeDuration = 5;
cfg.Training.UseParallel = false;
cfg.Training.StopTrainingCriteria = "EvaluationStatistic";
cfg.Training.StopTrainingValue = 1.0;

cfg.Done.MaxSteps = ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime);
cfg.Termination = cfg.Done;
cfg.IsDone = cfg.Done;
cfg.Reward.EnableTimeout = cfg.Done.EnableTimeout;
cfg.Reward.MaxSteps = cfg.Done.MaxSteps;

cfg.Evaluation.RequiredConsecutivePerfect = 2;

cfg.Training.SavePrefix = ...
    "FurutaTD3_matlab_ode3_student_100hz_actor1x32_critic2x32";
cfg.Training.RunName = "run_" + string(datetime("now", ...
    "Format", "yyyyMMdd_HHmmss")) ...
    + "_td3_matlab_ode3_student_100hz_actor1x32_critic2x32";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
