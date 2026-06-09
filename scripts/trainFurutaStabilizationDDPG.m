%function trainFurutaStabilizationDDPG()
%TRAINFURUTASTABILIZATIONDDPG Train a near-upright Furuta DDPG controller.
%
% Complete the Simulink model and block names in makeFurutaConfig.m before
% running this script.

cd("C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum")
addpath(genpath("scripts"))

cfg = makeFurutaConfig();
initFurutaModelWorkspace(cfg);
open_system(cfg.Model.Name);

oldFastRestart = get_param(cfg.Model.Name, "FastRestart");
if strcmp(oldFastRestart, "on")
    set_param(cfg.Model.Name, FastRestart="off");
end
if cfg.Training.UseFastRestart
    set_param(cfg.Model.Name, FastRestart="on");
end
cleanupFastRestart = onCleanup(@() restoreTrainingFastRestart(cfg.Model.Name, oldFastRestart));

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
actInfo = rlNumericSpec([1 1], ...
    LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, ...
    Name=cfg.Action.Name);

env = rlSimulinkEnv(cfg.Model.Name, cfg.Model.AgentBlock, obsInfo, actInfo);
env.ResetFcn = @localResetFcnFurutaCurriculum;

agent = createDDPGAgentFuruta(obsInfo, actInfo, cfg.Agent);
evalCfg = makeFurutaEvalConfig(cfg);
evalLog = struct();
evalLog.postStage = [];

prepareRunOutputFolders(cfg);
writeRunConfig(cfg, evalCfg);

if cfg.Training.UseParallel
    pool = gcp("nocreate");
    if isempty(pool)
        pool = parpool("Processes", cfg.Training.RequestedWorkers);
    elseif pool.NumWorkers ~= cfg.Training.RequestedWorkers
        warning("trainFurutaStabilizationDDPG:ParallelPoolSizeMismatch", ...
            "Using existing pool with %d workers instead of requested %d workers.", ...
            pool.NumWorkers, cfg.Training.RequestedWorkers);
    end
end

for k = 1:numel(cfg.Curriculum)
    stage = cfg.Curriculum(k);
    assignin("base", "curriculumParams", stage.Reset);
    assignin("base", "rewardParams", cfg.Reward);
    assignin("base", "safetyParams", cfg.Safety);

    agent.AgentOptions.NoiseOptions.StandardDeviation = stage.NoiseStd;

    trainOpts = rlTrainingOptions( ...
        MaxEpisodes=stage.MaxEpisodes, ...
        MaxStepsPerEpisode=ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime), ...
        Verbose=cfg.Training.Verbose, ...
        Plots=cfg.Training.PlotMode, ...
        ScoreAveragingWindowLength=cfg.Training.ScoreAveragingWindowLength, ...
        StopTrainingCriteria=cfg.Training.StopTrainingCriteria, ...
        StopTrainingValue=cfg.Training.StopTrainingValue, ...
        SaveAgentCriteria="EpisodeReward", ...
        SaveAgentValue=cfg.Training.StopTrainingValue, ...
        SaveAgentDirectory=cfg.Training.SavedAgentDir, ...
        UseParallel=cfg.Training.UseParallel);

    if cfg.Training.UseParallel
        trainOpts.ParallelizationOptions.Mode = cfg.Training.ParallelMode;
        trainOpts.ParallelizationOptions.DataToSendFromWorkers = "experiences";
        trainOpts.ParallelizationOptions.StepsUntilDataIsSent = cfg.Training.StepsUntilDataIsSent;
    end

    trainingStats = train(agent, env, trainOpts);

    postStageEval = [];
    if cfg.Evaluation.UsePostStageEvaluation
        fprintf("\nRunning post-stage evaluation for Stage %d: %s\n", k, stage.Name);
        postStageEval = evaluateFurutaController( ...
            agent, env, evalCfg.PostStageCases, evalCfg, ...
            "ControllerName", "DDPG", ...
            "EvalSetName", "post_stage_full", ...
            "StageIndex", k, ...
            "StageName", stage.Name, ...
            "RunInBackground", true, ...
            "UseFastRestart", true, ...
            "UseParallel", cfg.Training.UseParallel, ...
            "RequestedWorkers", cfg.Training.RequestedWorkers, ...
            "AllowPoolRestart", false);
        evalLog.postStage = [evalLog.postStage; postStageEval.summary];
        writeEvaluationTables(postStageEval, cfg, k, stage.Name);
    end

    save(fullfile(cfg.Training.StageDir, ...
        sprintf("%s_stage_%02d_%s.mat", cfg.Training.SavePrefix, k, stage.Name)), ...
        "agent", "stage", "trainingStats", "postStageEval", "evalCfg", "cfg");
end

save(fullfile(cfg.Training.OutputRoot, cfg.Training.FinalSaveName), ...
    "agent", "cfg", "evalCfg", "evalLog");
%end

function prepareRunOutputFolders(cfg)
folders = [
    cfg.Training.ResultsDir
    cfg.Training.OutputRoot
    cfg.Training.StageDir
    cfg.Training.EvalDir
    cfg.Training.ConfigDir
    cfg.Training.SavedAgentDir
    ];

for i = 1:numel(folders)
    if ~isfolder(folders(i))
        mkdir(folders(i));
    end
end
end

function writeRunConfig(cfg, evalCfg)
cfgPath = fullfile(cfg.Training.ConfigDir, "run_config.json");
evalCfgPath = fullfile(cfg.Training.ConfigDir, "eval_config.mat");

writeJson(cfgPath, cfg);
save(evalCfgPath, "evalCfg");
writetable(evalCfg.TrainingCases, ...
    fullfile(cfg.Training.ConfigDir, "training_eval_cases.csv"));
writetable(evalCfg.PostStageCases, ...
    fullfile(cfg.Training.ConfigDir, "post_stage_eval_cases.csv"));
end

function writeJson(path, value)
encoded = jsonencode(value, PrettyPrint=true);
fid = fopen(path, "w");
if fid < 0
    error("trainFurutaStabilizationDDPG:WriteJsonFailed", ...
        "Could not write JSON file: %s", path);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, "%s", encoded);
end

function writeEvaluationTables(postStageEval, cfg, stageIndex, stageName)
safeStageName = matlab.lang.makeValidName(stageName);
prefix = sprintf("stage_%02d_%s", stageIndex, safeStageName);

writetable(postStageEval.metrics, ...
    fullfile(cfg.Training.EvalDir, prefix + "_metrics.csv"));
writetable(postStageEval.summary, ...
    fullfile(cfg.Training.EvalDir, prefix + "_summary.csv"));
end

function restoreTrainingFastRestart(modelName, oldFastRestart)
if bdIsLoaded(modelName)
    set_param(modelName, FastRestart="off");
    set_param(modelName, FastRestart=oldFastRestart);
end
end
