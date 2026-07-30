%TESTFURUTAANALYTICALSWINGUPENV Short MATLAB-only environment smoke test.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
addpath(genpath(fullfile(repoRoot, "scripts")))

rng(0, "twister")
cfg = makeFurutaMatlabSwingupTD3Config();
env = createFurutaAnalyticalSwingupEnv(cfg);

validateEnvironment(env);
agent = createZeroActionDDPGAgentFuruta( ...
    getObservationInfo(env), getActionInfo(env), cfg.Agent.SampleTime);
simOptions = rlSimulationOptions(MaxSteps=100, StopOnError="on");
zeroAgentExperiences = sim(env, agent, simOptions); %#ok<NASGU>

disp("MATLAB analytical swing-up environment passed validation and 100 zero-action steps.")
