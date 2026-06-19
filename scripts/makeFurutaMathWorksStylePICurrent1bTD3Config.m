function cfg = makeFurutaMathWorksStylePICurrent1bTD3Config(options)
%MAKEFURUTAMATHWORKSSTYLEPICURRENT1BTD3CONFIG PI/current TD3 with 500 Hz agent.
%
% This variant keeps the successful MathWorks-style wide TD3 settings, but
% targets the 1b PI/current Simulink models. The 1b controller path includes
% integrator-line saturation, and the agent sample time is set to 500 Hz for
% hardware-rate compatibility.

arguments
    options.TrainingModelName (1,1) string = "inv_rot_pen_RL_cntr_simscape_sim_1b_train"
    options.EvaluationModelName (1,1) string = "inv_rot_pen_RL_cntr_simscape_sim_1b_analytical_active"
    options.TrainingAgentBlock (1,1) string = ""
    options.EvaluationAgentBlock (1,1) string = ""
end

cfg = makeFurutaMathWorksStyleWideTD3Config();

cfg.Model.TrainingName = options.TrainingModelName;
cfg.Model.EvaluationName = options.EvaluationModelName;
cfg.Model.Name = cfg.Model.TrainingName;
cfg.Model.TrainingFile = fullfile(cfg.ProjectRoot, "scripts", cfg.Model.TrainingName + ".slx");
cfg.Model.EvaluationFile = fullfile(cfg.ProjectRoot, "scripts", cfg.Model.EvaluationName + ".slx");

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

cfg.Agent.SampleTime = 1 / 500;

cfg.Action.PhysicalInterface = "current";
cfg.Action.CurrentScale = cfg.Limits.CurrentMax;
cfg.Action.TorqueScale = cfg.Motor.km * cfg.Limits.CurrentMax;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1b_500hz";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1b_500hz";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end
