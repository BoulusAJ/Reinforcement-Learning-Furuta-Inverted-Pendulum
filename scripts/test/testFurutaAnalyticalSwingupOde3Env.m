%TESTFURUTAANALYTICALSWINGUPODE3ENV Validate convention and environment.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
addpath(genpath(fullfile(repoRoot, "scripts")))

rng(0, "twister")
cfg = makeFurutaMatlabSwingupOde3TD3Config();
cfg.MatlabEnvironment.Reset.Theta1Range = deg2rad(10) * [1 1];
cfg.MatlabEnvironment.Reset.Theta2Range = deg2rad(20) * [1 1];
cfg.MatlabEnvironment.Reset.Omega1Range = 2 * [1 1];
cfg.MatlabEnvironment.Reset.Omega2Range = -3 * [1 1];
env = createFurutaAnalyticalSwingupEnvSimulinkConvention(cfg);

[obs, ~] = reset(env);
expected = [ ...
    sin(deg2rad(-10)); cos(deg2rad(-10)); ...
    sin(deg2rad(160)); cos(deg2rad(160)); ...
    -2 / 25; 3 / 25; 0];
assert(max(abs(obs - expected)) < 1e-12, ...
    "Observation does not follow the Simulink error convention.");

validateEnvironment(env);
agent = createZeroActionDDPGAgentFuruta( ...
    getObservationInfo(env), getActionInfo(env), cfg.Agent.SampleTime);
sim(env, agent, rlSimulationOptions(MaxSteps=100, StopOnError="on"));

disp("Simulink-convention ode3 MATLAB environment passed validation.")
