function result = evaluateFurutaController(agent, env, cases, evalCfg, opts)
%EVALUATEFURUTACONTROLLER Evaluate a Furuta controller on fixed cases.

arguments
    agent
    env
    cases table
    evalCfg struct
    opts.ControllerName string = "controller"
    opts.EvalSetName string = "eval"
    opts.StageIndex double = NaN
    opts.StageName string = ""
    opts.TrainingEpisode double = NaN
    opts.RunInBackground (1,1) logical = true
    opts.CloseModelWhenDone (1,1) logical = false
    opts.UseFastRestart (1,1) logical = true
    opts.UseParallel (1,1) logical = false
    opts.RequestedWorkers double = NaN
    opts.AllowPoolRestart (1,1) logical = false
end

metrics = table();
metadata = struct( ...
    "ControllerName", opts.ControllerName, ...
    "EvalSetName", opts.EvalSetName, ...
    "StageIndex", opts.StageIndex, ...
    "StageName", opts.StageName, ...
    "TrainingEpisode", opts.TrainingEpisode);

simOpts = rlSimulationOptions( ...
    MaxSteps=evalCfg.MaxSteps, ...
    StopOnError="on");

if opts.UseParallel
    setupParallelPool(opts.RequestedWorkers, opts.AllowPoolRestart);
    parallelUseFastRestart = false;

    if opts.UseFastRestart
        warning("evaluateFurutaController:FastRestartDisabledForParallel", ...
            "Fast Restart is disabled for parallel fixed-case evaluation to avoid worker build/cache conflicts.");
    end

    q = parallel.pool.DataQueue;
    afterEach(q, @(i) fprintf('Finished evaluating case: %d\n', i));


    metricsCell = cell(height(cases), 1);
    parfor i = 1:height(cases)
        caseMetrics = evaluateOneCaseParallel(agent, cases(i, :), evalCfg, simOpts, parallelUseFastRestart);
        metricsCell{i} = addMetadata(caseMetrics, metadata);
        send(q, i);  % notify client
    end

    for i = 1:numel(metricsCell)
        metrics = [metrics; metricsCell{i}]; %#ok<AGROW>
    end
else
    oldResetFcn = env.ResetFcn;
    modelState = prepareModelForEvaluation(evalCfg, opts);
    cleanupObj = onCleanup(@() restoreEnvironment(env, oldResetFcn, evalCfg, modelState));

    for i = 1:height(cases)
        disp("Evaluating case: ", i)
        fixedReset = makeFixedReset(cases(i, :));

        assignin("base", "curriculumParams", fixedReset);
        assignin("base", "rewardParams", evalCfg.Reward);
        assignin("base", "safetyParams", evalCfg.Safety);
        env.ResetFcn = @localResetFcnFurutaCurriculum;

        experiences = sim(env, agent, simOpts);
        caseMetrics = computeFurutaMetrics(experiences, cases(i, :), evalCfg);
        metrics = [metrics; addMetadata(caseMetrics, metadata)]; %#ok<AGROW>
    end
end

summary = summarizeFurutaMetrics(metrics);
summary.ControllerName = opts.ControllerName;
summary.EvalSetName = opts.EvalSetName;
summary.StageIndex = opts.StageIndex;
summary.StageName = opts.StageName;
summary.TrainingEpisode = opts.TrainingEpisode;
summary.EvaluatedAt = datetime("now");

result = struct();
result.metrics = metrics;
result.summary = summary;
result.cases = cases;
result.evalCfg = evalCfg;
end

function modelState = prepareModelForEvaluation(evalCfg, opts)
modelState = struct();
modelState.wasLoaded = false;
modelState.shouldClose = false;
modelState.oldStopTime = "";
modelState.oldFastRestart = "";
modelState.oldSignalLogging = "";
modelState.oldSignalLoggingName = "";

if ~isfield(evalCfg, "ModelName")
    return;
end

modelState.wasLoaded = bdIsLoaded(evalCfg.ModelName);
if ~modelState.wasLoaded && opts.RunInBackground
    loadEvaluationModel(evalCfg);
    modelState.shouldClose = opts.CloseModelWhenDone;
elseif ~modelState.wasLoaded
    openEvaluationModel(evalCfg);
    modelState.shouldClose = opts.CloseModelWhenDone;
end

modelState.oldStopTime = get_param(evalCfg.ModelName, "StopTime");
modelState.oldFastRestart = get_param(evalCfg.ModelName, "FastRestart");
modelState.oldSignalLogging = get_param(evalCfg.ModelName, "SignalLogging");
modelState.oldSignalLoggingName = get_param(evalCfg.ModelName, "SignalLoggingName");

