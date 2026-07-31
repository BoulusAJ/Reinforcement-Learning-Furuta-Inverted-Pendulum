function ws = initFurutaSldrtHardwareWorkspace(options)
%INITFURUTASLDRTHARDWAREWORKSPACE Initialize the real-system SLDRT workspace.
%
% This prepares the workspace for inv_rot_pen_RL_cntr_simscape_sldrt.slx.
% It keeps the simulation init conventions, but uses the latest drehpendel
% reference paths and exposes the firmware UART protocol parameters.
%
% Example:
%   ws = initFurutaSldrtHardwareWorkspace(SerialPort="COM9", OpenModel=true);

arguments
    options.ModelName (1,1) string = "inv_rot_pen_RL_cntr_simscape_sldrt"
    options.SerialPort (1,1) string = "COM9"
    options.ControlBaudRate (1,1) double = 115200
    options.LoggingBaudRate (1,1) double = 2e6
    options.AgentSampleTime (1,1) double = 5e-3
    options.HardwareCurrentMax (1,1) double = 0.5
    options.TrainedCurrentMax (1,1) double = 4.0
    options.InitialTheta (2,1) double = [0; 0]
    options.InitialOmega (2,1) double = [0; 0]
    options.AgentFile (1,1) string = ""
    options.AssignToBase (1,1) logical = true
    options.LoadModel (1,1) logical = true
    options.OpenModel (1,1) logical = false
end

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = findFurutaProjectRoot(scriptDir);
supportDir = fullfile(repoRoot, "deployment", "sldrt", "support");
drehpendelSldrtDir = fullfile(supportDir, "pendulum");
drehpendelIirDir = fullfile(supportDir, "iirfilter");
drehpendelSerialStreamDir = fullfile(supportDir, "serial_stream");
plantDir = fullfile(repoRoot, "shared", "plant");

addpath(scriptDir);
addpath(drehpendelSldrtDir);
addpath(drehpendelIirDir);
addpath(drehpendelSerialStreamDir);
addpath(plantDir);

cfg = makeFurutaMathWorksStyleWideTD3Config();
cfg.Model.Name = options.ModelName;
cfg.Model.TrainingName = options.ModelName;
cfg.Model.EvaluationName = options.ModelName;
cfg.Model.AgentBlock = options.ModelName + "/RL Agent";
cfg.Model.TrainingAgentBlock = cfg.Model.AgentBlock;
cfg.Model.EvaluationAgentBlock = cfg.Model.AgentBlock;
cfg.Model.PlantSampleTime = options.AgentSampleTime;
cfg.Model.HardwareFastSampleTime = 50e-6;
cfg.Agent.SampleTime = options.AgentSampleTime;
cfg.Action.PhysicalInterface = "current";
cfg.Action.CurrentScale = options.HardwareCurrentMax;
cfg.Action.TrainedCurrentScale = options.TrainedCurrentMax;
cfg.Limits.CurrentMax = options.HardwareCurrentMax;
cfg.Reference.Root = fullfile(repoRoot, "shared");
cfg.Reference.LabModelDir = plantDir;
cfg.Reference.CourseLabDir = "";

ws = initFurutaModelWorkspace(cfg, ...
    AssignToBase=false, ...
    InitialTheta=options.InitialTheta, ...
    InitialOmega=options.InitialOmega, ...
    CurrentControllerKpDb=20*log10(2.5), ...
    UseReferencePath=true);

Ts = options.AgentSampleTime;
Ts_fast = cfg.Model.HardwareFastSampleTime;
phi2_enable = cfg.Safety.PendulumEnableAngle;
phi2_disable = cfg.Safety.PendulumDisableAngle;

% Firmware host-control protocol from references/drehpendel:
% host -> board: single current command, uint8 enable flag
% board -> host: motor angle, pendulum angle, measured current
serialCfg = struct();
serialCfg.Port = options.SerialPort;
serialCfg.ControlBaudRate = options.ControlBaudRate;
serialCfg.LoggingBaudRate = options.LoggingBaudRate;
serialCfg.HostSampleTime = Ts;
serialCfg.FirmwareControlSampleTime = 200e-6;
serialCfg.FirmwareFastSampleTime = Ts_fast;
serialCfg.WatchdogTimeout = 0.3;
serialCfg.TxCurrentCommandDataType = "single";
serialCfg.TxEnableDataType = "uint8";
serialCfg.TxCurrentCommandBytes = 4;
serialCfg.TxEnableBytes = 1;
serialCfg.TxPacketBytes = 5;
serialCfg.RxDataType = "single";
serialCfg.RxNumSignals = 3;
serialCfg.RxPacketBytes = 12;
serialCfg.RxSignalNames = ["theta1", "theta2", "current"];
serialCfg.EnableTrueValue = uint8(1);
serialCfg.EnableFalseValue = uint8(0);

