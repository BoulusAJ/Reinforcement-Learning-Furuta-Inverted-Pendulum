%% Prepare MATLAB-trained agent for Simulink evaluation

scriptDir = fullfile(pwd, "scripts");
addpath(genpath(scriptDir));

%% Select agent and Simulink model

agentFile = fullfile( ...
    "results", "TD3", ...
    "run_20260728_153540_td3_matlab_analytical_100hz_fast", ...
    "FurutaTD3_matlab_analytical_100hz_fast_actor1x64_critic2x64_final.mat");

modelName = "inv_rot_pen_RL_swingup_1_train";
modelFile = fullfile("scripts", modelName + ".slx");

saved = load(agentFile, "agent", "cfg");
agent = saved.agent;
cfg = saved.cfg;

% Point the saved MATLAB-training configuration at the Simulink model.
cfg.Model.Name = modelName;
cfg.Model.TrainingName = modelName;
cfg.Model.EvaluationName = modelName;
cfg.Model.TrainingFile = modelFile;
cfg.Model.EvaluationFile = modelFile;
cfg.Model.TrainingAgentBlock = modelName + "/RL Agent";
cfg.Model.EvaluationAgentBlock = cfg.Model.TrainingAgentBlock;
cfg.Model.AgentBlock = cfg.Model.TrainingAgentBlock;

%% Initial physical state

% Angle convention:
%   theta2 = 0       hanging down
%   theta2 = pi      upright
theta1_0 = deg2rad(0);
theta2_0 = deg2rad(0);
omega1_0 = 0;                 % rad/s
omega2_0 = 0;                 % rad/s

theta0 = [theta1_0; theta2_0];
omega0 = [omega1_0; omega2_0];

% Existing Simulink reset/error convention.
theta1Error0 = -theta1_0;
theta2Error0 = pi - theta2_0;
omega1Error0 = -omega1_0;
omega2Error0 = -omega2_0;

%% Initialize all standard model parameters

ws = initFurutaModelWorkspace(cfg, ...
    AssignToBase=true, ...
    InitialTheta=theta0, ...
    InitialOmega=omega0);

% Main structures expected by the MATLAB Function blocks.
rewardParams = cfg.Reward;
doneParams = cfg.Done;
safetyParams = cfg.Safety;

% Aliases used by different model revisions.
isDoneParams = doneParams;
terminationParams = doneParams;
captureParams = doneParams;

% Mechanical/electrical parameter structure.
param = ws.param;
params = param;  % Optional alias if a block uses "params".

% Explicitly retain the trained interface.
currentMax = cfg.Limits.CurrentMax;  % 1.5 A
agentTs = cfg.Agent.SampleTime;      % 0.01 s = 100 Hz
plantTs = cfg.Model.PlantSampleTime; % 20 kHz plant model

%% Fixed reset structure, useful with rlSimulinkEnv

curriculumParams = struct();
curriculumParams.mode = "fixed";
curriculumParams.Theta1Error0 = theta1Error0;
curriculumParams.Theta2Error0 = theta2Error0;
curriculumParams.Omega1Error0 = omega1Error0;
curriculumParams.Omega2Error0 = omega2Error0;

%% Agent specifications and diagnostic bus

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], ...
    Name="observations");

actInfo = rlNumericSpec([1 1], ...
    LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, ...
    Name=cfg.Action.Name);

FurutaRewardDiagnosisBus = createFurutaRewardDiagnosisBus( ...
    AssignToBase=true);

%% Assign everything explicitly to the base workspace

variables = {
    "agent", agent
    "cfg", cfg
    "param", param
    "params", params
    "theta0", theta0
    "omega0", omega0
    "theta1_0", theta1_0
    "theta2_0", theta2_0
    "omega1_0", omega1_0
    "omega2_0", omega2_0
    "theta1Error0", theta1Error0
    "theta2Error0", theta2Error0
    "omega1Error0", omega1Error0
    "omega2Error0", omega2Error0
    "rewardParams", rewardParams
    "doneParams", doneParams
    "isDoneParams", isDoneParams
    "terminationParams", terminationParams
    "captureParams", captureParams
    "safetyParams", safetyParams
    "curriculumParams", curriculumParams
    "obsInfo", obsInfo
    "actInfo", actInfo
    "currentMax", currentMax
    "agentTs", agentTs
    "plantTs", plantTs
    };

for index = 1:size(variables, 1)
    assignin("base", variables{index, 1}, variables{index, 2});
end

%% Load model

load_system(modelFile);

fprintf("Prepared %s\n", modelName);
fprintf("Agent Ts: %.4f s (%.0f Hz)\n", agentTs, 1/agentTs);
fprintf("Current limit: %.2f A\n", currentMax);
fprintf("Initial state: [%.1f deg, %.1f deg, %.2f, %.2f]\n", ...
    rad2deg(theta1_0), rad2deg(theta2_0), omega1_0, omega2_0);
fprintf("Capture rho: %.6f\n", doneParams.RhoCapture);