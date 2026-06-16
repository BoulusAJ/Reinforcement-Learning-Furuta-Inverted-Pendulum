function cfg = makeFurutaMathWorksStyleVoltageTD3Config(options)
%MAKEFURUTAMATHWORKSSTYLEVOLTAGETD3CONFIG Direct-voltage TD3 diagnostic run.
%
% This keeps the successful MathWorks-style wide TD3 settings and changes the
% run identity/model target for a voltage-input actuator-path comparison.

arguments
    options.TrainingModelName (1,1) string = "inv_rot_pen_RL_cntr_simscape_sim_voltage_train"
    options.EvaluationModelName (1,1) string = "inv_rot_pen_RL_cntr_simscape_sim_voltage"
    options.TrainingAgentBlock (1,1) string = ""
    options.EvaluationAgentBlock (1,1) string = ""
end

cfg = makeFurutaMathWorksStyleWideTD3Config();

cfg.Model.TrainingName = options.TrainingModelName;
cfg.Model.EvaluationName = options.EvaluationModelName;
cfg.Model.Name = cfg.Model.TrainingName;

if strlength(options.TrainingAgentBlock) > 0
    cfg.Model.TrainingAgentBlock = options.TrainingAgentBlock;
else
    cfg.Model.TrainingAgentBlock = cfg.Model.TrainingName + "/RL Agent";
end

if strlength(options.EvaluationAgentBlock) > 0
    cfg.Model.EvaluationAgentBlock = options.EvaluationAgentBlock;
else
    cfg.Model.EvaluationAgentBlock = cfg.Model.EvaluationName + "/RL Agent";
end

cfg.Model.AgentBlock = cfg.Model.TrainingAgentBlock;

cfg.Action.PhysicalInterface = "voltage";
cfg.Action.VoltageScale = cfg.Limits.VoltageMax;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_voltage";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_voltage";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
