function action = furutaActorForwardRaw(observation, weights)
%FURUTAACTORFORWARDRAW Raw actor forward pass matching the Nucleo C++ code.

x = double(observation(:));
if numel(x) ~= weights.InputSize
    error("furutaActorForwardRaw:ObservationSize", ...
        "Expected observation length %d, got %d.", weights.InputSize, numel(x));
end

h1 = max(weights.W1 * x + weights.b1, 0);
h2 = max(weights.W2 * h1 + weights.b2, 0);
z = weights.W3 * h2 + weights.b3;
action = tanh(z);
action = max(min(action, 1), -1);
end
