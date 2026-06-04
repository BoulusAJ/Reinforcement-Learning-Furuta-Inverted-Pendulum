function evalCfg = makeFurutaEvalConfig(cfg)
%MAKEFURUTAEVALCONFIG Fixed evaluation cases and metric settings.

evalCfg.ModelName = cfg.Model.Name;
evalCfg.AgentBlock = cfg.Model.AgentBlock;
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
evalCfg.ActionLimit = cfg.Action.Max;
evalCfg.CurrentLimit = cfg.Limits.CurrentMax;
evalCfg.VoltageLimit = cfg.Limits.VoltageMax;

evalCfg.TrainingCases = makeCases( ...
    [0], ...
    deg2rad([-5 -2 0 2 5]), ...
    [0], ...
    [-1 0 1], ...
    "training_validation");

evalCfg.PostStageCases = makeCases( ...
    deg2rad([0]), ...
    deg2rad([-20 -12 -5 0 5 12 20]), ...
    [0], ...
    [-5 -2 0 2 5], ...
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
