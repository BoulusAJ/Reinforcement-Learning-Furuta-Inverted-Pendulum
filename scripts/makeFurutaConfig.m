function cfg = makeFurutaConfig()
%MAKEFURUTACONFIG Central configuration for Furuta RL experiments.

cfg.ProjectName = "FurutaRL";

paths = getFurutaPaths();
cfg.ProjectRoot = paths.ProjectRoot;
cfg.ResultsRoot = paths.ResultsRoot;

% Keep a stripped model for training and a richer model for evaluation and
% signal inspection. cfg.Model.Name remains the training/default model for
% compatibility with older helper scripts.
cfg.Model.TrainingName = "inv_rot_pen_RL_cntr_simscape_sim_train";
cfg.Model.EvaluationName = "inv_rot_pen_RL_cntr_simscape_sim";
cfg.Model.Name = cfg.Model.TrainingName;
cfg.Model.TrainingAgentBlock = cfg.Model.TrainingName + "/RL Agent";
cfg.Model.EvaluationAgentBlock = cfg.Model.EvaluationName + "/RL Agent";
cfg.Model.AgentBlock = cfg.Model.TrainingAgentBlock;
cfg.Model.PlantSampleTime = 1 / 20e3;

cfg.Agent.Algorithm = "TD3";
cfg.Agent.UseDevice = "gpu";
cfg.Agent.SampleTime = 5e-3;
cfg.Agent.LearningFrequency = -1;
cfg.Agent.PolicyUpdateFrequency = 2;
cfg.Agent.TargetUpdateFrequency = 2;
cfg.Agent.MiniBatchSize = 1024;
cfg.Agent.ExperienceBufferLength = 1e6;
cfg.Agent.NumWarmStartSteps = 1024;
cfg.Agent.NumEpoch = 10;
cfg.Agent.MaxMiniBatchPerEpoch = 100;
cfg.Agent.TargetSmoothFactor = 5e-3;
cfg.Agent.TargetPolicyNoiseStd = 0.20;
cfg.Agent.TargetPolicyNoiseLimit = 0.50;
cfg.Agent.ExplorationNoiseStd = 0.50;
cfg.Agent.ExplorationNoiseStdMin = 0.05;
cfg.Agent.ExplorationNoiseDecayRate = 1e-6;
cfg.Agent.ActorLearnRate = 2e-3;
cfg.Agent.CriticLearnRate = 5e-3;
cfg.Agent.GradientThreshold = 1;

cfg.Reference.Root = fullfile(cfg.ProjectRoot, "references", "zhaw_rotary_pendulum_lab");
cfg.Reference.LabModelDir = fullfile(cfg.Reference.Root, "lab_model");
cfg.Reference.CourseLabDir = fullfile(cfg.Reference.Root, "course_lab_p5");

% Values from the ZHAW lab/course reference scripts.
cfg.Motor.R = 4.12 * 1.1;
cfg.Motor.L = 1.31e-3;
cfg.Motor.km = 97.5e-3;
cfg.Limits.SupplyVoltage = 24;
cfg.Limits.PwmOffset = 0.09;
cfg.Limits.VoltageMax = cfg.Limits.SupplyVoltage * (1 - cfg.Limits.PwmOffset);
cfg.Limits.CurrentMax = 4;
cfg.Limits.MotorSpeedMax = 200;

% Observation convention for direct swing-up RL:
% [sin(theta1Error); cos(theta1Error);
%  sin(theta2Error); cos(theta2Error);
%  omega1Error; omega2Error; previousAction].
% This keeps the classical error-to-zero interpretation while avoiding angle
% wrap discontinuities. theta2Error follows the hardware state-space
% controller convention:
% theta2Error = -atan2(sin(theta2 - pi), cos(theta2 - pi)).
cfg.Observation.Names = [ ...
    "sinTheta1Error", "cosTheta1Error", ...
    "sinTheta2Error", "cosTheta2Error", ...
    "omega1Error", "omega2Error", ...
    "previousAction"];
cfg.Observation.Dimension = 7;
cfg.Observation.AngularVelocityScale = 25;

% RL action is normalized signed effort in [-1, 1]. Map it outside the
% agent to the selected physical interface, e.g. current or torque.
cfg.Action.Name = "a_rl";
cfg.Action.Min = -1.0;
cfg.Action.Max = 1.0;
cfg.Action.IsNormalized = true;
cfg.Action.PhysicalInterface = "torque_or_current";
cfg.Action.CurrentScale = cfg.Limits.CurrentMax;
cfg.Action.TorqueScale = cfg.Motor.km * cfg.Limits.CurrentMax;

