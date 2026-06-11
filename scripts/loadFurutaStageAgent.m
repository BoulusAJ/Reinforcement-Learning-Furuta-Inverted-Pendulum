function loaded = loadFurutaStageAgent(runDir, stageIndex, opts)
%LOADFURUTASTAGEAGENT Load a saved Furuta stage agent and initialize model.
%
% Example:
%   loaded = loadFurutaStageAgent( ...
%       fullfile("results", "DDPG", "run_20260604_existing_stage_results"), 1);

arguments
    runDir {mustBeTextScalar}
    stageIndex (1,1) double {mustBeInteger, mustBePositive}
    opts.AssignToBase (1,1) logical = true
    opts.LoadModel (1,1) logical = true
    opts.RunInBackground (1,1) logical = true
end

runDir = string(runDir);
stagePattern = sprintf("Furuta*_stage_%02d_*.mat", stageIndex);
stageFiles = dir(fullfile(runDir, "stages", stagePattern));

if isempty(stageFiles)
    error("loadFurutaStageAgent:StageFileNotFound", ...
        "No stage %02d file found in %s", stageIndex, fullfile(runDir, "stages"));
elseif numel(stageFiles) > 1
    error("loadFurutaStageAgent:AmbiguousStageFile", ...
        "Multiple stage %02d files found in %s", stageIndex, fullfile(runDir, "stages"));
end

stagePath = fullfile(stageFiles(1).folder, stageFiles(1).name);
S = load(stagePath);

requiredFields = ["agent", "cfg", "stage"];
for i = 1:numel(requiredFields)
    if ~isfield(S, requiredFields(i))
        error("loadFurutaStageAgent:MissingField", ...
            "Stage file is missing required field: %s", requiredFields(i));
    end
end

cfg = S.cfg;
agent = S.agent;
stage = S.stage;

initFurutaModelWorkspace(cfg, AssignToBase=opts.AssignToBase);

if opts.AssignToBase
    assignin("base", "agent", agent);
    assignin("base", "cfg", cfg);
    assignin("base", "stage", stage);
    assignin("base", "curriculumParams", stage.Reset);
    assignin("base", "rewardParams", cfg.Reward);
    assignin("base", "safetyParams", cfg.Safety);

    if isfield(S, "evalCfg")
        assignin("base", "evalCfg", S.evalCfg);
    end
    if isfield(S, "postStageEval")
        assignin("base", "postStageEval", S.postStageEval);
    end
    if isfield(S, "trainingStats")
        assignin("base", "trainingStats", S.trainingStats);
    end
end

if opts.LoadModel
    if opts.RunInBackground
        load_system(cfg.Model.Name);
    else
        open_system(cfg.Model.Name);
    end
end

loaded = S;
loaded.StageFile = stagePath;
loaded.RunDir = runDir;
end
