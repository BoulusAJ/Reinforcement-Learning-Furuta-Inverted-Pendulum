%% Train Furuta direct TD3 with 1c PI/current path at 500 Hz long, arc observations
% Weto-input follow-up: actor 1x64, critic 2x64, reduced arc-distance
% observation vector in the 1c Simulink models.

addpath(genpath("scripts"))
cfg = makeFurutaMathWorksStylePICurrent1c500HzLongActor1x64Critic2x64ArcObsTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
