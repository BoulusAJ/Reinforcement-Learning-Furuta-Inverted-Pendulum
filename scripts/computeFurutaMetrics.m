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
[tElectricalPower, electricalPower] = alignProduct(sig.tCurrent, sig.current, sig.tVoltage, sig.voltage);
electricalAbsEnergy = integrateAbs(tElectricalPower, electricalPower);
meanAbsElectricalPower = electricalAbsEnergy / max(eps, t(end) - t(1));

dActionEnergy = integrateDiffSquare(sig.tAction, sig.action);
dTorqueCommandEnergy = integrateDiffSquare(sig.tTorqueCommand, sig.torque_command);

finalWindowStart = max(t(1), t(end) - evalCfg.FinalWindowSeconds);
idxFinal = t >= finalWindowStart;

finalTheta2MAE = mean(abs(sig.theta2Error(idxFinal)));
finalTheta1MAE = mean(abs(sig.theta1Error(idxFinal)));
finalTheta2Bias = mean(sig.theta2Error(idxFinal));
finalTheta1Bias = mean(sig.theta1Error(idxFinal));
finalTheta2MaxAbsError = max(abs(sig.theta2Error(idxFinal)));

endWindowStart = max(t(1), t(end) - 1.0);
idxEnd = t >= endWindowStart;

theta2EndRMS = rmsValue(sig.theta2Error(idxEnd));
theta2EndDetrended = sig.theta2Error(idxEnd) - mean(sig.theta2Error(idxEnd), "omitnan");
theta2EndOscRMS = rmsValue(theta2EndDetrended);
theta2EndPeakToPeak = peakToPeak(theta2EndDetrended);
theta2EndOscFreqHz = estimateOscillationFrequency(t(idxEnd), theta2EndDetrended);

[actionEndT, actionEnd] = finalWindowSignal(sig.tAction, sig.action, 1.0);
actionEndDetrended = actionEnd - mean(actionEnd, "omitnan");
actionEndRMS = rmsValue(actionEnd);
actionEndOscRMS = rmsValue(actionEndDetrended);
actionEndPeakToPeak = peakToPeak(actionEndDetrended);
actionEndOscFreqHz = estimateOscillationFrequency(actionEndT, actionEndDetrended);
actionDiffRMS = rmsValue(diff(sig.action));

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
    theta2EndRMS, theta2EndOscRMS, theta2EndPeakToPeak, theta2EndOscFreqHz, ...
    actionEnergy, torqueCommandEnergy, torqueEnergy, currentEnergy, voltageEnergy, electricalAbsEnergy, meanAbsElectricalPower, ...
    dActionEnergy, dTorqueCommandEnergy, actionDiffRMS, ...
    actionEndRMS, actionEndOscRMS, actionEndPeakToPeak, actionEndOscFreqHz, ...
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
        "Theta2EndRMS", "Theta2EndOscRMS", "Theta2EndPeakToPeak", "Theta2EndOscFreqHz", ...
        "ActionEnergy", "TorqueCommandEnergy", "TorqueEnergy", "CurrentEnergy", "VoltageEnergy", "ElectricalAbsEnergy", "MeanAbsElectricalPower", ...
        "DActionEnergy", "DTorqueCommandEnergy", "ActionDiffRMS", ...
        "ActionEndRMS", "ActionEndOscRMS", "ActionEndPeakToPeak", "ActionEndOscFreqHz", ...
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

function [tCommon, absProduct] = alignProduct(tA, a, tB, b)
tA = tA(:);
a = a(:);
tB = tB(:);
b = b(:);

nA = min(numel(tA), numel(a));
nB = min(numel(tB), numel(b));
if nA < 2 || nB < 2
    tCommon = 0;
    absProduct = 0;
    return;
end

tA = tA(1:nA);
a = a(1:nA);
tB = tB(1:nB);
b = b(1:nB);

tStart = max(tA(1), tB(1));
tEnd = min(tA(end), tB(end));
idx = tA >= tStart & tA <= tEnd;
if nnz(idx) < 2
    tCommon = 0;
    absProduct = 0;
    return;
end

tCommon = tA(idx);
aCommon = a(idx);
bCommon = interp1(tB, b, tCommon, "linear", "extrap");
absProduct = abs(aCommon .* bCommon);
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

function y = rmsValue(x)
x = x(:);
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = sqrt(mean(x.^2));
end
end

function y = peakToPeak(x)
x = x(:);
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = max(x) - min(x);
end
end

function [tWindow, xWindow] = finalWindowSignal(t, x, windowSeconds)
t = t(:);
x = x(:);
n = min(numel(t), numel(x));
if n == 0
    tWindow = [];
    xWindow = [];
    return;
end

t = t(1:n);
x = x(1:n);
windowStart = max(t(1), t(end) - windowSeconds);
idx = t >= windowStart;
tWindow = t(idx);
xWindow = x(idx);
end

function freqHz = estimateOscillationFrequency(t, x)
t = t(:);
x = x(:);
n = min(numel(t), numel(x));
if n < 3
    freqHz = NaN;
    return;
end

t = t(1:n);
x = x(1:n);
valid = isfinite(t) & isfinite(x);
t = t(valid);
x = x(valid);
if numel(t) < 3 || peakToPeak(x) < 1e-12
    freqHz = 0;
    return;
end

signX = sign(x);
signX(signX == 0) = 1;
crossings = find(signX(1:end-1) .* signX(2:end) < 0);
duration = t(end) - t(1);
if duration <= 0
    freqHz = NaN;
else
    freqHz = numel(crossings) / (2 * duration);
end
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
