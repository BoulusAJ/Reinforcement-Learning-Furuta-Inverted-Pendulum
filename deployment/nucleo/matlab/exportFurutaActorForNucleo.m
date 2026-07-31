function export = exportFurutaActorForNucleo(agentFile, options)
%EXPORTFURUTAACTORFORNUCLEO Export a trained TD3 actor to C++ header arrays.
%
% This exporter is intentionally hard-coded for the current demonstrator actor:
% [7] -> [hidden] -> [hidden] -> [1], ReLU, ReLU, tanh.

arguments
    agentFile (1,1) string
    options.OutputHeader (1,1) string = fullfile("deployment", "nucleo", ...
        "generated", "td3_swingup_balance", "rl_policy_weights.h")
    options.OutputMat (1,1) string = ""
    options.HiddenSize (1,1) double = 64
    options.InputSize (1,1) double = 7
    options.OutputSize (1,1) double = 1
end

S = load(agentFile);
if ~isfield(S, "agent")
    error("exportFurutaActorForNucleo:MissingAgent", ...
        "The file does not contain variable 'agent': %s", agentFile);
end

agent = S.agent;
cfg = struct();
if isfield(S, "cfg")
    cfg = S.cfg;
end

actor = getActor(agent);
rawParams = getLearnableParameters(actor);
values = localNumericValues(rawParams);
weights = localAssignBySize(values, options.InputSize, options.HiddenSize, options.OutputSize);

weights.InputSize = options.InputSize;
weights.Hidden1Size = size(weights.W1, 1);
weights.Hidden2Size = size(weights.W2, 1);
weights.OutputSize = options.OutputSize;
weights.ActionScale = localGetActionScale(cfg);
weights.SampleTime = localGetSampleTime(cfg);
weights.SourceAgentFile = agentFile;
weights.GeneratedAt = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));

writeFurutaActorHeader(weights, options.OutputHeader);

if strlength(options.OutputMat) > 0
    outputMatDir = fileparts(options.OutputMat);
    if strlength(outputMatDir) > 0 && ~isfolder(outputMatDir)
        mkdir(outputMatDir);
    end
    save(options.OutputMat, "weights", "cfg", "agentFile");
end

export = struct();
export.AgentFile = agentFile;
export.OutputHeader = options.OutputHeader;
export.OutputMat = options.OutputMat;
export.Weights = weights;
end

function values = localNumericValues(rawParams)
if istable(rawParams)
    if any(strcmp(rawParams.Properties.VariableNames, "Value"))
        rawValues = rawParams.Value;
    else
        rawValues = table2cell(rawParams);
    end
elseif iscell(rawParams)
    rawValues = rawParams;
else
    rawValues = {rawParams};
end

values = {};
for idx = 1:numel(rawValues)
    v = rawValues{idx};
    if isa(v, "dlarray")
        v = extractdata(v);
    end
    if isa(v, "gpuArray")
        v = gather(v);
    end
    if isnumeric(v)
        values{end+1} = double(v); %#ok<AGROW>
    end
end
end

function weights = localAssignBySize(values, inputSize, hiddenSize, outputSize)
weights = struct();
used = false(size(values));
[weights.W1, used] = localTakeMatrix(values, used, hiddenSize, inputSize, "W1");
[weights.b1, used] = localTakeVector(values, used, hiddenSize, "b1");
[weights.W2, used] = localTakeMatrix(values, used, hiddenSize, hiddenSize, "W2");
[weights.b2, used] = localTakeVector(values, used, hiddenSize, "b2");
[weights.W3, used] = localTakeMatrix(values, used, outputSize, hiddenSize, "W3");
[weights.b3, used] = localTakeVector(values, used, outputSize, "b3");
end

function [value, used] = localTakeMatrix(values, used, rows, cols, name)
idx = localFindSize(values, used, [rows cols]);
if isempty(idx)
    idx = localFindSize(values, used, [cols rows]);
    if isempty(idx)
        error("exportFurutaActorForNucleo:MissingWeight", ...
            "Could not find %s with size %dx%d.", name, rows, cols);
    end
    value = values{idx}.';
else
    value = values{idx};
end
used(idx) = true;
end

function [value, used] = localTakeVector(values, used, len, name)
idx = [];
for k = 1:numel(values)
    if used(k)
        continue;
    end
    if numel(values{k}) == len && (isvector(values{k}) || any(size(values{k}) == 1))
        idx = k;
        break;
    end
end
if isempty(idx)
    error("exportFurutaActorForNucleo:MissingBias", ...
        "Could not find %s with length %d.", name, len);
end
value = values{idx}(:);
used(idx) = true;
end

function idx = localFindSize(values, used, targetSize)
idx = [];
for k = 1:numel(values)
    if used(k)
        continue;
    end
    if isequal(size(values{k}), targetSize)
        idx = k;
        return;
    end
end
end

function scale = localGetActionScale(cfg)
scale = 4.0;
if isfield(cfg, "Action") && isfield(cfg.Action, "CurrentScale")
    scale = cfg.Action.CurrentScale;
end
end

function sampleTime = localGetSampleTime(cfg)
sampleTime = 0.002;
if isfield(cfg, "Agent") && isfield(cfg.Agent, "SampleTime")
    sampleTime = cfg.Agent.SampleTime;
end
end
