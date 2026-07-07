%% Plot hardware swing-up runs without mixing deployment conditions

addpath("scripts/analysis")

%% Plot all runs from one test folder

testRoot = fullfile("results", "model_vs_hardware", ...
    "swingup_500hz_long_hardware_scale1p0_lim4a_20260707");

runFiles = localRunFiles(testRoot);

analysis = plotFurutaSwingupHardwareRuns(runFiles, ...
    Label="500Hz long hardware scale1p0 lim4a", ...
    SaveOutput=true);

%% Example: plot three selected runs from one test folder

% runFiles = [
%     "results/model_vs_hardware/swingup_500hz_long_hardware_scale1p0_lim4a_20260707/20260707_174108_hardware_closed_loop/run.mat"
%     "results/model_vs_hardware/swingup_500hz_long_hardware_scale1p0_lim4a_20260707/20260707_174246_hardware_closed_loop/run.mat"
%     "results/model_vs_hardware/swingup_500hz_long_hardware_scale1p0_lim4a_20260707/20260707_174339_hardware_closed_loop/run.mat"
% ];
%
% selectedAnalysis = plotFurutaSwingupHardwareRuns(runFiles, ...
%     Label="selected 500Hz long hardware scale1p0 lim4a", ...
%     SaveOutput=true);

%% Less common: plot all available condition batches

% batches = localBatchDefinitions();
% batchAnalysis = struct();
%
% for idx = 1:numel(batches)
%     runFiles = localRunFiles(batches(idx).Root);
%
%     if isempty(runFiles)
%         fprintf("Skipping %s: no run.mat files found under:\n  %s\n\n", ...
%             batches(idx).Name, batches(idx).Root);
%         continue
%     end
%
%     fprintf("Plotting %s with %d runs.\n", batches(idx).Name, numel(runFiles));
%
%     batchAnalysis.(batches(idx).Name) = plotFurutaSwingupHardwareRuns( ...
%         runFiles, ...
%         Label=batches(idx).Label, ...
%         SaveOutput=true);
% end

function runFiles = localRunFiles(rootDir)
D = dir(fullfile(rootDir, "*", "run.mat"));
if isempty(D)
    runFiles = strings(0, 1);
else
    runFiles = fullfile(string({D.folder}), string({D.name})).';
end
end

function batches = localBatchDefinitions()
batches = [
    struct( ...
        "Name", "scale0p4_lim4a", ...
        "Root", fullfile("results", "model_vs_hardware", ...
            "swingup_500hz_long_hardware_scale0p4_lim4a_20260707"), ...
        "Label", "500Hz long hardware scale0p4 lim4a")
    struct( ...
        "Name", "scale1p0_lim4a", ...
        "Root", fullfile("results", "model_vs_hardware", ...
            "swingup_500hz_long_hardware_scale1p0_lim4a_20260707"), ...
        "Label", "500Hz long hardware scale1p0 lim4a")
    struct( ...
        "Name", "scale1p0_lim0p5a", ...
        "Root", fullfile("results", "model_vs_hardware", ...
            "swingup_500hz_long_hardware_scale1p0_lim0p5a_20260707"), ...
        "Label", "500Hz long hardware scale1p0 lim0p5a")
];
end
