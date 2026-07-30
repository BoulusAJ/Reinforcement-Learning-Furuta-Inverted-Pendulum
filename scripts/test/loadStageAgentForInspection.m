%% Load a saved stage agent for inspection

cd("C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum")
addpath(genpath("scripts"))

runDir = furutaResultsPath("DDPG", "run_20260604_existing_stage_results");
stageIndex = 1;

loaded = loadFurutaStageAgent(runDir, stageIndex);

agent = loaded.agent;
cfg = loaded.cfg;
stage = loaded.stage;

%% Optional simulation

simOut = sim(cfg.Model.Name, StopTime=string(cfg.Training.EpisodeDuration));
