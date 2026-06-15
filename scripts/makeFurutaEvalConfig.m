function evalCfg = makeFurutaEvalConfig(cfg)
%MAKEFURUTAEVALCONFIG Fixed evaluation cases and metric settings.

if isfield(cfg.Model, "EvaluationName")
    evalCfg.ModelName = cfg.Model.EvaluationName;
else
    evalCfg.ModelName = cfg.Model.Name;
end

if isfield(cfg.Model, "EvaluationAgentBlock")
    evalCfg.AgentBlock = cfg.Model.EvaluationAgentBlock;
else
    evalCfg.AgentBlock = evalCfg.ModelName + "/RL Agent";
end
evalCfg.ProjectRoot = cfg.ProjectRoot;
evalCfg.ScriptsDir = fullfile(cfg.ProjectRoot, "scripts");
evalCfg.Ts = cfg.Model.PlantSampleTime;
evalCfg.AgentSampleTime = cfg.Agent.SampleTime;
evalCfg.Tf = cfg.Training.EpisodeDuration;
evalCfg.MaxSteps = ceil(evalCfg.Tf / cfg.Agent.SampleTime);

evalCfg.ObservationDimension = cfg.Observation.Dimension;
evalCfg.ActionName = cfg.Action.Name;
evalCfg.ActionMin = cfg.Action.Min;
evalCfg.ActionMax = cfg.Action.Max;

evalCfg.FinalWindowSeconds = 0.5;
evalCfg.SettlingTolTheta2 = deg2rad(1);
evalCfg.SettlingTolTheta1 = deg2rad(3);

evalCfg.Safety = cfg.Safety;
evalCfg.Reward = cfg.Reward;
evalCfg.ActionLimit = cfg.Action.Max;
evalCfg.CurrentLimit = cfg.Limits.CurrentMax;
evalCfg.VoltageLimit = cfg.Limits.VoltageMax;

evalCfg.TrainingCases = makeCases( ...
    [0], ...
    deg2rad([-20 -5 0 5 20]), ...
    [0], ...
    [-5 0 5], ...
    "training_validation");

evalCfg.PostStageCases = makeCases( ...
    deg2rad([-45 0 45]), ...
    deg2rad([-180 -135 -90 -45 -20 0 20 45 90 135 180]), ...
    [-5 0 5], ...
    [-10 0 10], ...
    "post_stage_full");

evalCfg.Score.failureBasePenalty = 1000;
evalCfg.Score.meanFinalTheta2MAEWeight = 20;
evalCfg.Score.maxFinalTheta2ErrorWeight = 5;
evalCfg.Score.theta2IAEWeight = 2;
evalCfg.Score.theta1IAEWeight = 0.5;
evalCfg.Score.torqueEnergyWeight = 0.1;
evalCfg.Score.actionSmoothnessWeight = 0.1;
end

function cases = makeCases(theta1ErrorList, theta2ErrorList, omega1ErrorList, omega2ErrorList, evalSetName)
caseID = 0;
rows = [];

for i = 1:numel(theta1ErrorList)
    for j = 1:numel(theta2ErrorList)
        for k = 1:numel(omega1ErrorList)
            for n = 1:numel(omega2ErrorList)
                caseID = caseID + 1;
                rows = [rows; ...
                    caseID, ...
                    theta1ErrorList(i), ...
                    theta2ErrorList(j), ...
                    omega1ErrorList(k), ...
                    omega2ErrorList(n)]; %#ok<AGROW>
            end
        end
    end
end

cases = array2table(rows, 'VariableNames', ...
    ["CaseID", "Theta1Error0", "Theta2Error0", "Omega1Error0", "Omega2Error0"]);
cases.EvalSetName = repmat(evalSetName, height(cases), 1);
end
