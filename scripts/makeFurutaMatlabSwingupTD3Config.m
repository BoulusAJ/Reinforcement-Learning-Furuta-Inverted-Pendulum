function cfg = makeFurutaMatlabSwingupTD3Config()
%MAKEFURUTAMATLABSWINGUPTD3CONFIG Fast MATLAB-only analytical prototype.

cfg = makeFurutaSwingupCaptureTD3Config();

actionDiffReferenceSampleTime = cfg.Agent.SampleTime;
cfg.Agent.SampleTime = 0.01; % 100 Hz policy
cfg.Agent.UseDevice = "cpu";
cfg.Agent.ExperienceBufferLength = 5e5;
cfg.Agent.LearningFrequency = -1; % bounded learning burst after each episode
cfg.Agent.MiniBatchSize = 256;
cfg.Agent.NumWarmStartSteps = 1000;
cfg.Agent.NumEpoch = 1;
cfg.Agent.MaxMiniBatchPerEpoch = 25;

cfg.MatlabEnvironment.IntegrationStep = 0.001; % 1 kHz RK4 plant
ratio = cfg.Agent.SampleTime / cfg.MatlabEnvironment.IntegrationStep;
cfg.MatlabEnvironment.Substeps = round(ratio);
if abs(ratio - cfg.MatlabEnvironment.Substeps) > 1e-12
    error("Agent.SampleTime must be an integer multiple of IntegrationStep.");
end

if isfield(cfg, "Reference") && isfolder(cfg.Reference.LabModelDir)
    addpath(cfg.Reference.LabModelDir);
end
cfg.MatlabEnvironment.Param = get_parameter();

% Physical-angle reset convention: theta2=0 is hanging down.
cfg.MatlabEnvironment.Reset.Theta1Range = deg2rad([-5 5]);
cfg.MatlabEnvironment.Reset.Theta2Range = deg2rad([-5 5]);
cfg.MatlabEnvironment.Reset.Omega1Range = [-0.25 0.25];
cfg.MatlabEnvironment.Reset.Omega2Range = [-0.25 0.25];

cfg.Done.MaxSteps = ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime);
cfg.Termination = cfg.Done;
cfg.IsDone = cfg.Done;
cfg.Reward = localCopyCaptureFields(cfg.Reward, cfg.Done);
% ActionDiffWeight was tuned at the inherited 500 Hz sample time. The
% reward function scales it with Ts so changing Agent.SampleTime here keeps
% the relative continuous-time action-rate penalty approximately constant.
cfg.Reward.ActionDiffReferenceSampleTime = actionDiffReferenceSampleTime;
cfg.Reward.AgentSampleTime = cfg.Agent.SampleTime;

cfg.Training.UseParallel = false;
cfg.Training.UseFastRestart = false;
cfg.Training.SaveAgentValue = 300;
cfg.Training.SavePrefix = "FurutaTD3_matlab_analytical_100hz_fast_actor1x64_critic2x64";
cfg.Training.RunName = "run_" + string(datetime("now", ...
    "Format", "yyyyMMdd_HHmmss")) + "_td3_matlab_analytical_100hz_fast";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end

function reward = localCopyCaptureFields(reward, done)
fields = ["KCapture", "PCapture", "RhoCapture", "CurrentLimit", ...
    "Theta1Guard", "Theta2Guard", "Omega1Guard", "Omega2Guard", ...
    "ObservationOmegaIsScaled", "ObservationOmegaScale", ...
    "EnableTimeout", "MaxSteps"];
for idx = 1:numel(fields)
    reward.(fields(idx)) = done.(fields(idx));
end
end
