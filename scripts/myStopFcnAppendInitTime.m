function myStopFcnAppendInitTime
try
    % Name of SimulationOutput variable in base workspace
    simOutName = 'out';
    if ~evalin('base',['exist(''' simOutName ''',''var'')'])
        return
    end
    out = evalin('base', simOutName);

    % Get metadata robustly
    if isprop(out,'SimulationMetadata')
        simMeta = out.SimulationMetadata;
    else
        simMeta = getSimulationMetadata(out);
    end

    % Read timing values using subfunction
    initT  = getTimingField(simMeta, 'InitializationElapsedWallTime');
    execT  = getTimingField(simMeta, 'ExecutionElapsedWallTime');
    termT  = getTimingField(simMeta, 'TerminationElapsedWallTime');
    totalT = getTimingField(simMeta, 'TotalElapsedWallTime');
    % Append to base workspace arrays (create if missing)
    if ~evalin('base','exist(''initTimes'',''var'')')
        assignin('base','initTimes',initT);
        assignin('base','execTimes',execT);
        assignin('base','termTimes',termT);
        assignin('base','totalTimes',totalT);
    else
        a = evalin('base','initTimes');  a(end+1) = initT;  assignin('base','initTimes',a);
        b = evalin('base','execTimes');  b(end+1) = execT;  assignin('base','execTimes',b);
        c = evalin('base','termTimes');  c(end+1) = termT;  assignin('base','termTimes',c);
        d = evalin('base','totalTimes'); d(end+1) = totalT; assignin('base','totalTimes',d);
    end
catch ME
    % Record error info without interrupting stop processing
    if ~evalin('base','exist(''initTimesErr'',''var'')')
        assignin('base','initTimesErr',{getReport(ME,'basic')});
    else
        errCell = evalin('base','initTimesErr');
        errCell{end+1} = getReport(ME,'basic');
        assignin('base','initTimesErr',errCell);
    end
end
end

% -----------------------
% Subfunction (non-nested)
function val = getTimingField(meta, fieldName)
val = NaN;
if isprop(meta,'TimingInfo') && isstruct(meta.TimingInfo) && ...
        isfield(meta.TimingInfo, fieldName)
    val = meta.TimingInfo.(fieldName);
end
end
