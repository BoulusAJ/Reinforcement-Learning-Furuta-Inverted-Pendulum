%CONTINUEFURUTAMATLABSWINGUPTRAINING Resume an analytical swing-up TD3 run.
%
% Configure this section, then run the script. The source run is never
% overwritten. The continued agent, evaluator checkpoints, and statistics
% are written to a new results directory.

sourceRunFolder = fullfile("results", "TD3", ...
    "run_20260730_195820_td3_matlab_ode3_student_100hz_actor1x32_critic2x32");
checkpointPreference = "final"; % "best" or "final"
additionalEpisodes = 2000;
if ~exist("startTraining", "var")
    startTraining = true; % Set false before run(...) for a read-only preview.
end

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

sourceRunFolder = localAbsolutePath(sourceRunFolder, repoRoot);
sourceAgentFile = localSelectCheckpoint(sourceRunFolder, checkpointPreference);
loaded = load(sourceAgentFile, "agent", "cfg", "evaluationSummary");
if ~isfield(loaded, "agent") || ~isfield(loaded, "cfg")
    error("Checkpoint must contain both agent and cfg: %s", sourceAgentFile);
end

agent = loaded.agent;
cfg = loaded.cfg;
if isprop(agent, "UseExplorationPolicy")
    agent.UseExplorationPolicy = true;
end

sourceRunName = string(localLastFolderName(sourceRunFolder));
resumeStamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss_SSS"));
cfg.Training.ParentRunFolder = sourceRunFolder;
cfg.Training.ResumeCheckpoint = sourceAgentFile;
cfg.Training.ResumeAdditionalEpisodes = additionalEpisodes;
cfg.Training.MaxEpisodes = additionalEpisodes;
cfg.Training.RunName = "run_" + resumeStamp + "_resume_" + ...
    erase(sourceRunName, "run_");
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_continued_final.mat";
cfg.Training.UseParallel = false;

if ~isfield(cfg.Evaluation, "RequiredConsecutivePerfect")
    cfg.Evaluation.RequiredConsecutivePerfect = 2;
end
if ~isfield(cfg.Evaluation, "CustomEvaluationFrequency")
    cfg.Evaluation.CustomEvaluationFrequency = 50;
end
cfg.Training.StopTrainingCriteria = "EvaluationStatistic";
cfg.Training.StopTrainingValue = 1.0;

usesSimulinkConvention = isfield(cfg.Observation, "ErrorConvention") && ...
    string(cfg.Observation.ErrorConvention) == "reference_minus_measurement";
if ~usesSimulinkConvention
    error(["This continuation script expects a convention-correct MATLAB " ...
        "swing-up run with Observation.ErrorConvention set to " ...
        "reference_minus_measurement."]);
end

env = createFurutaAnalyticalSwingupEnvSimulinkConvention(cfg);

if ~startTraining
    resumePreview = struct( ...
        SourceRunFolder=sourceRunFolder, ...
        SourceAgentFile=sourceAgentFile, ...
        AdditionalEpisodes=additionalEpisodes, ...
        ProposedOutputFolder=cfg.Training.OutputRoot, ...
        ActorHiddenLayerSizes=cfg.Agent.ActorHiddenLayerSizes, ...
        CriticHiddenLayerSizes=cfg.Agent.CriticHiddenLayerSizes);
    disp(resumePreview)
    return
end

mkdir(cfg.Training.OutputRoot);
mkdir(cfg.Training.ConfigDir);
mkdir(cfg.Training.SavedAgentDir);

resumeInfo = struct( ...
    SourceRunFolder=sourceRunFolder, ...
    SourceAgentFile=sourceAgentFile, ...
    CheckpointPreference=checkpointPreference, ...
    AdditionalEpisodes=additionalEpisodes, ...
    ContinuedRunFolder=cfg.Training.OutputRoot, ...
    StartTime=datetime("now"));
save(fullfile(cfg.Training.ConfigDir, "resume_info.mat"), "resumeInfo", "cfg");

fprintf("Continuing Furuta MATLAB swing-up training\n");
fprintf("Source checkpoint: %s\n", sourceAgentFile);
if isfield(loaded, "evaluationSummary")
    fprintf("Source fixed evaluation: %d/%d captures at episode %d.\n", ...
        loaded.evaluationSummary.Captured, ...
        loaded.evaluationSummary.NumCases, ...
        loaded.evaluationSummary.TrainingEpisode);
end
fprintf("Additional episodes: %d\n", additionalEpisodes);
fprintf("New output folder: %s\n", cfg.Training.OutputRoot);

trainOpts = rlTrainingOptions( ...
    MaxEpisodes=additionalEpisodes, ...
    MaxStepsPerEpisode=cfg.Done.MaxSteps, ...
    Verbose=cfg.Training.Verbose, ...
    Plots=cfg.Training.PlotMode, ...
    ScoreAveragingWindowLength=cfg.Training.ScoreAveragingWindowLength, ...
    StopTrainingCriteria=cfg.Training.StopTrainingCriteria, ...
    StopTrainingValue=cfg.Training.StopTrainingValue, ...
    SaveAgentCriteria=cfg.Training.SaveAgentCriteria, ...
    SaveAgentValue=cfg.Training.SaveAgentValue, ...
    SaveAgentDirectory=cfg.Training.SavedAgentDir, ...
    UseParallel=false);

% IMPORTANT: Keep parallel training disabled while using the custom fixed-
% case evaluator. Run independent experiments in separate MATLAB processes.
evaluator = rlCustomEvaluator( ...
    @(evaluationAgent, evaluationEnv, trainingInfo) ...
        evaluateFurutaFixedSwingupCasesDuringTraining( ...
            evaluationAgent, evaluationEnv, trainingInfo, cfg), ...
    EvaluationFrequency=cfg.Evaluation.CustomEvaluationFrequency);

trainingStats = train(agent, env, trainOpts, Evaluator=evaluator);
resumeInfo.EndTime = datetime("now");
save(fullfile(cfg.Training.OutputRoot, cfg.Training.FinalSaveName), ...
    "agent", "trainingStats", "cfg", "resumeInfo");

function absolutePath = localAbsolutePath(pathValue, repoRoot)
pathValue = string(pathValue);
[found, attributes] = fileattrib(pathValue);
if ~found
    candidate = fullfile(repoRoot, pathValue);
    [found, attributes] = fileattrib(candidate);
end
if ~found || ~attributes.directory
    error("Source run folder does not exist: %s", pathValue);
end
absolutePath = string(attributes.Name);
end

function checkpoint = localSelectCheckpoint(runFolder, preference)
preference = lower(string(preference));
bestFile = fullfile(runFolder, "best_fixed_evaluation_agent.mat");
finalFiles = dir(fullfile(runFolder, "*final.mat"));

if preference == "best"
    if isfile(bestFile)
        checkpoint = string(bestFile);
        return;
    end
    warning("Best checkpoint not found; falling back to final checkpoint.");
elseif preference ~= "final"
    error("checkpointPreference must be 'best' or 'final'.");
end

if isempty(finalFiles)
    error("No final checkpoint found in: %s", runFolder);
end
[~, newestIndex] = max([finalFiles.datenum]);
checkpoint = string(fullfile( ...
    finalFiles(newestIndex).folder, finalFiles(newestIndex).name));
end

function folderName = localLastFolderName(folderPath)
[~, folderName] = fileparts(folderPath);
end
