function summary = plotAllFurutaTrainingProgress(options)
%PLOTALLFURUTATRAININGPROGRESS Generate training plots for every saved run.
%
%   summary = plotAllFurutaTrainingProgress() scans results/**/run_* folders,
%   calls plotFurutaTrainingProgress for each run, and writes a batch summary
%   table to results/training_progress_batch_summary.csv.

arguments
    options.ResultsRoot (1,1) string = ""
    options.OutputName (1,1) string = "training_progress"
    options.RewardOnlyOutputName (1,1) string = "training_reward"
    options.SummaryName (1,1) string = "training_progress_batch_summary.csv"
    options.Overwrite (1,1) logical = true
end

resultsRoot = string(options.ResultsRoot);
if strlength(resultsRoot) == 0
    paths = getFurutaPaths();
    resultsRoot = paths.ResultsRoot;
end
if ~isfolder(resultsRoot)
    error("plotAllFurutaTrainingProgress:MissingResultsRoot", ...
        "Results root does not exist: %s", resultsRoot);
end

runDirs = findRunDirectories(resultsRoot);
rows = table();

fprintf("Found %d run directories under %s.\n", numel(runDirs), resultsRoot);

for idx = 1:numel(runDirs)
    runDir = runDirs(idx);
    fprintf("\n[%d/%d] %s\n", idx, numel(runDirs), runDir);

    row = table( ...
        runDir, ...
        false, ...
        strings(1,1), ...
        strings(1,1), ...
        strings(1,1), ...
        strings(1,1), ...
        strings(1,1), ...
        0, ...
        VariableNames=[ ...
            "RunDir", ...
            "Succeeded", ...
            "SourceMat", ...
            "SourceVariable", ...
            "PlotPath", ...
            "RewardPlotPath", ...
            "Message", ...
            "NumEpisodes"]);

    try
        if ~options.Overwrite && ...
                isfile(fullfile(runDir, options.OutputName + ".png")) && ...
                isfile(fullfile(runDir, options.RewardOnlyOutputName + ".png"))
            row.Succeeded = true;
            row.Message = "already exists";
        else
            out = plotFurutaTrainingProgress( ...
                runDir, ...
                OutputName=options.OutputName, ...
                RewardOnlyOutputName=options.RewardOnlyOutputName);

            row.Succeeded = true;
            row.SourceMat = out.SourceMat;
            row.SourceVariable = out.SourceVariable;
            row.PlotPath = out.PlotPath;
            row.RewardPlotPath = out.RewardPlotPath;
            row.NumEpisodes = out.NumEpisodes;
            row.Message = "ok";
        end
    catch err
        row.Message = string(err.message);
        warning("plotAllFurutaTrainingProgress:RunFailed", ...
            "Skipping %s: %s", runDir, err.message);
    end

    rows = [rows; row]; %#ok<AGROW>
end

summary = rows;
summaryPath = fullfile(resultsRoot, options.SummaryName);
writetable(summary, summaryPath);

fprintf("\nSaved batch summary:\n  %s\n", summaryPath);
fprintf("Succeeded: %d / %d\n", nnz(summary.Succeeded), height(summary));
end

function runDirs = findRunDirectories(resultsRoot)
listing = dir(fullfile(resultsRoot, "**", "run_*"));
isRunDir = [listing.isdir];
listing = listing(isRunDir);

runDirs = strings(numel(listing), 1);
for idx = 1:numel(listing)
    runDirs(idx) = string(fullfile(listing(idx).folder, listing(idx).name));
end

runDirs = unique(runDirs, "stable");
runDirs = sort(runDirs);
end