if strcmp(modelState.oldFastRestart, "on")
    set_param(evalCfg.ModelName, FastRestart="off");
end

set_param(evalCfg.ModelName, StopTime=num2str(evalCfg.Tf));
set_param(evalCfg.ModelName, SignalLogging="on", SignalLoggingName="logsout");

if opts.UseFastRestart
    set_param(evalCfg.ModelName, FastRestart="on");
end
end

function restoreEnvironment(env, oldResetFcn, evalCfg, modelState)
env.ResetFcn = oldResetFcn;

if isfield(evalCfg, "ModelName")
    if strlength(string(modelState.oldFastRestart)) > 0
        set_param(evalCfg.ModelName, FastRestart="off");
    end

    if strlength(string(modelState.oldStopTime)) > 0
        set_param(evalCfg.ModelName, StopTime=modelState.oldStopTime);
    end

    if strlength(string(modelState.oldSignalLogging)) > 0
        set_param(evalCfg.ModelName, SignalLogging=modelState.oldSignalLogging);
    end

    if strlength(string(modelState.oldSignalLoggingName)) > 0
        set_param(evalCfg.ModelName, SignalLoggingName=modelState.oldSignalLoggingName);
    end

    if strlength(string(modelState.oldFastRestart)) > 0
        set_param(evalCfg.ModelName, FastRestart=modelState.oldFastRestart);
    end

    if modelState.shouldClose
        close_system(evalCfg.ModelName, 0);
    end
end
end

function fixedReset = makeFixedReset(caseRow)
fixedReset = struct();
fixedReset.mode = "fixed";
fixedReset.Theta1Error0 = caseRow.Theta1Error0;
fixedReset.Theta2Error0 = caseRow.Theta2Error0;
fixedReset.Omega1Error0 = caseRow.Omega1Error0;
fixedReset.Omega2Error0 = caseRow.Omega2Error0;
end

function caseMetrics = addMetadata(caseMetrics, metadata)
caseMetrics.ControllerName = metadata.ControllerName;
caseMetrics.EvalSetName(:) = metadata.EvalSetName;
caseMetrics.StageIndex = metadata.StageIndex;
caseMetrics.StageName = metadata.StageName;
caseMetrics.TrainingEpisode = metadata.TrainingEpisode;
caseMetrics.EvaluatedAt = datetime("now");
end

function setupParallelPool(requestedWorkers, allowPoolRestart)
pool = gcp("nocreate");

if isempty(pool)
    if isnan(requestedWorkers)
        parpool("Processes");
    else
        parpool("Processes", requestedWorkers);
    end
    return;
end

if ~isnan(requestedWorkers) && pool.NumWorkers ~= requestedWorkers
    if allowPoolRestart
        delete(pool);
        parpool("Processes", requestedWorkers);
    else
        warning("evaluateFurutaController:ParallelPoolSizeMismatch", ...
            "Using existing pool with %d workers instead of requested %d workers.", ...
            pool.NumWorkers, requestedWorkers);
    end
end
end

function caseMetrics = evaluateOneCaseParallel(agent, caseRow, evalCfg, simOpts, useFastRestart)
persistent workerEnv workerModelName workerInitialized oldFileGenConfig

addpath(evalCfg.ScriptsDir);

if isempty(workerInitialized) || ~workerInitialized
    oldFileGenConfig = configureWorkerFileGeneration(evalCfg);
    cfg = makeFurutaConfig();
    initFurutaModelWorkspace(cfg);
    assignin("base", "rewardParams", evalCfg.Reward);
    assignin("base", "safetyParams", evalCfg.Safety);
    workerInitialized = true;
end

loadEvaluationModel(evalCfg);

% Parallel workers can collide while building accelerator/JIT artifacts for
% the same model. Keep worker simulations in normal mode unless this is
% deliberately revisited with per-worker accelerator builds.
set_param(evalCfg.ModelName, SimulationMode="normal");

if useFastRestart && ~strcmp(get_param(evalCfg.ModelName, "FastRestart"), "on")
    set_param(evalCfg.ModelName, FastRestart="on");
elseif ~useFastRestart && strcmp(get_param(evalCfg.ModelName, "FastRestart"), "on")
    set_param(evalCfg.ModelName, FastRestart="off");
end

set_param(evalCfg.ModelName, StopTime=num2str(evalCfg.Tf));
set_param(evalCfg.ModelName, SignalLogging="on", SignalLoggingName="logsout");

