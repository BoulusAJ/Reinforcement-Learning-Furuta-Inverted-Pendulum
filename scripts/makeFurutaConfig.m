function cfg = makeFurutaConfig()
%MAKEFURUTACONFIG Central configuration for Furuta RL experiments.

cfg.ProjectName = "FurutaRL";

% Fill these in after the lab model details are known.
cfg.Model.Name = "inv_rot_pen_analytical_sim";
cfg.Model.AgentBlock = cfg.Model.Name + "/RL Agent";
cfg.Model.SampleTime = 1 / 20e3;

cfg.Reference.Root = fullfile(pwd, "references", "zhaw_rotary_pendulum_lab");
cfg.Reference.LabModelDir = fullfile(cfg.Reference.Root, "lab_model");
cfg.Reference.CourseLabDir = fullfile(cfg.Reference.Root, "course_lab_p5");

% Values from the ZHAW lab/course reference scripts.
cfg.Motor.R = 4.12 * 1.1;
cfg.Motor.L = 1.31e-3;
cfg.Motor.km = 97.5e-3;
cfg.Limits.VoltageMax = 24;
cfg.Limits.CurrentMax = 1;
cfg.Limits.MotorSpeedMax = 200;

% Observation convention: [theta; alpha; theta_dot; alpha_dot].
% Define alpha = 0 as upright unless the hardware/model uses another convention.
cfg.Observation.Names = ["theta", "alpha", "theta_dot", "alpha_dot"];
cfg.Observation.Dimension = 4;

% Replace with hardware-safe limits.
cfg.Action.Name = "u";
cfg.Action.Min = -1.0;
cfg.Action.Max = 1.0;

cfg.Safety.MaxAbsArmAngle = deg2rad(90);
cfg.Safety.MaxAbsPendulumAngle = deg2rad(30);
cfg.Safety.MaxAbsAngularVelocity = cfg.Limits.MotorSpeedMax;
cfg.Safety.PendulumEnableAngle = deg2rad(30);
cfg.Safety.PendulumDisableAngle = deg2rad(10);

cfg.Training.SavePrefix = "FurutaDDPG_near_upright";
cfg.Training.ResultsDir = fullfile(pwd, "results");
cfg.Training.StopTrainingCriteria = "AverageReward";
cfg.Training.StopTrainingValue = 450;
cfg.Training.ScoreAveragingWindowLength = 20;

cfg.Reward.alphaScale = deg2rad(12);
cfg.Reward.thetaScale = deg2rad(45);
cfg.Reward.velocityScale = 10.0;
cfg.Reward.lambda_u = 1e-3;
cfg.Reward.lambda_du = 5e-3;
cfg.Reward.uprightBonus = 1.0;
cfg.Reward.uprightTolerance = deg2rad(5);
cfg.Reward.unsafePenalty = 100.0;

cfg.Curriculum = makeCurriculum();
end

function stages = makeCurriculum()
stages = struct([]);

stages(1).Name = "local_small_angle";
stages(1).MaxEpisodes = 300;
stages(1).Reset.AlphaRange = deg2rad([-5 5]);
stages(1).Reset.AlphaDotRange = [-1 1];
stages(1).NoiseStd = 0.20;

stages(2).Name = "medium_angle";
stages(2).MaxEpisodes = 500;
stages(2).Reset.AlphaRange = deg2rad([-12 12]);
stages(2).Reset.AlphaDotRange = [-3 3];
stages(2).NoiseStd = 0.15;

stages(3).Name = "robust_near_upright";
stages(3).MaxEpisodes = 700;
stages(3).Reset.AlphaRange = deg2rad([-20 20]);
stages(3).Reset.AlphaDotRange = [-5 5];
stages(3).NoiseStd = 0.10;
end
