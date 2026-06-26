
%%
run("scripts/analysis/saveCurrentWorkspaceTest1HardwareRun.m")
% results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/<timestamp>_hardware/
%%
% for comparing mat analysis files:
files = [
    "results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/<hardware_run>/run.mat"
    "results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/<simulation_run>/run.mat"
];

comparison = compareFurutaModelVsHardwareRuns(files, ...
    Label="test1_hardware_vs_model", ...
    ReferenceIndex=1);

%%
% for comparing mat analysis files:
files = [
    "results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/20260622_201704_hardware/run.mat"
    "results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/20260622_205252_analytical/run.mat"
];

comparison = compareFurutaModelVsHardwareRuns(files, ...
    Label="test1_hardware_vs_model", ...
    ReferenceIndex=1);

%%
spec = makeFurutaModelVsHardwareTest1Spec();

savedSim = saveFurutaModelVsHardwareRun(simout, ...
    TestName=spec.TestName, ...
    SourceType="analytical", ...
    Description=spec.Description, ...
    ModelDescription="Analytical model, run_20260616_012625_td3_mathworks_style_wide parameters, internal 20 kHz, logged at 200 Hz", ...
    InputDescription="I_cmd = 0.2 A until disable at 0.8 s; enable = 1 then 0", ...
    CurrentCommand=spec.CurrentCommand, ...
    EnableDisableTime=spec.EnableDisableTime, ...
    Duration=spec.Duration);

%%
files = [
    "results/model_vs_hardware/test1_constant_current_0p2a_disable_0p8s/<hardware_run>/run.mat"
    savedSim.matPath
];

comparison = compareFurutaModelVsHardwareRuns(files, ...
    Label="test1_hardware_vs_analytical_20khz_logged_200hz", ...
    ReferenceIndex=1);