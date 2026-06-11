function prepareFurutaTrainingModel(cfg, opts)
%PREPAREFURUTATRAININGMODEL Create a stripped Simulink model for training.
%
% The evaluation model keeps scopes and rich logged signals for inspection.
% The training model is a copy with Scope blocks removed and signal logging
% disabled to reduce UI/logging overhead during long RL training runs.

arguments
    cfg struct = makeFurutaConfig()
    opts.Overwrite (1,1) logical = false
    opts.RemoveScopes (1,1) logical = true
    opts.DisableSignalLogging (1,1) logical = true
end

evalModel = cfg.Model.EvaluationName;
trainModel = cfg.Model.TrainingName;

evalPath = fullfile(cfg.ProjectRoot, "scripts", evalModel + ".slx");
trainPath = fullfile(cfg.ProjectRoot, "scripts", trainModel + ".slx");

if ~isfile(evalPath)
    error("prepareFurutaTrainingModel:MissingEvaluationModel", ...
        "Evaluation model file does not exist: %s", evalPath);
end

if isfile(trainPath) && ~opts.Overwrite
    fprintf("Training model already exists: %s\n", trainPath);
    fprintf("Use Overwrite=true to refresh it from %s.\n", evalPath);
    return;
end

if bdIsLoaded(evalModel)
    close_system(evalModel, 0);
end
if bdIsLoaded(trainModel)
    close_system(trainModel, 0);
end

copyfile(evalPath, trainPath, "f");
load_system(trainModel);

if opts.DisableSignalLogging
    set_param(trainModel, SignalLogging="off");
    disableLineLogging(trainModel);
end

if opts.RemoveScopes
    removeScopeBlocks(trainModel);
end

save_system(trainModel);
close_system(trainModel, 0);

fprintf("Prepared training model: %s\n", trainPath);
end

function disableLineLogging(modelName)
lines = find_system(modelName, ...
    FindAll="on", ...
    Type="line");

for idx = 1:numel(lines)
    try
        set_param(lines(idx), DataLogging="off");
    catch
    end
end
end

function removeScopeBlocks(modelName)
scopes = find_system(modelName, ...
    LookUnderMasks="all", ...
    FollowLinks="on", ...
    BlockType="Scope");

for idx = 1:numel(scopes)
    try
        delete_block(scopes{idx});
    catch err
        warning("prepareFurutaTrainingModel:ScopeDeleteFailed", ...
            "Could not delete Scope block %s: %s", scopes{idx}, err.message);
    end
end
end
