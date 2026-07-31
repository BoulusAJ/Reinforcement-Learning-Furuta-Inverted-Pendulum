%EVALUATEFURUTAMATLABSWINGUPAGENT Evaluate one analytical swing-up rollout.
%
% Edit the values in this section and run the script again.
% Angle convention:
%   theta2 = 0 deg   -> pendulum hanging down
%   theta2 = 180 deg -> pendulum upright


theta1InitialDeg = 0;
theta2InitialDeg = 0;
omega1Initial = 0; % rad/s
omega2Initial = 0; % rad/s

% Policy update rate for evaluation. The agent was trained at 100 Hz.
% Set this to 20 to test the existing policy with a 50 ms zero-order hold.
% A value assigned before running this script is preserved for batch tests.
if ~exist("evaluationAgentHz", "var")
    evaluationAgentHz = 100;
end

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(fileparts(scriptDir)));
addpath(repoRoot);
cd(repoRoot)
startupFurutaProject();
paths = getFurutaPaths(ProjectRoot=repoRoot);
if ~exist("agentFile", "var") || strlength(string(agentFile)) == 0
    agentFile = fullfile(repoRoot, "approaches", ...
        "td3_swingup_lqr_balance", "agents", ...
        "FurutaTD3_swingup_100Hz_final.mat");
end

loaded = load(agentFile, "agent", "cfg");
if ~isfield(loaded, "agent")
    error("Agent file does not contain a variable named 'agent': %s", agentFile);
end
agent = loaded.agent;
if isfield(loaded, "cfg")
    cfg = loaded.cfg;
else
    warning("Saved file has no cfg variable; using the current MATLAB configuration.");
    cfg = makeFurutaMatlabSwingupTD3Config();
end

cfg.Agent.SampleTime = 1 / evaluationAgentHz;
ratio = cfg.Agent.SampleTime / cfg.MatlabEnvironment.IntegrationStep;
cfg.MatlabEnvironment.Substeps = round(ratio);
if abs(ratio - cfg.MatlabEnvironment.Substeps) > 1e-12
    error("Evaluation agent period must be an integer multiple of the plant step.");
end
cfg.Done.MaxSteps = ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime);
cfg.Termination = cfg.Done;
cfg.IsDone = cfg.Done;
cfg.Reward.AgentSampleTime = cfg.Agent.SampleTime;

cfg.MatlabEnvironment.Reset.Theta1Range = deg2rad(theta1InitialDeg) * [1 1];
cfg.MatlabEnvironment.Reset.Theta2Range = deg2rad(theta2InitialDeg) * [1 1];
cfg.MatlabEnvironment.Reset.Omega1Range = omega1Initial * [1 1];
cfg.MatlabEnvironment.Reset.Omega2Range = omega2Initial * [1 1];

usesSimulinkConvention = isfield(cfg.Observation, "ErrorConvention") && ...
    string(cfg.Observation.ErrorConvention) == "reference_minus_measurement";
if usesSimulinkConvention
    env = createFurutaAnalyticalSwingupEnvSimulinkConvention(cfg);
else
    env = createFurutaAnalyticalSwingupEnv(cfg);
end
maxSteps = cfg.Done.MaxSteps;
Ts = cfg.Agent.SampleTime;

state = zeros(maxSteps + 1, 4);
action = zeros(maxSteps, 1);
currentCommand = zeros(maxSteps, 1);
reward = zeros(maxSteps, 1);

[observation, info] = reset(env);
state(1, :) = info.State(:)';
isDone = false;

for stepIndex = 1:maxSteps
    selectedAction = getAction(agent, observation);
    action(stepIndex) = localScalarAction(selectedAction);

    [observation, reward(stepIndex), isDone, info] = step(env, selectedAction);
    state(stepIndex + 1, :) = info.State(:)';
    currentCommand(stepIndex) = info.LastCurrentCommand;

    if isDone
        break;
    end
end

numSteps = stepIndex;
state = state(1:numSteps + 1, :);
action = action(1:numSteps);
currentCommand = currentCommand(1:numSteps);
reward = reward(1:numSteps);
stateTime = (0:numSteps)' * Ts;
stepTime = (1:numSteps)' * Ts;

% Simulink From Workspace signals for comparison with the Simulink plant.
% Current is applied from the beginning of each agent interval and held with
% zero-order interpolation. Plant output columns are:
% [theta1(rad), theta2(rad), omega1(rad/s), omega2(rad/s)].
currentTime = (0:numSteps - 1)' * Ts;
furutaMatlabCurrentCommand = timeseries( ...
    [currentCommand; currentCommand(end)], ...
    [currentTime; stateTime(end)], ...
    Name="currentCommand_A");
furutaMatlabCurrentCommand = setinterpmethod( ...
    furutaMatlabCurrentCommand, "zoh");

furutaMatlabPlantOutputs = timeseries( ...
    state, stateTime, Name="theta1_theta2_omega1_omega2");
furutaMatlabPlantOutputs = setinterpmethod( ...
    furutaMatlabPlantOutputs, "linear");

