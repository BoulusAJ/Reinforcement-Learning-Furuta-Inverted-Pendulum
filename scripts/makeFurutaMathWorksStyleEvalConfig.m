function evalCfg = makeFurutaMathWorksStyleEvalConfig(cfg)
%MAKEFURUTAMATHWORKSSTYLEEVALCONFIG Short and full fixed evaluation sets.

evalCfg = makeFurutaEvalConfig(cfg);

evalCfg.ShortCases = makeCasesLocal( ...
    deg2rad([0]), ...
    deg2rad([-45 -20 -5 0 5 20 45]), ...
    [0], ...
    [0], ...
    "short_mathworks_style");

evalCfg.FullCases = evalCfg.PostStageCases;
evalCfg.PostStageCases = evalCfg.ShortCases;
end

function cases = makeCasesLocal(theta1ErrorList, theta2ErrorList, omega1ErrorList, omega2ErrorList, evalSetName)
caseID = 0;
rows = [];

for i = 1:numel(theta1ErrorList)
    for j = 1:numel(theta2ErrorList)
        for k = 1:numel(omega1ErrorList)
            for n = 1:numel(omega2ErrorList)
                caseID = caseID + 1;
                rows = [rows; ...
                    caseID, ...
                    theta1ErrorList(i), ...
                    theta2ErrorList(j), ...
                    omega1ErrorList(k), ...
                    omega2ErrorList(n)]; %#ok<AGROW>
            end
        end
    end
end

cases = array2table(rows, 'VariableNames', ...
    ["CaseID", "Theta1Error0", "Theta2Error0", "Omega1Error0", "Omega2Error0"]);
cases.EvalSetName = repmat(evalSetName, height(cases), 1);
end
