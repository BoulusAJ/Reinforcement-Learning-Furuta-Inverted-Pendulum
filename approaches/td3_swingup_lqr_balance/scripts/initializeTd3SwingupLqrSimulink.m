function ws = initializeTd3SwingupLqrSimulink(options)
%INITIALIZETD3SWINGUPLQRSIMULINK Prepare the included Simulink evaluation.

arguments
    options.InitialTheta (2,1) double = [0; 0]
    options.InitialOmega (2,1) double = [0; 0]
    options.OpenModel (1,1) logical = true
end

scriptDir = fileparts(mfilename("fullpath"));
approachDir = fileparts(scriptDir);
projectRoot = fileparts(fileparts(approachDir));

addpath(projectRoot);
startupFurutaProject();

agentFile = fullfile(approachDir, "agents", ...
    "FurutaTD3_swingup_100Hz_final.mat");
modelName = "inv_rot_pen_RL_swingup_1_test_agent_alt";
modelFile = fullfile(approachDir, "models", modelName + ".slx");

saved = load(agentFile, "agent", "cfg");
cfg = saved.cfg;
cfg.ProjectRoot = string(projectRoot);
cfg.Reference.Root = fullfile(projectRoot, "shared");
cfg.Reference.LabModelDir = fullfile(projectRoot, "shared", "plant");
cfg.Reference.CourseLabDir = "";
cfg.Model.Name = modelName;
cfg.Model.TrainingName = modelName;
cfg.Model.EvaluationName = modelName;
cfg.Model.TrainingFile = modelFile;
cfg.Model.EvaluationFile = modelFile;
cfg.Model.AgentBlock = modelName + "/RL Agent";
cfg.Model.TrainingAgentBlock = cfg.Model.AgentBlock;
cfg.Model.EvaluationAgentBlock = cfg.Model.AgentBlock;

ws = initFurutaModelWorkspace(cfg, ...
    AssignToBase=false, ...
    InitialTheta=options.InitialTheta, ...
    InitialOmega=options.InitialOmega);
ws.agent = saved.agent;
ws.agentFile = agentFile;
ws.modelFile = modelFile;

% The model also contains optional From Workspace inputs for comparing a
% MATLAB rollout with Simulink. Zero placeholders let the model compile when
% that comparison data has not been generated yet.
zeroComparisonSignal = timeseries([0; 0], [0; 1]);
ws.furutaMatlabCurrentCommand = zeroComparisonSignal;
ws.furutaMatlabTheta1 = zeroComparisonSignal;
ws.furutaMatlabTheta2 = zeroComparisonSignal;
ws.furutaMatlabOmega1 = zeroComparisonSignal;
ws.furutaMatlabOmega2 = zeroComparisonSignal;

names = fieldnames(ws);
for idx = 1:numel(names)
    assignin("base", names{idx}, ws.(names{idx}));
end

load_system(modelFile);
if options.OpenModel
    open_system(modelName);
end

fprintf("Initialized %s\n", modelName);
fprintf("Agent: %s\n", agentFile);
fprintf("theta0 = [%g; %g] rad, omega0 = [%g; %g] rad/s\n", ...
    ws.theta0(1), ws.theta0(2), ws.omega0(1), ws.omega0(2));
end
