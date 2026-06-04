%function trainFurutaStabilizationDDPG()
%TRAINFURUTASTABILIZATIONDDPG Train a near-upright Furuta DDPG controller.
%
% Complete the Simulink model and block names in makeFurutaConfig.m before
% running this script.

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

agent = createDDPGAgentFuruta(obsInfo, actInfo, cfg.Agent.SampleTime);

if ~exist(cfg.Training.ResultsDir, "dir")
    mkdir(cfg.Training.ResultsDir);
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
        SaveAgentDirectory=cfg.Training.ResultsDir);

    trainingStats = train(agent, env, trainOpts);

    save(fullfile(cfg.Training.ResultsDir, ...
        sprintf("%s_stage_%02d_%s.mat", cfg.Training.SavePrefix, k, stage.Name)), ...
        "agent", "stage", "trainingStats", "cfg");
end

save(fullfile(cfg.Training.ResultsDir, cfg.Training.SavePrefix + "_final.mat"), "agent", "cfg");
%end
