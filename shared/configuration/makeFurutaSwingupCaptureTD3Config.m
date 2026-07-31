function cfg = makeFurutaSwingupCaptureTD3Config()
%MAKEFURUTASWINGUPCAPTURETD3CONFIG TD3 swing-up into LQR capture region.
%
% Training target:
%   RL swing-up only -> terminate when the state is inside a conservative
%   LQR capture ellipsoid. Balancing is left to the existing LQR lab.

cfg = makeFurutaMathWorksStylePICurrent1b500HzLongActor1x64Critic2x64TD3Config();

modelName = "inv_rot_pen_RL_swingup_1_train";
cfg.Model.TrainingName = modelName;
cfg.Model.EvaluationName = modelName;
cfg.Model.Name = modelName;
modelDir = fullfile(cfg.ProjectRoot, "approaches", ...
    "td3_swingup_lqr_balance", "models");
cfg.Model.TrainingFile = fullfile(modelDir, modelName + ".slx");
cfg.Model.EvaluationFile = cfg.Model.TrainingFile;
cfg.Model.TrainingAgentBlock = modelName + "/RL Agent";
cfg.Model.EvaluationAgentBlock = cfg.Model.TrainingAgentBlock;
cfg.Model.AgentBlock = cfg.Model.TrainingAgentBlock;

cfg.Limits.CurrentMax = 1.5;
cfg.Action.PhysicalInterface = "current";
cfg.Action.CurrentScale = cfg.Limits.CurrentMax;
cfg.Action.TorqueScale = cfg.Motor.km * cfg.Limits.CurrentMax;

cfg.Observation.Names = [ ...
    "sinTheta1Error", "cosTheta1Error", ...
    "sinTheta2Error", "cosTheta2Error", ...
    "omega1ErrorScaled", "omega2ErrorScaled", ...
    "previousAction"];
cfg.Observation.Dimension = 7;
cfg.Observation.OmegaScale = 25;
cfg.Observation.AngularVelocityScale = cfg.Observation.OmegaScale;
cfg.Observation.OmegaClip = 25;

cfg.Safety.MaxAbsArmAngle = deg2rad(90);
cfg.Safety.MaxAbsPendulumAngle = pi;
cfg.Safety.MaxAbsAngularVelocity = cfg.Observation.OmegaClip;

cfg.Agent.NetworkStyle = "custom_mlp";
cfg.Agent.ActorHiddenLayerSizes = 64;
cfg.Agent.CriticHiddenLayerSizes = [64 64];
cfg.Agent.NetworkDescription = "custom_mlp_actor_1x64_critic2x64_swingup_capture";

cfg.Training.UseParallel = false;
cfg.Training.UseFastRestart = true;
cfg.Training.MaxEpisodes = 5000;
cfg.Training.EpisodeDuration = 5;
cfg.Training.ScoreAveragingWindowLength = 20;
cfg.Training.StopTrainingCriteria = "EpisodeCount";
cfg.Training.StopTrainingValue = cfg.Training.MaxEpisodes;
cfg.Training.SaveAgentCriteria = "EpisodeReward";
cfg.Training.SaveAgentValue = 1800;
cfg.Training.RunInBackground = true;
cfg.Training.DisableScopes = true;
cfg.Training.DisableSignalLogging = true;
cfg.Training.Reset.Name = "swingup_capture_wide_random";
cfg.Training.Reset.Theta1ErrorRange = deg2rad([-30 30]);
cfg.Training.Reset.Theta2ErrorRange = deg2rad([-180 180]);
cfg.Training.Reset.Omega1ErrorRange = [-3 3];
cfg.Training.Reset.Omega2ErrorRange = [-6 6];

cfg.Evaluation.UsePostStageEvaluation = false;
cfg.Evaluation.UseCustomEvaluatorDuringTraining = false;
cfg.Evaluation.UseStandardEvaluatorDuringTraining = false;
cfg.Evaluation.UseShortEvaluation = false;
cfg.Evaluation.UseFullEvaluation = false;
cfg.Evaluation.UseParallel = false;

cfg.Done = makeSwingupCaptureDoneParams(cfg);
cfg.Termination = cfg.Done;
cfg.IsDone = cfg.Done;

cfg.Reward = cfg.Done;
cfg.Reward.ProgressWeight = 1.0;
cfg.Reward.Theta1Weight = 0.08;
cfg.Reward.Theta1Scale = deg2rad(35);
cfg.Reward.Omega1Weight = 0.02;
cfg.Reward.Omega1Scale = 10;
cfg.Reward.Omega2NearWeight = 0.08;
cfg.Reward.Omega2Scale = 8;
cfg.Reward.NearUprightAngle = deg2rad(35);
cfg.Reward.ActionWeight = 2e-3;
cfg.Reward.ActionDiffWeight = 2e-2;
cfg.Reward.CaptureBonus = 25;
cfg.Reward.UnsafePenalty = 25;
cfg.Reward.duWarmupSteps = 1;

cfg.Training.SavePrefix = "FurutaTD3_swingup_capture_actor1x64_critic2x64";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_swingup_capture_actor1x64_critic2x64";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end

function doneParams = makeSwingupCaptureDoneParams(cfg)
if isfield(cfg, "Reference") && isfield(cfg.Reference, "LabModelDir") && ...
        isfolder(cfg.Reference.LabModelDir)
    addpath(cfg.Reference.LabModelDir);
end

param = get_parameter();
[A, B] = linearize_furuta_equilibrium([0; pi], param);
B = B * param.km;
Q = diag([1 10 0.001 0.001]);
R = 0.5 * 10;
[K, P] = lqr(A, B, Q, R);

rhoMaxCurrent = cfg.Limits.CurrentMax^2 / (K * (P \ K'));
rhoCapture = min(0.10, 0.5 * rhoMaxCurrent);

doneParams = struct();
doneParams.KCapture = K;
doneParams.PCapture = P;
doneParams.RhoCapture = rhoCapture;
doneParams.CurrentLimit = cfg.Limits.CurrentMax;
doneParams.RhoMaxCurrent = rhoMaxCurrent;
doneParams.RhoCurrentLimit = rhoMaxCurrent;
doneParams.Theta1Guard = deg2rad(45);
doneParams.Theta2Guard = deg2rad(30);
doneParams.Omega1Guard = 12;
doneParams.Omega2Guard = 12;
doneParams.ObservationUsesSinCos = true;
doneParams.ObservationOmegaIsScaled = true;
doneParams.ObservationOmegaScale = cfg.Observation.OmegaScale;
doneParams.EnableTimeout = true;
doneParams.MaxSteps = ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime);
end
