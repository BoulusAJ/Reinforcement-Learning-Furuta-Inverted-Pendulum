projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
startupFurutaProject();

cfg = makeFurutaMatlabSwingupTD3Config();
env = createFurutaAnalyticalSwingupEnv(cfg);

obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

% Replace this with a trained agent if desired.
% agent = createZeroActionDDPGAgentFuruta( ...
%     obsInfo, actInfo, cfg.Agent.SampleTime);
agent = createTD3AgentFuruta(obsInfo, actInfo, cfg.Agent);

numSimulations = 50;
maxSteps = cfg.Done.MaxSteps;

% Warm up MATLAB, networks, and environment.
obs = reset(env);
action = getAction(agent, obs);
step(env, action);

inferenceTime = 0;
environmentTime = 0;
totalSteps = 0;
episodeSteps = zeros(numSimulations, 1);

wallTimer = tic;

for episode = 1:numSimulations
    obs = reset(env);

    for k = 1:maxSteps
        timer = tic;
        action = getAction(agent, obs);
        inferenceTime = inferenceTime + toc(timer);

        timer = tic;
        [obs, ~, isDone, ~] = step(env, action);
        environmentTime = environmentTime + toc(timer);

        totalSteps = totalSteps + 1;
        episodeSteps(episode) = k;

        if isDone
            break;
        end
    end
end

wallTime = toc(wallTimer);
simulatedTime = totalSteps * cfg.Agent.SampleTime;

fprintf("\nBenchmark over %d simulations and %d steps\n", ...
    numSimulations, totalSteps);
fprintf("Mean episode length:       %.1f steps\n", mean(episodeSteps));
fprintf("Simulated physical time:   %.3f s\n", simulatedTime);
fprintf("Total wall time:           %.3f s\n", wallTime);

fprintf("\nAgent inference\n");
fprintf("  Total:                    %.3f s\n", inferenceTime);
fprintf("  Mean per step:            %.3f ms\n", ...
    1e3 * inferenceTime / totalSteps);
fprintf("  Share of wall time:       %.1f %%\n", ...
    100 * inferenceTime / wallTime);

fprintf("\nPlant + reward + isDone\n");
fprintf("  Total:                    %.3f s\n", environmentTime);
fprintf("  Mean per step:            %.3f ms\n", ...
    1e3 * environmentTime / totalSteps);
fprintf("  Share of wall time:       %.1f %%\n", ...
    100 * environmentTime / wallTime);

fprintf("\nOther loop overhead:        %.3f s\n", ...
    wallTime - inferenceTime - environmentTime);
fprintf("Overall real-time factor:   %.1fx\n", ...
    simulatedTime / wallTime);
