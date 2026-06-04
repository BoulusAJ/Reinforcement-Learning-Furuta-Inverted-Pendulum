cd("C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum")
addpath(genpath("scripts"))
close all
Simulink.sdi.close
Simulink.sdi.clear

cfg = makeFurutaConfig();
initFurutaModelWorkspace(cfg);

set_param(cfg.Model.Name, "FastRestart", "on")
set_param(cfg.Model.Name, "SignalLogging", "off")

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
actInfo = rlNumericSpec([1 1], ...
    LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, ...
    Name=cfg.Action.Name);

env = rlSimulinkEnv(cfg.Model.Name, cfg.Model.AgentBlock, obsInfo, actInfo);
env.ResetFcn = @localResetFcnFurutaCurriculum;

assignin("base", "curriculumParams", cfg.Curriculum(1).Reset);
assignin("base", "rewardParams", cfg.Reward);
assignin("base", "safetyParams", cfg.Safety);

agent = createDDPGAgentFuruta(obsInfo, actInfo, cfg.Agent);

trainOpts = rlTrainingOptions( ...
    MaxEpisodes=10, ...
    MaxStepsPerEpisode=ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime), ...
    StopTrainingCriteria="EpisodeCount", ...
    StopTrainingValue=20, ...
    Plots="none", ...
    Verbose=true);

tic
trainingStats = train(agent, env, trainOpts);
toc
%%
clear totalTimes execTimes initTimes termTimes