hardware = struct();
hardware.CurrentMax = options.HardwareCurrentMax;
hardware.TrainedCurrentMax = options.TrainedCurrentMax;
hardware.CommandScale = options.HardwareCurrentMax;
hardware.SupplyVoltage = 24.0;
hardware.OffsetVoltage = 2.0;
hardware.MotorEncoderCountsPerRev = 4 * 4096;
hardware.PendulumEncoderCountsPerRev = 4 * 1024;
hardware.PendulumEncoderSign = -1;
hardware.CurrentSensorOffset = 1.5;
hardware.CurrentSensorAdcVoltage = 3.3;
hardware.CurrentSensorGain = -1 / (50 * 7e-3);
hardware.EnableInitialValue = false;

% Firmware current-loop and encoder filters.
s = zpk("s");
Tf = 1 / (2*pi*100);
G_diff = c2d(s / (Tf*s + 1), Ts, "tustin");
G_notch = tf(get_notch(680.0, 0.6, Ts_fast));
G_lowpass2 = tf(get_lowpass2(500.0, 0.9, Ts_fast));

Kp_i = 2.5;
Tn_i = 0.0013 / 4.5320;
Kp_i_over_Tn_i = Kp_i / Tn_i;
tau_ro_i = 1 / (2*pi*3000);

ws.cfg = cfg;
ws.Ts = Ts;
ws.Ts_fast = Ts_fast;
ws.phi2_enable = phi2_enable;
ws.phi2_disable = phi2_disable;
ws.serialCfg = serialCfg;
ws.hardware = hardware;
ws.serialPort = char(serialCfg.Port);
ws.serialBaudRate = serialCfg.ControlBaudRate;
ws.serialTxPacketBytes = serialCfg.TxPacketBytes;
ws.serialRxPacketBytes = serialCfg.RxPacketBytes;
ws.serialRxNumSignals = serialCfg.RxNumSignals;
ws.serialEnableTrueValue = serialCfg.EnableTrueValue;
ws.serialEnableFalseValue = serialCfg.EnableFalseValue;
ws.agentTs = Ts;
ws.hardwareFastTs = Ts_fast;
ws.currentCommandLimit = options.HardwareCurrentMax;
ws.currentCommandScale = options.HardwareCurrentMax;
ws.i_max = options.HardwareCurrentMax;
ws.param.i_max_setpoint = options.HardwareCurrentMax;
ws.G_diff = G_diff;
ws.G_notch = G_notch;
ws.G_lowpass2 = G_lowpass2;
ws.Kp_i = Kp_i;
ws.Tn_i = Tn_i;
ws.Kp_i_over_Tn_i = Kp_i_over_Tn_i;
ws.tau_ro_i = tau_ro_i;
ws.rewardParams = cfg.Reward;
ws.safetyParams = cfg.Safety;

if strlength(options.AgentFile) > 0
    agentData = load(options.AgentFile);
    if ~isfield(agentData, "agent")
        error("initFurutaSldrtHardwareWorkspace:MissingAgent", ...
            "AgentFile does not contain a variable named 'agent': %s", options.AgentFile);
    end
    ws.agent = agentData.agent;
    ws.agentFile = options.AgentFile;
end

if options.AssignToBase
    names = fieldnames(ws);
    for idx = 1:numel(names)
        assignin("base", names{idx}, ws.(names{idx}));
    end
end

if options.LoadModel
    modelPath = fullfile(repoRoot, "deployment", "sldrt", "models", ...
        options.ModelName + ".slx");
    if options.OpenModel
        if isfile(modelPath)
            open_system(modelPath);
        else
            open_system(options.ModelName);
        end
    else
        if isfile(modelPath)
            load_system(modelPath);
        else
            load_system(options.ModelName);
        end
    end
end
end
