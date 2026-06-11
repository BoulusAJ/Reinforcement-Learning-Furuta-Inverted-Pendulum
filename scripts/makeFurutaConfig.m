function cfg = makeFurutaConfig()
%MAKEFURUTACONFIG Central configuration for Furuta RL experiments.

cfg.ProjectName = "FurutaRL";

scriptDir = fileparts(mfilename("fullpath"));
cfg.ProjectRoot = fileparts(scriptDir);

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
cfg.Agent.SampleTime = 1e-3;
cfg.Agent.LearningFrequency = 40;
cfg.Agent.PolicyUpdateFrequency = 2;
cfg.Agent.TargetUpdateFrequency = 2;
cfg.Agent.MiniBatchSize = 64;
cfg.Agent.ExperienceBufferLength = 2e5;
cfg.Agent.NumWarmStartSteps = 5000;
cfg.Agent.TargetSmoothFactor = 5e-3;
cfg.Agent.TargetPolicyNoiseStd = 0.10;
cfg.Agent.TargetPolicyNoiseLimit = 0.30;

cfg.Reference.Root = fullfile(cfg.ProjectRoot, "references", "zhaw_rotary_pendulum_lab");
cfg.Reference.LabModelDir = fullfile(cfg.Reference.Root, "lab_model");
cfg.Reference.CourseLabDir = fullfile(cfg.Reference.Root, "course_lab_p5");

% Values from the ZHAW lab/course reference scripts.
cfg.Motor.R = 4.12 * 1.1;
cfg.Motor.L = 1.31e-3;
cfg.Motor.km = 97.5e-3;
cfg.Limits.VoltageMax = 24;
cfg.Limits.CurrentMax = 4;
cfg.Limits.MotorSpeedMax = 200;

% Observation convention for RL:
% [theta1Error; theta2Error; omega1Error; omega2Error].
% These are post-summation feedback-controller error signals.
% theta2Error follows the hardware state-space controller convention:
% theta2Error = -atan2(sin(theta2 - pi), cos(theta2 - pi)).
cfg.Observation.Names = ["theta1Error", "theta2Error", "omega1Error", "omega2Error"];
cfg.Observation.Dimension = 4;

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
cfg.Safety.MaxAbsPendulumAngle = deg2rad(30);
cfg.Safety.MaxAbsAngularVelocity = cfg.Limits.MotorSpeedMax;
cfg.Safety.PendulumEnableAngle = deg2rad(30);
cfg.Safety.PendulumDisableAngle = deg2rad(10);

cfg.Training.SavePrefix = "Furuta" + cfg.Agent.Algorithm + "_near_upright";
cfg.Training.ResultsDir = fullfile(cfg.ProjectRoot, "results", cfg.Agent.Algorithm);
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_" + lower(cfg.Agent.Algorithm) + "_upright_stabilization";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
cfg.Training.EpisodeDuration = 1;
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
cfg.Training.StepsUntilDataIsSent = 32;

cfg.Evaluation.UsePostStageEvaluation = true;
cfg.Evaluation.UseCustomEvaluatorDuringTraining = false;
cfg.Evaluation.UseStandardEvaluatorDuringTraining = false;

cfg.Reward.theta2Scale = deg2rad(12);
cfg.Reward.theta1Scale = deg2rad(45);
cfg.Reward.velocityScale = 10.0;
cfg.Reward.lambda_u = 1e-3;
cfg.Reward.lambda_du = 5e-2;
cfg.Reward.aliveBonus = 0.1;
cfg.Reward.uprightBonus = 1.0;
cfg.Reward.uprightTolerance = deg2rad(5);
cfg.Reward.unsafePenalty = 1000.0;

cfg.Curriculum = makeCurriculum();
end

function stages = makeCurriculum()
stages = struct([]);

stages(1).Name = "local_small_angle";
stages(1).MaxEpisodes = 300;
stages(1).Reset.Theta1ErrorRange = deg2rad([0 0]);
stages(1).Reset.Theta2ErrorRange = deg2rad([-5 5]);
stages(1).Reset.Omega1ErrorRange = [0 0];
stages(1).Reset.Omega2ErrorRange = [-1 1];
stages(1).NoiseStd = 0.05;

stages(2).Name = "medium_angle";
stages(2).MaxEpisodes = 500;
stages(2).Reset.Theta1ErrorRange = deg2rad([0 0]);
stages(2).Reset.Theta2ErrorRange = deg2rad([-12 12]);
stages(2).Reset.Omega1ErrorRange = [0 0];
stages(2).Reset.Omega2ErrorRange = [-3 3];
stages(2).NoiseStd = 0.15;

stages(3).Name = "robust_near_upright";
stages(3).MaxEpisodes = 700;
stages(3).Reset.Theta1ErrorRange = deg2rad([0 0]);
stages(3).Reset.Theta2ErrorRange = deg2rad([-20 20]);
stages(3).Reset.Omega1ErrorRange = [0 0];
stages(3).Reset.Omega2ErrorRange = [-5 5];
stages(3).NoiseStd = 0.10;
end
