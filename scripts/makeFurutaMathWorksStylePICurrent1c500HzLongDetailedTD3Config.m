function cfg = makeFurutaMathWorksStylePICurrent1c500HzLongDetailedTD3Config()
%MAKEFURUTAMATHWORKSSTYLEPICURRENT1C500HZLONGDETAILEDTD3CONFIG Detailed-model 500 Hz TD3 fine-tuning config.
%
% Nominal detailed-model training setup for PC 5011. It mirrors the deployed
% 500 Hz long PI/current baseline, points to the 1c detailed models, and keeps
% domain randomization disabled by default.

cfg = makeFurutaMathWorksStylePICurrent1b500HzLongTD3Config();

cfg.Model.TrainingName = "inv_rot_pen_RL_cntr_simscape_sim_1c_train";
cfg.Model.EvaluationName = "inv_rot_pen_RL_cntr_simscape_sim_1c_analysis";
cfg.Model.Name = cfg.Model.TrainingName;
cfg.Model.TrainingAgentBlock = cfg.Model.TrainingName + "/RL Agent";
cfg.Model.EvaluationAgentBlock = cfg.Model.EvaluationName + "/RL Agent";
cfg.Model.AgentBlock = cfg.Model.TrainingAgentBlock;
cfg.Model.TrainingFile = fullfile(cfg.ProjectRoot, "scripts", cfg.Model.TrainingName + ".slx");
cfg.Model.EvaluationFile = fullfile(cfg.ProjectRoot, "scripts", cfg.Model.EvaluationName + ".slx");

cfg.Training.UseInitialAgent = false;
cfg.Training.InitialAgentRunDir = fullfile( ...
    cfg.ResultsRoot, "TD3", ...
    "run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long");
cfg.Training.InitialAgentPath = fullfile( ...
    cfg.Training.InitialAgentRunDir, ...
    "FurutaTD3_mathworks_style_pi_current_1b_500hz_long_final.mat");
cfg.Training.UseDiary = true;

cfg.DetailedModel = makeDetailedModelConfig();
cfg.DomainRandomization = makeDomainRandomizationConfig();
cfg.Training.Reset.DomainRandomization = cfg.DomainRandomization;

cfg.Training.SavePrefix = "FurutaTD3_mathworks_style_pi_current_1c_500hz_long_detailed";
cfg.Training.RunName = "run_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")) + "_td3_mathworks_style_pi_current_1c_500hz_long_detailed";
cfg.Training.OutputRoot = fullfile(cfg.Training.ResultsDir, cfg.Training.RunName);
cfg.Training.StageDir = fullfile(cfg.Training.OutputRoot, "stages");
cfg.Training.EvalDir = fullfile(cfg.Training.OutputRoot, "evaluation");
cfg.Training.ConfigDir = fullfile(cfg.Training.OutputRoot, "config");
cfg.Training.SavedAgentDir = fullfile(cfg.Training.OutputRoot, "saved_agents");
cfg.Training.FinalSaveName = cfg.Training.SavePrefix + "_final.mat";
end

function detailed = makeDetailedModelConfig()
detailed.Enabled = true;

detailed.fc_diff_theta1_Hz = 100;
detailed.fc_diff_theta2_Hz = 100;

detailed.TsFast = 50e-6;
detailed.EncoderNotchFrequencyHz = 680;
detailed.EncoderNotchDamping = 0.6;

detailed.CurrentCommandLpfFrequencyHz = 500;
detailed.CurrentCommandLpfDamping = 0.9;
detailed.PiRolloffFrequencyHz = 3000;

detailed.EncoderTheta1CountsPerRev = 4 * 4096;
detailed.EncoderTheta2CountsPerRev = 4 * 1024;

detailed.currentBias_A = 0.0026;
detailed.currentNoiseStd_A = 0.0084;
detailed.I_static_comp_A = 0.0205;

detailed.Friction.Theta1.B = 1e-5;
detailed.Friction.Theta1.CoulombCurrent_A = 0.015;
detailed.Friction.Theta1.OmegaS = 0.10;
detailed.Friction.Theta1.OmegaEps = 0.01;
detailed.Friction.Theta1.viscousScalingFactor = 7.5;
detailed.Friction.Theta1.coulombStaticScalingFactor = 2.3;
end

function dr = makeDomainRandomizationConfig()
dr.Enabled = false;

dr.CurrentBiasRange_A = [-0.010, 0.010];
dr.CurrentNoiseStdRange_A = [0.004, 0.020];
dr.IStaticCompRange_A = [0.000, 0.030];
dr.IStaticCompTightRange_A = [0.010, 0.030];

dr.Theta1ViscousScalingFactorRange = [0.5, 2.0] * 7.5;
dr.Theta1CoulombStaticScalingFactorRange = [0.5, 2.0] * 2.3;
end
