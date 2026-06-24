%%
addpath(genpath("scripts"))
%%
loaded = loadFurutaFinalAgent(fullfile("results", "TD3", ...
    "run_20260616_012625_td3_mathworks_style_wide"), ...
    OpenModel=true);

%%
loaded = loadFurutaFinalAgent(fullfile("results", "TD3", ...
    "run_20260616_233822_td3_mathworks_style_voltage"), ...
    OpenModel=true);
%%
loaded = loadFurutaFinalAgent(fullfile("results", "TD3", ...
    "run_20260618_121014_td3_mathworks_style_pi_current_1b_500hz"), ...
    OpenModel=true);
%%
bdclose all
clearvars

loaded = loadFurutaFinalAgent(fullfile("results", "TD3", ...
    "run_20260618_121014_td3_mathworks_style_pi_current_1b_500hz"), ...
    OpenModel=true, ...
    InitialTheta=[0; 0], ...
    InitialOmega=[0; 0]);

%%
bdclose all
clearvars

loaded = loadFurutaFinalAgent(fullfile("results", "TD3", ...
    "run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long"), ...
    OpenModel=true, ...
    InitialTheta=[0; 0], ...
    InitialOmega=[0; 0]);
%%
theta0 = [0; 0];
%%
theta0 = [0; pi];
%%
theta0 = [0; pi+deg2rad(10)];

%%
addpath(genpath(fullfile("uC", "nucleo_policy_deploy", "matlab")))
%%
export = exportFurutaActorForNucleo(finalAgentFile, ...
    OutputHeader=fullfile("uC", "nucleo_policy_deploy", "lib", ...
        "RLPolicy", "rl_policy_weights.h"), ...
    OutputMat=fullfile(runDir, "actor_export_nucleo.mat"));
%%
runDir = fullfile("results", "TD3", ...
    "run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long");
S = load(fullfile(runDir, "actor_export_nucleo.mat"), "weights");
ucPolicyWeights = S.weights;

%%
%addpath(genpath("uC/nucleo_policy_deploy/matlab"))
loadFurutaUcPolicyMirrorParams

%%
1/Ts
