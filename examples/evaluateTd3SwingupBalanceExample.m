%% Evaluate the included TD3 swing-up-and-balance agent in Simulink

scriptDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(scriptDir);
addpath(projectRoot);
cd(projectRoot)
paths = startupFurutaProject();
agentFile = fullfile(paths.ProjectRoot, "approaches", ...
    "td3_swingup_balance", "agents", "FurutaTD3_500Hz_long_final.mat");
modelName = "inv_rot_pen_RL_cntr_simscape_sim_1b_analytical_active";
modelFile = fullfile(paths.ProjectRoot, "approaches", ...
    "td3_swingup_balance", "models", modelName + ".slx");

saved = load(agentFile, "agent");
agent = saved.agent;
cfg = makeFurutaMathWorksStylePICurrent1b500HzLongTD3Config();
cfg.Model.Name = modelName;
cfg.Model.EvaluationName = modelName;
cfg.Model.EvaluationFile = modelFile;
cfg.Model.AgentBlock = modelName + "/RL Agent";
cfg.Model.EvaluationAgentBlock = cfg.Model.AgentBlock;

initFurutaModelWorkspace(cfg, AssignToBase=true, ...
    InitialTheta=[0; 0], InitialOmega=[0; 0]);
assignin("base", "agent", agent);
assignin("base", "cfg", cfg);
assignin("base", "rewardParams", cfg.Reward);
assignin("base", "safetyParams", cfg.Safety);

load_system(modelFile);
simulationOutput = sim(modelName); %#ok<NASGU>