cfg.Safety.MaxAbsArmAngle = deg2rad(90);
cfg.Safety.MaxAbsPendulumAngle = pi;
cfg.Safety.MaxAbsAngularVelocity = cfg.Limits.MotorSpeedMax;
cfg.Safety.PendulumEnableAngle = deg2rad(30);
cfg.Safety.PendulumDisableAngle = deg2rad(10);

cfg.Training.SavePrefix = "Furuta" + cfg.Agent.Algorithm + "_direct_swingup";
cfg.Training.ResultsDir = fullfile(cfg.ResultsRoot, cfg.Agent.Algorithm);
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_" + lower(cfg.Agent.Algorithm) + "_direct_swingup";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
cfg.Training.EpisodeDuration = 5;
cfg.Training.StopTrainingCriteria = "AverageReward";
cfg.Training.StopTrainingValue = 450;
cfg.Training.ScoreAveragingWindowLength = 20;
cfg.Training.Verbose = true;
cfg.Training.PlotMode = "none";
cfg.Training.RunInBackground = true;
cfg.Training.DisableScopes = true;
cfg.Training.DisableSignalLogging = true;
cfg.Training.UseFastRestart = false;
cfg.Training.UseParallel = false;
cfg.Training.RequestedWorkers = 10;
cfg.Training.ParallelMode = "async";
cfg.Training.StepsUntilDataIsSent = 1000; %32; % parallel only

cfg.Evaluation.UsePostStageEvaluation = true;
cfg.Evaluation.UseCustomEvaluatorDuringTraining = false;
cfg.Evaluation.UseStandardEvaluatorDuringTraining = false;

cfg.Reward.RewardMode = 1;
cfg.Reward.theta2Weight = 1.0;
cfg.Reward.theta2Scale = deg2rad(15);
cfg.Reward.theta1Weight = 0.1;
cfg.Reward.theta1Scale = deg2rad(30);
cfg.Reward.omega1Weight = 0.05;
cfg.Reward.omega1Scale = 5.0;
cfg.Reward.omega2Weight = 0.02;
cfg.Reward.omega2Scale = 5.0;
cfg.Reward.AngularVelocityScale = cfg.Observation.AngularVelocityScale;
cfg.Reward.lambda_u = 1e-3;
cfg.Reward.lambda_du = 3e-2;
cfg.Reward.duWarmupSteps = 1;
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

cfg.Curriculum = makeCurriculum();
end

function stages = makeCurriculum()
stages = struct([]);

stages(1).Name = "near_upright_stabilization";
stages(1).MaxEpisodes = 800;
stages(1).Reset.Theta1ErrorRange = deg2rad([0 0]);
stages(1).Reset.Theta2ErrorRange = deg2rad([-5 5]);
stages(1).Reset.Omega1ErrorRange = [0 0];
stages(1).Reset.Omega2ErrorRange = [-1 1];
stages(1).NoiseStd = 0.10;

stages(2).Name = "medium_upright_recovery";
stages(2).MaxEpisodes = 500;
stages(2).Reset.Theta1ErrorRange = deg2rad([-10 10]);
stages(2).Reset.Theta2ErrorRange = deg2rad([-25 25]);
stages(2).Reset.Omega1ErrorRange = [-2 2];
stages(2).Reset.Omega2ErrorRange = [-5 5];
stages(2).NoiseStd = 0.20;

stages(3).Name = "large_angle_recovery";
stages(3).MaxEpisodes = 1000;
stages(3).Reset.Theta1ErrorRange = deg2rad([-20 20]);
stages(3).Reset.Theta2ErrorRange = deg2rad([-90 90]);
stages(3).Reset.Omega1ErrorRange = [-5 5];
stages(3).Reset.Omega2ErrorRange = [-10 10];
stages(3).NoiseStd = 0.30;

stages(4).Name = "full_swingup";
stages(4).MaxEpisodes = 2000;
stages(4).Reset.Theta1ErrorRange = deg2rad([-45 45]);
stages(4).Reset.Theta2ErrorRange = deg2rad([-180 180]);
stages(4).Reset.Omega1ErrorRange = [-8 8];
stages(4).Reset.Omega2ErrorRange = [-12 12];
stages(4).NoiseStd = 0.35;
end
