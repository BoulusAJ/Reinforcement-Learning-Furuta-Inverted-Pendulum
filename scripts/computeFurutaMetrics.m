function row = computeFurutaMetrics(experiences, caseRow, evalCfg)
%COMPUTEFURUTAMETRICS Compute case-level Furuta stabilization metrics.

sig = extractFurutaSignals(experiences);
t = sig.t;

theta1AbsMax = max(abs(sig.theta1));
theta2ErrorAbsMax = max(abs(sig.theta2Error));
omegaAbsMax = max(max(abs([sig.omega1Error, sig.omega2Error])));

theta2IAE = integrateAbs(t, sig.theta2Error);
theta2ISE = integrateSquare(t, sig.theta2Error);
theta1IAE = integrateAbs(t, sig.theta1Error);

actionEnergy = integrateSquare(sig.tAction, sig.action);
torqueCommandEnergy = integrateSquare(sig.tTorqueCommand, sig.torque_command);
torqueEnergy = integrateSquare(sig.tTorque, sig.torque);
currentEnergy = integrateSquare(sig.tCurrent, sig.current);
voltageEnergy = integrateSquare(sig.tVoltage, sig.voltage);

dActionEnergy = integrateDiffSquare(sig.tAction, sig.action);
dTorqueCommandEnergy = integrateDiffSquare(sig.tTorqueCommand, sig.torque_command);

finalWindowStart = max(t(1), t(end) - evalCfg.FinalWindowSeconds);
idxFinal = t >= finalWindowStart;

finalTheta2MAE = mean(abs(sig.theta2Error(idxFinal)));
finalTheta1MAE = mean(abs(sig.theta1Error(idxFinal)));
finalTheta2Bias = mean(sig.theta2Error(idxFinal));
finalTheta1Bias = mean(sig.theta1Error(idxFinal));
finalTheta2MaxAbsError = max(abs(sig.theta2Error(idxFinal)));

settlingTimeTheta2 = computeSettlingTime(t, sig.theta2Error, evalCfg.SettlingTolTheta2);
settlingTimeBoth = computeSettlingTimeBoth( ...
    t, sig.theta1Error, sig.theta2Error, ...
    evalCfg.SettlingTolTheta1, evalCfg.SettlingTolTheta2);

terminated = any(sig.isDone > 0.5);
failed = terminated || ...
    theta2ErrorAbsMax > evalCfg.Safety.MaxAbsPendulumAngle || ...
    theta1AbsMax > evalCfg.Safety.MaxAbsArmAngle || ...
    omegaAbsMax > evalCfg.Safety.MaxAbsAngularVelocity;

caseCost = computeCaseCost( ...
    finalTheta2MAE, finalTheta2MaxAbsError, theta2IAE, theta1IAE, ...
    torqueEnergy, dActionEnergy, failed, evalCfg);

row = table( ...
    caseRow.CaseID, ...
    caseRow.Theta1Error0, caseRow.Theta2Error0, ...
    caseRow.Omega1Error0, caseRow.Omega2Error0, ...
    string(caseRow.EvalSetName), ...
    t(end), numel(t), ...
    theta1AbsMax, theta2ErrorAbsMax, omegaAbsMax, ...
    theta2IAE, theta2ISE, theta1IAE, ...
    settlingTimeTheta2, settlingTimeBoth, ...
    finalTheta2MAE, finalTheta1MAE, finalTheta2Bias, finalTheta1Bias, finalTheta2MaxAbsError, ...
    actionEnergy, torqueCommandEnergy, torqueEnergy, currentEnergy, voltageEnergy, ...
    dActionEnergy, dTorqueCommandEnergy, ...
    terminated, failed, caseCost, ...
    'VariableNames', [ ...
        "CaseID", ...
        "Theta1Error0", "Theta2Error0", ...
        "Omega1Error0", "Omega2Error0", ...
        "EvalSetName", ...
        "SimTime", "NumSamples", ...
        "MaxAbsTheta1", "MaxAbsTheta2Error", "MaxAbsOmegaError", ...
        "Theta2IAE", "Theta2ISE", "Theta1IAE", ...
        "SettlingTimeTheta2", "SettlingTimeBoth", ...
        "FinalTheta2MAE", "FinalTheta1MAE", "FinalTheta2Bias", "FinalTheta1Bias", "FinalTheta2MaxAbsError", ...
        "ActionEnergy", "TorqueCommandEnergy", "TorqueEnergy", "CurrentEnergy", "VoltageEnergy", ...
        "DActionEnergy", "DTorqueCommandEnergy", ...
        "Terminated", "Failed", "CaseCost"]);
end

function area = integrateAbs(t, x)
area = integrateSignal(t, abs(x));
end

function area = integrateSquare(t, x)
area = integrateSignal(t, x.^2);
end

function area = integrateDiffSquare(t, x)
if numel(x) < 2
    area = 0;
    return;
end

dx = [0; diff(x)];
area = integrateSignal(t, dx.^2);
end

function area = integrateSignal(t, x)
t = t(:);
x = x(:);
n = min(numel(t), numel(x));

if n < 2
    area = 0;
    return;
end

area = trapz(t(1:n), x(1:n));
end

function settlingTime = computeSettlingTime(t, e, tol)
inside = abs(e) <= tol;
settlingTime = NaN;

for k = 1:numel(t)
    if all(inside(k:end))
        settlingTime = t(k);
        return;
    end
end
end

function settlingTime = computeSettlingTimeBoth(t, theta1Error, theta2Error, theta1Tol, theta2Tol)
inside = abs(theta1Error) <= theta1Tol & abs(theta2Error) <= theta2Tol;
settlingTime = NaN;

for k = 1:numel(t)
    if all(inside(k:end))
        settlingTime = t(k);
        return;
    end
end
end

function caseCost = computeCaseCost(finalTheta2MAE, finalTheta2MaxAbsError, theta2IAE, theta1IAE, torqueEnergy, dActionEnergy, failed, evalCfg)
if failed
    caseCost = evalCfg.Score.failureBasePenalty;
else
    caseCost = ...
        evalCfg.Score.meanFinalTheta2MAEWeight * finalTheta2MAE + ...
        evalCfg.Score.maxFinalTheta2ErrorWeight * finalTheta2MaxAbsError + ...
        evalCfg.Score.theta2IAEWeight * theta2IAE + ...
        evalCfg.Score.theta1IAEWeight * theta1IAE + ...
        evalCfg.Score.torqueEnergyWeight * torqueEnergy + ...
        evalCfg.Score.actionSmoothnessWeight * dActionEnergy;
end
end
