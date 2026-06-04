%% Inspect post-stage evaluation result
% Requires postStageEval in the workspace.

if ~exist("postStageEval", "var")
    error("postStageEval is not in the workspace.");
end

%% Basic size check

height(postStageEval.metrics)
postStageEval.summary

%% Key case-level table

keyMetrics = postStageEval.metrics(:, [ ...
    "CaseID", ...
    "Theta2Error0", ...
    "Omega2Error0", ...
    "Failed", ...
    "FinalTheta2MAE", ...
    "MaxAbsTheta2Error", ...
    "SettlingTimeTheta2", ...
    "CaseCost"]);

disp(keyMetrics)

%% Worst cases by cost

worstCases = sortrows(postStageEval.metrics, "CaseCost", "descend");
disp(worstCases)

%% Failed cases only

failedCases = postStageEval.metrics(postStageEval.metrics.Failed, :);
disp(failedCases)

%% Plot final theta2 error by initial theta2 error

figure
scatter(rad2deg(postStageEval.metrics.Theta2Error0), ...
    postStageEval.metrics.FinalTheta2MAE)
xlabel("Initial theta2 error [deg]")
ylabel("Final theta2 MAE [rad]")
grid on

%% Plot case cost by initial omega2 error

figure
scatter(postStageEval.metrics.Omega2Error0, ...
    postStageEval.metrics.CaseCost)
xlabel("Initial omega2 error [rad/s]")
ylabel("Case cost")
grid on

%% Optional export

if exist("cfg", "var")
    save(fullfile(cfg.Training.ResultsDir, "debug_post_stage_eval.mat"), "postStageEval")
    writetable(postStageEval.metrics, ...
        fullfile(cfg.Training.ResultsDir, "debug_post_stage_metrics.csv"))
    writetable(postStageEval.summary, ...
        fullfile(cfg.Training.ResultsDir, "debug_post_stage_summary.csv"))
else
    warning("cfg is not in the workspace. Skipping export.");
end
