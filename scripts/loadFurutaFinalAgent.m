function loaded = loadFurutaFinalAgent(runDir, opts)
%LOADFURUTAFINALAGENT Load a final Furuta agent and initialize Simulink.
%
% Example:
%   loaded = loadFurutaFinalAgent(fullfile("results", "TD3", ...
%       "run_20260616_012625_td3_mathworks_style_wide"));

arguments
    runDir {mustBeTextScalar}
    opts.FinalFile {mustBeTextScalar} = ""
    opts.AssignToBase (1,1) logical = true
    opts.LoadModel (1,1) logical = true
    opts.OpenModel (1,1) logical = false
    opts.ModelRole (1,1) string {mustBeMember(opts.ModelRole, ["evaluation", "training", "base"])} = "evaluation"
    opts.InitialTheta (2,1) double = [0; pi + pi/9]
    opts.InitialOmega (2,1) double = [0; 0]
end

runDir = string(runDir);

if strlength(opts.FinalFile) > 0
    finalPath = fullfile(runDir, string(opts.FinalFile));
else
    finalFiles = dir(fullfile(runDir, "*_final.mat"));
    if isempty(finalFiles)
        error("loadFurutaFinalAgent:FinalFileNotFound", ...
            "No *_final.mat file found in %s", runDir);
    elseif numel(finalFiles) > 1
        error("loadFurutaFinalAgent:AmbiguousFinalFile", ...
            "Multiple *_final.mat files found in %s. Use FinalFile to choose one.", runDir);
    end
    finalPath = fullfile(finalFiles(1).folder, finalFiles(1).name);
end

S = load(finalPath);

requiredFields = ["agent", "cfg"];
for i = 1:numel(requiredFields)
    if ~isfield(S, requiredFields(i))
        error("loadFurutaFinalAgent:MissingField", ...
            "Final file is missing required field: %s", requiredFields(i));
    end
end

cfg = S.cfg;
agent = S.agent;

initFurutaModelWorkspace(cfg, ...
    AssignToBase=opts.AssignToBase, ...
    InitialTheta=opts.InitialTheta, ...
    InitialOmega=opts.InitialOmega);

if opts.AssignToBase
    assignin("base", "agent", agent);
    assignin("base", "cfg", cfg);
    assignin("base", "runDir", runDir);
    assignin("base", "finalAgentPath", finalPath);
    assignin("base", "curriculumParams", cfg.Training.Reset);
    assignin("base", "rewardParams", cfg.Reward);
    assignin("base", "safetyParams", cfg.Safety);

    if isfield(S, "evalCfg")
        assignin("base", "evalCfg", S.evalCfg);
    end
    if isfield(S, "evalLog")
        assignin("base", "evalLog", S.evalLog);
    end
    if isfield(S, "trainingStats")
        assignin("base", "trainingStats", S.trainingStats);
    end
end

modelName = selectModelName(cfg, opts.ModelRole);
modelFile = selectModelFile(cfg, opts.ModelRole);
if opts.LoadModel
    if opts.OpenModel
        openModel(modelName, modelFile);
    else
        loadModel(modelName, modelFile);
    end
end

loaded = S;
loaded.FinalFile = finalPath;
loaded.RunDir = runDir;
loaded.ModelName = modelName;
loaded.ModelFile = modelFile;
end

function modelName = selectModelName(cfg, modelRole)
switch modelRole
    case "evaluation"
        if isfield(cfg.Model, "EvaluationName")
            modelName = cfg.Model.EvaluationName;
        else
            modelName = cfg.Model.Name;
        end
    case "training"
        if isfield(cfg.Model, "TrainingName")
            modelName = cfg.Model.TrainingName;
        else
            modelName = cfg.Model.Name;
        end
    otherwise
        modelName = cfg.Model.Name;
end
end

function modelFile = selectModelFile(cfg, modelRole)
modelFile = "";
switch modelRole
    case "evaluation"
        if isfield(cfg.Model, "EvaluationFile")
            modelFile = string(cfg.Model.EvaluationFile);
        end
    case "training"
        if isfield(cfg.Model, "TrainingFile")
            modelFile = string(cfg.Model.TrainingFile);
        end
    otherwise
        if isfield(cfg.Model, "TrainingFile")
            modelFile = string(cfg.Model.TrainingFile);
        end
end
end

function loadModel(modelName, modelFile)
if strlength(modelFile) > 0 && isfile(modelFile)
    load_system(modelFile);
else
    load_system(modelName);
end
end

function openModel(modelName, modelFile)
if strlength(modelFile) > 0 && isfile(modelFile)
    open_system(modelFile);
else
    open_system(modelName);
end
end
