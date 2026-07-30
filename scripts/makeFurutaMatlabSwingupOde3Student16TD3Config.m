function cfg = makeFurutaMatlabSwingupOde3Student16TD3Config()
%MAKEFURUTAMATLABSWINGUPODE3STUDENT16TD3CONFIG 16-neuron laptop experiment.
%
% This is identical to the 32-neuron experiment except for network width.
% It uses a separate run name and output directory so it can train in a
% second MATLAB process without writing into the active 32-neuron run.

cfg = makeFurutaMatlabSwingupOde3Student32TD3Config();

cfg.Agent.ActorHiddenLayerSizes = 16;
cfg.Agent.CriticHiddenLayerSizes = [16 16];

cfg.Training.SavePrefix = ...
    "FurutaTD3_matlab_ode3_student_100hz_actor1x16_critic2x16";
cfg.Training.RunName = "run_" + string(datetime("now", ...
    "Format", "yyyyMMdd_HHmmss_SSS")) ...
    + "_td3_matlab_ode3_student_100hz_actor1x16_critic2x16";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
