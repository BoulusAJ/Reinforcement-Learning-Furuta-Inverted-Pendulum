function cfg = makeFurutaMathWorksStyleTD3Config()
%MAKEFURUTAMATHWORKSSTYLETD3CONFIG Config for the no-curriculum TD3 run.
%
% This intentionally mirrors the MathWorks Quanser QUBE TD3 example more
% closely than the staged direct-swing-up curriculum.

cfg = makeFurutaConfig();

cfg.Agent.Algorithm = "TD3";
cfg.Agent.UseDevice = "cpu";
cfg.Agent.NetworkStyle = "default";
cfg.Agent.NumHiddenUnit = 64;
cfg.Agent.SampleTime = 5e-3;
cfg.Agent.LearningFrequency = -1;
cfg.Agent.PolicyUpdateFrequency = 2;
cfg.Agent.TargetUpdateFrequency = 2;
cfg.Agent.MiniBatchSize = 1024;
cfg.Agent.ExperienceBufferLength = 1e6;
cfg.Agent.NumWarmStartSteps = 1024;
cfg.Agent.NumEpoch = 10;
cfg.Agent.MaxMiniBatchPerEpoch = 100;
cfg.Agent.ActorLearnRate = 2e-3;
cfg.Agent.CriticLearnRate = 5e-3;
cfg.Agent.GradientThreshold = 1;
cfg.Agent.ExplorationNoiseStd = 0.5;
cfg.Agent.ExplorationNoiseStdMin = 0.05;
cfg.Agent.ExplorationNoiseDecayRate = 1e-6;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
cfg.Training.EpisodeDuration = 5;
cfg.Training.MaxEpisodes = 2000;
cfg.Training.StopTrainingCriteria = "none";
cfg.Training.StopTrainingValue = [];
cfg.Training.ScoreAveragingWindowLength = 10;
cfg.Training.UseParallel = true;
cfg.Training.RequestedWorkers = 22;
cfg.Training.ParallelMode = "async";
cfg.Training.StepsUntilDataIsSent = 1000;
cfg.Training.SaveAgentCriteria = "EpisodeReward";
cfg.Training.SaveAgentValue = 700;

cfg.Training.Reset.Name = "mathworks_style_random_upright";
cfg.Training.Reset.Theta1ErrorRange = deg2rad([-45 45]);
cfg.Training.Reset.Theta2ErrorRange = deg2rad([-45 45]);
cfg.Training.Reset.Omega1ErrorRange = [0 0];
cfg.Training.Reset.Omega2ErrorRange = [0 0];

cfg.Evaluation.UsePostStageEvaluation = false;
cfg.Evaluation.UseShortEvaluation = true;
cfg.Evaluation.UseFullEvaluation = true;
cfg.Evaluation.UseParallel = true;
cfg.Evaluation.RequestedWorkers = cfg.Training.RequestedWorkers;
cfg.Evaluation.AllowPoolRestart = false;

cfg.Reward = struct();
cfg.Reward.RewardMode = 2;
cfg.Reward.theta2Weight = 1.0;
cfg.Reward.theta2Scale = deg2rad(15);
cfg.Reward.theta1Weight = 0.1;
cfg.Reward.theta1Scale = deg2rad(30);
cfg.Reward.omega1Weight = 0.05;
cfg.Reward.omega1Scale = 5.0;
cfg.Reward.omega2Weight = 0.02;
cfg.Reward.omega2Scale = 5.0;
cfg.Reward.lambda_u = 1e-3;
cfg.Reward.lambda_du = 3e-2;
cfg.Reward.aliveBonus = 0.02;
cfg.Reward.uprightBonus = 0.2;
cfg.Reward.uprightTolerance = deg2rad(8);
cfg.Reward.unsafePenalty = 10.0;
cfg.Reward.aliveReward = 1.0;
cfg.Reward.costWeight = 0.1;
cfg.Reward.angularVelocityWeight = 1e-2;
cfg.Reward.actionSmoothnessWeight = 0.3;
cfg.Reward.aliveTheta1Limit = cfg.Safety.MaxAbsArmAngle;
cfg.Reward.aliveOmega1Limit = 30.0;
cfg.Reward.duWarmupSteps = 1;
end