furutaMatlabTheta1 = timeseries(state(:, 1), stateTime, Name="theta1_rad");
furutaMatlabTheta2 = timeseries(state(:, 2), stateTime, Name="theta2_rad");
furutaMatlabOmega1 = timeseries(state(:, 3), stateTime, Name="omega1_rad_s");
furutaMatlabOmega2 = timeseries(state(:, 4), stateTime, Name="omega2_rad_s");

captured = isDone && isfield(info.LastDiagnosis, "captured") && ...
    info.LastDiagnosis.captured;
if captured
    outcome = "LQR capture region reached";
elseif isDone && isfield(info.LastDiagnosis, "timeout") && info.LastDiagnosis.timeout
    outcome = "Episode timeout";
elseif isDone
    outcome = "Safety termination";
else
    outcome = "Maximum step count reached";
end

fprintf("Agent: %s\n", agentFile);
fprintf("Initial state: theta1=%.2f deg, theta2=%.2f deg, omega1=%.2f rad/s, omega2=%.2f rad/s\n", ...
    theta1InitialDeg, theta2InitialDeg, omega1Initial, omega2Initial);
fprintf("Policy evaluation rate: %.1f Hz (ZOH %.3f s)\n", ...
    evaluationAgentHz, cfg.Agent.SampleTime);
if usesSimulinkConvention
    fprintf("Observation convention: Simulink reference-minus-measurement; integrator: ode3.\n");
else
    fprintf("Observation convention: legacy MATLAB positive-state signs; integrator: RK4.\n");
end
fprintf("Outcome: %s at %.3f s; return = %.3f\n", ...
    outcome, stateTime(end), sum(reward));

stateFigure = figure(Name="Furuta Swing-Up States", Color="w");
stateLayout = tiledlayout(stateFigure, 4, 1, TileSpacing="compact", Padding="compact");
stateAxes = gobjects(4, 1);

stateAxes(1) = nexttile(stateLayout);
plot(stateTime, rad2deg(state(:, 1)), LineWidth=1.2);
ylabel("theta1 (deg)");
grid on

stateAxes(2) = nexttile(stateLayout);
plot(stateTime, rad2deg(state(:, 2)), LineWidth=1.2);
ylabel("theta2 (deg)");
grid on

stateAxes(3) = nexttile(stateLayout);
plot(stateTime, state(:, 3), LineWidth=1.2);
ylabel("omega1 (rad/s)");
grid on

stateAxes(4) = nexttile(stateLayout);
plot(stateTime, state(:, 4), LineWidth=1.2);
ylabel("omega2 (rad/s)");
xlabel("Time (s)");
grid on
linkaxes(stateAxes, "x");
title(stateLayout, "Analytical swing-up: " + outcome);

currentFigure = figure(Name="Furuta Swing-Up Current", Color="w");
currentAxes = axes(currentFigure);
stairs(currentAxes, stepTime, currentCommand, LineWidth=1.2);
yline(currentAxes, cfg.Limits.CurrentMax, ":", "Current limit");
yline(currentAxes, -cfg.Limits.CurrentMax, ":");
xlabel(currentAxes, "Time (s)");
ylabel(currentAxes, "Current command (A)");
title(currentAxes, "RL current command");
grid(currentAxes, "on");

rewardFigure = figure(Name="Furuta Swing-Up Reward", Color="w");
rewardAxes = axes(rewardFigure);
plot(rewardAxes, stepTime, reward, LineWidth=1.2);
xlabel(rewardAxes, "Time (s)");
ylabel(rewardAxes, "Reward per step");
title(rewardAxes, sprintf("Reward, total = %.3f", sum(reward)));
grid(rewardAxes, "on");

if captured
    captureTime = stateTime(end);
    for axisHandle = [stateAxes; currentAxes; rewardAxes]'
        xline(axisHandle, captureTime, "--k", "LQR controller takes over", ...
            LabelOrientation="horizontal", LabelVerticalAlignment="middle");
    end
end

evaluationResult = struct( ...
    AgentFile=agentFile, Outcome=outcome, Captured=captured, ...
    Time=stateTime, StepTime=stepTime, State=state, Action=action, ...
    CurrentCommand=currentCommand, Reward=reward, TotalReward=sum(reward), ...
    FinalDiagnosis=info.LastDiagnosis, ...
    CurrentCommandTimeseries=furutaMatlabCurrentCommand, ...
    PlantOutputsTimeseries=furutaMatlabPlantOutputs);

function value = localScalarAction(action)
if iscell(action)
    action = action{1};
end
value = double(action(1));
end

function agentPath = localNewestFinalAgent(resultsRoot)
pattern = fullfile(resultsRoot, "TD3", ...
    "run_*_td3_matlab_analytical_*", "*final.mat");
files = dir(pattern);
if isempty(files)
    error("No MATLAB analytical final agent found. Set agentFile explicitly.");
end
[~, newestIndex] = max([files.datenum]);
agentPath = string(fullfile(files(newestIndex).folder, files(newestIndex).name));
end
