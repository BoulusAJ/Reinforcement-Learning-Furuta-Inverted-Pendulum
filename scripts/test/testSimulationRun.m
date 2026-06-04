cd("C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum")
addpath(genpath("scripts"))

cfg = makeFurutaConfig();
%initFurutaModelWorkspace(cfg, InitialTheta=[0; pi + deg2rad(0.1)]);
initFurutaModelWorkspace(cfg, InitialTheta=[0; pi]);

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
actInfo = rlNumericSpec([1 1], ...
    LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, ...
    Name=cfg.Action.Name);

agent = createZeroActionDDPGAgentFuruta(obsInfo, actInfo, cfg.Agent.SampleTime);
assignin("base", "agent", agent);

open_system(cfg.Model.Name)
set_param(cfg.Model.Name, "FastRestart", "on")
simOut = sim(cfg.Model.Name, StopTime=string(cfg.Training.EpisodeDuration));

%%
set_param(cfg.Model.Name, "FastRestart", "on")
for i = 1:10
    simOut = sim(cfg.Model.Name, StopTime=string(cfg.Training.EpisodeDuration));
    simOut.SimulationMetadata.TimingInfo.InitializationElapsedWallTime
end