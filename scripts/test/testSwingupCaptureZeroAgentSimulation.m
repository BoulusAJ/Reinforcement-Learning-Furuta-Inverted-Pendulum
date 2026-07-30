%% Smoke-test inv_rot_pen_RL_swingup_1_train with a zero-action agent.
% This uses the same training cfg as trainFurutaSwingupCaptureTD3, but does
% not train. It only checks that the model, observation/action specs,
% rewardParams, doneParams, safetyParams, and reset path are wired correctly.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

cfg = makeFurutaSwingupCaptureTD3Config();
cfg.Training.UseFastRestart = true;
cfg.Training.DisableSignalLogging = false;

% Fixed non-capture reset. With theta2Error = 170 deg, raw theta2 starts
% close to the downward position because localResetFcnFurutaCurriculum uses:
%   theta2_0 = pi - theta2Error0
cfg.Training.Reset.mode = "fixed";
cfg.Training.Reset.Theta1Error0 = 0;
cfg.Training.Reset.Theta2Error0 = deg2rad(170);
cfg.Training.Reset.Omega1Error0 = 0;
cfg.Training.Reset.Omega2Error0 = 0;

initFurutaModelWorkspace(cfg, ...
    InitialTheta=[0; pi - cfg.Training.Reset.Theta2Error0], ...
    InitialOmega=[0; 0]);

assignin("base", "curriculumParams", cfg.Training.Reset);
assignin("base", "rewardParams", cfg.Reward);
assignin("base", "doneParams", cfg.Done);
assignin("base", "isDoneParams", cfg.Done);
assignin("base", "terminationParams", cfg.Done);
assignin("base", "captureParams", cfg.Done);
assignin("base", "safetyParams", cfg.Safety);

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
actInfo = rlNumericSpec([1 1], ...
    LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, ...
    Name=cfg.Action.Name);

agent = createZeroActionDDPGAgentFuruta(obsInfo, actInfo, cfg.Agent.SampleTime);
assignin("base", "agent", agent);

if isfield(cfg.Model, "TrainingFile")
    load_system(cfg.Model.TrainingFile);
else
    load_system(cfg.Model.TrainingName);
end

if strcmp(get_param(cfg.Model.Name, "FastRestart"), "on")
    set_param(cfg.Model.Name, FastRestart="off");
end
set_param(cfg.Model.Name, FastRestart="on");
set_param(cfg.Model.Name, SignalLogging="on", SignalLoggingName="logsout");

env = rlSimulinkEnv(cfg.Model.TrainingName, cfg.Model.TrainingAgentBlock, obsInfo, actInfo);
env.ResetFcn = @localResetFcnFurutaCurriculum;

simOpts = rlSimulationOptions( ...
    MaxSteps=ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime), ...
    StopOnError="on");

experiences = sim(env, agent, simOpts);
assignin("base", "zeroAgentSmokeTestExperiences", experiences);

fprintf("Zero-agent smoke test finished for %s.\n", cfg.Model.TrainingName);
fprintf("MaxSteps: %d, Ts: %.6g s, CurrentMax: %.3g A, RhoCapture: %.6g\n", ...
    simOpts.MaxSteps, cfg.Agent.SampleTime, cfg.Limits.CurrentMax, cfg.Done.RhoCapture);
