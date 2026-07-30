%TRAINFURUTAMATLABSWINGUPTD3 Train TD3 without Simulink.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))
rng(0, "twister")

cfg = makeFurutaMatlabSwingupTD3Config();

cfg.Agent.UseDevice = "gpu";  % compare against "cpu"

env = createFurutaAnalyticalSwingupEnv(cfg);
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);
agent = createTD3AgentFuruta(obsInfo, actInfo, cfg.Agent);

if ~isfolder(cfg.Training.OutputRoot)
    mkdir(cfg.Training.OutputRoot);
end
if ~isfolder(cfg.Training.ConfigDir)
    mkdir(cfg.Training.ConfigDir);
end
if ~isfolder(cfg.Training.SavedAgentDir)
    mkdir(cfg.Training.SavedAgentDir);
end

trainOpts = rlTrainingOptions( ...
    MaxEpisodes=cfg.Training.MaxEpisodes, ...
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

trainingStats = train(agent, env, trainOpts);
save(fullfile(cfg.Training.OutputRoot, cfg.Training.FinalSaveName), ...
    "agent", "trainingStats", "cfg");