if isempty(workerEnv) || ~strcmp(workerModelName, evalCfg.ModelName)
    obsInfo = rlNumericSpec([evalCfg.ObservationDimension 1], Name="observations");
    actInfo = rlNumericSpec([1 1], ...
        LowerLimit=evalCfg.ActionMin, ...
        UpperLimit=evalCfg.ActionMax, ...
        Name=evalCfg.ActionName);

    workerEnv = rlSimulinkEnv(evalCfg.ModelName, evalCfg.AgentBlock, obsInfo, actInfo);
    workerEnv.ResetFcn = @localResetFcnFurutaCurriculum;
    workerModelName = evalCfg.ModelName;
end

assignin("base", "curriculumParams", makeFixedReset(caseRow));
assignin("base", "rewardParams", evalCfg.Reward);
assignin("base", "safetyParams", evalCfg.Safety);
workerEnv.ResetFcn = @localResetFcnFurutaCurriculum;

experiences = sim(workerEnv, agent, simOpts);
caseMetrics = computeFurutaMetrics(experiences, caseRow, evalCfg);
end

function loadEvaluationModel(evalCfg)
if isfield(evalCfg, "ModelFile") && strlength(string(evalCfg.ModelFile)) > 0
    load_system(evalCfg.ModelFile);
else
    load_system(evalCfg.ModelName);
end
end

function openEvaluationModel(evalCfg)
if isfield(evalCfg, "ModelFile") && strlength(string(evalCfg.ModelFile)) > 0
    open_system(evalCfg.ModelFile);
else
    open_system(evalCfg.ModelName);
end
end

function oldFileGenConfig = configureWorkerFileGeneration(evalCfg)
oldFileGenConfig = [];

try
    oldFileGenConfig = Simulink.fileGenControl("getConfig");

    task = getCurrentTask();
    if isempty(task)
        workerTag = "client";
    else
        workerTag = "worker_" + string(task.ID);
    end

    rootDir = fullfile(evalCfg.ProjectRoot, "work", "simulink_parallel", workerTag);
    cacheDir = fullfile(rootDir, "cache");
    codegenDir = fullfile(rootDir, "codegen");

    if ~isfolder(cacheDir)
        mkdir(cacheDir);
    end
    if ~isfolder(codegenDir)
        mkdir(codegenDir);
    end

    Simulink.fileGenControl( ...
        "set", ...
        "CacheFolder", cacheDir, ...
        "CodeGenFolder", codegenDir);
catch err
    warning("evaluateFurutaController:WorkerFileGenSetupFailed", ...
        "Could not configure per-worker Simulink file generation folders: %s", err.message);
end
end

function summary = summarizeFurutaMetrics(metrics)
summary = table( ...
    height(metrics), ...
    mean(metrics.Failed), ...
    mean(metrics.FinalTheta2MAE, "omitnan"), ...
    max(metrics.FinalTheta2MaxAbsError, [], "omitnan"), ...
    mean(metrics.Theta2IAE, "omitnan"), ...
    mean(metrics.Theta2EndRMS, "omitnan"), ...
    mean(metrics.Theta2EndOscRMS, "omitnan"), ...
    mean(metrics.Theta2EndPeakToPeak, "omitnan"), ...
    mean(metrics.Theta2EndOscFreqHz, "omitnan"), ...
    mean(metrics.TorqueEnergy, "omitnan"), ...
    mean(metrics.ElectricalAbsEnergy, "omitnan"), ...
    mean(metrics.MeanAbsElectricalPower, "omitnan"), ...
    mean(metrics.DActionEnergy, "omitnan"), ...
    mean(metrics.ActionDiffRMS, "omitnan"), ...
    mean(metrics.ActionEndOscRMS, "omitnan"), ...
    mean(metrics.ActionEndPeakToPeak, "omitnan"), ...
    mean(metrics.ActionEndOscFreqHz, "omitnan"), ...
    mean(metrics.CaseCost, "omitnan"), ...
    -mean(metrics.CaseCost, "omitnan"), ...
    'VariableNames', [ ...
        "NumCases", ...
        "FailureRate", ...
        "MeanFinalTheta2MAE", ...
        "MaxFinalTheta2Error", ...
        "MeanTheta2IAE", ...
        "MeanTheta2EndRMS", ...
        "MeanTheta2EndOscRMS", ...
        "MeanTheta2EndPeakToPeak", ...
        "MeanTheta2EndOscFreqHz", ...
        "MeanTorqueEnergy", ...
        "MeanElectricalAbsEnergy", ...
        "MeanAbsElectricalPower", ...
        "MeanDActionEnergy", ...
        "MeanActionDiffRMS", ...
        "MeanActionEndOscRMS", ...
        "MeanActionEndPeakToPeak", ...
        "MeanActionEndOscFreqHz", ...
        "MeanCaseCost", ...
        "Score"]);
end
