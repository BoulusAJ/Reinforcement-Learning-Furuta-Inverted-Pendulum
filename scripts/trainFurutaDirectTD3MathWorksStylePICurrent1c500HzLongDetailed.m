%% Train Furuta direct TD3 on the 1c detailed model at 500 Hz long
% PC 5011 handoff run. This mirrors the deployed 500Hz_long baseline but
% points training to the detailed 1c model and analysis/evaluation to the 1c
% analysis model.
%
% Initial-agent fine-tuning is available but disabled by default. To continue
% from the deployed 500Hz_long final agent, set:
%
%   cfg.Training.UseInitialAgent = true;
%
% before calling trainFurutaDirectTD3WithConfig(cfg).
%
% Domain randomization ranges are included in cfg.DomainRandomization, but
% disabled by default. To turn them on after the nominal detailed-model run is
% understood, set:
%
%   cfg.DomainRandomization.Enabled = true;
%   cfg.Training.Reset.DomainRandomization = cfg.DomainRandomization;

cfg = makeFurutaMathWorksStylePICurrent1c500HzLongDetailedTD3Config();

% cfg.Training.UseInitialAgent = true;
% cfg.DomainRandomization.Enabled = true;
% cfg.Training.Reset.DomainRandomization = cfg.DomainRandomization;

trainFurutaDirectTD3WithConfig(cfg);
