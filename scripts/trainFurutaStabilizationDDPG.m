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

if ~exist(cfg.Training.ResultsDir, "dir")
    mkdir(cfg.Training.ResultsDir);
end

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
        ScoreAveragingWindowLength=cfg.Training.ScoreAveragingWindowLength, ...
        StopTrainingCriteria=cfg.Training.StopTrainingCriteria, ...
        StopTrainingValue=cfg.Training.StopTrainingValue, ...
        SaveAgentCriteria="EpisodeReward", ...
        SaveAgentValue=cfg.Training.StopTrainingValue, ...
        SaveAgentDirectory=cfg.Training.ResultsDir, ...
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
        evalLog.postStage = [evalLog.postStage; postStageEval.summary]; %#ok<AGROW>
    end

    save(fullfile(cfg.Training.ResultsDir, ...
        sprintf("%s_stage_%02d_%s.mat", cfg.Training.SavePrefix, k, stage.Name)), ...
        "agent", "stage", "trainingStats", "postStageEval", "evalCfg", "cfg");
end

save(fullfile(cfg.Training.ResultsDir, cfg.Training.SavePrefix + "_final.mat"), ...
    "agent", "cfg", "evalCfg", "evalLog");
%end
