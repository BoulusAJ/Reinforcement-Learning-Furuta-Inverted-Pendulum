%% 
simout1;

%% Quick visual inspection of hardware swing-up recording in simout1

% Expected mux layout:
% 1 theta1
% 2 theta2
% 3 omega1
% 4 omega2
% 5 theta2_wrapped
% 6 enable
% 7 current_cmd / i_cmd
% 8 current

sig = extractFurutaModelVsHardwareSignals(simout1, ...
    SourceLabel="hardware_swingup_raw");

fprintf("Samples: %d\n", numel(sig.t));
fprintf("Time: %.3f to %.3f s, duration %.3f s\n", ...
    sig.t(1), sig.t(end), sig.t(end) - sig.t(1));
fprintf("Median dt: %.6f s, median fs: %.2f Hz\n", ...
    sig.dt_median, sig.fs_median);

idxEnableOn = find(sig.enable > 0.5, 1, "first");
idxEnableOff = find(sig.enable < 0.5 & sig.t > sig.t(idxEnableOn), 1, "first");

if ~isempty(idxEnableOn)
    fprintf("Enable ON at t = %.3f s\n", sig.t(idxEnableOn));
else
    fprintf("Enable ON not found\n");
end

if ~isempty(idxEnableOff)
    fprintf("Enable OFF at t = %.3f s\n", sig.t(idxEnableOff));
else
    fprintf("Enable OFF not found after enable-on\n");
end

fprintf("Max |theta1|: %.2f deg\n", max(abs(rad2deg(sig.theta1))));
fprintf("Max |theta2_wrapped|: %.2f deg\n", max(abs(rad2deg(sig.theta2_wrapped))));
fprintf("Max |omega1|: %.2f rad/s\n", max(abs(sig.omega1)));
fprintf("Max |omega2|: %.2f rad/s\n", max(abs(sig.omega2)));
fprintf("Max |i_cmd|: %.3f A\n", max(abs(sig.current_cmd)));
fprintf("Max |current|: %.3f A\n", max(abs(sig.current)));

%% Plot full recording

figure("Color", "w", "Name", "Hardware swing-up raw simout1");
tiledlayout(5, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile
plot(sig.t, rad2deg(sig.theta1), "LineWidth", 1.0);
grid on
ylabel("\theta_1 [deg]")

nexttile
plot(sig.t, rad2deg(sig.theta2), "LineWidth", 1.0);
hold on
plot(sig.t, rad2deg(sig.theta2_wrapped), "LineWidth", 1.0);
grid on
ylabel("\theta_2 [deg]")
legend(["raw", "wrapped"], "Location", "best")

nexttile
plot(sig.t, sig.omega1, "LineWidth", 1.0);
hold on
plot(sig.t, sig.omega2, "LineWidth", 1.0);
grid on
ylabel("\omega [rad/s]")
legend(["omega1", "omega2"], "Location", "best")

nexttile
plot(sig.t, sig.current_cmd, "LineWidth", 1.0);
hold on
plot(sig.t, sig.current, "LineWidth", 1.0);
grid on
ylabel("current [A]")
legend(["i_{cmd}", "i"], "Location", "best")

nexttile
stairs(sig.t, sig.enable, "LineWidth", 1.0);
grid on
ylabel("enable")
xlabel("time [s]")

%% Plot useful window around motor enable, if found

if ~isempty(idxEnableOn)
    t0 = max(sig.t(1), sig.t(idxEnableOn) - 0.5);
    if ~isempty(idxEnableOff)
        t1 = min(sig.t(end), sig.t(idxEnableOff) + 0.5);
    else
        t1 = sig.t(end);
    end

    idx = sig.t >= t0 & sig.t <= t1;

    figure("Color", "w", "Name", "Hardware swing-up enabled window");
    tiledlayout(5, 1, "TileSpacing", "compact", "Padding", "compact");

    nexttile
    plot(sig.t(idx), rad2deg(sig.theta1(idx)), "LineWidth", 1.0);
    grid on
    ylabel("\theta_1 [deg]")

    nexttile
    plot(sig.t(idx), rad2deg(sig.theta2(idx)), "LineWidth", 1.0);
    hold on
    plot(sig.t(idx), rad2deg(sig.theta2_wrapped(idx)), "LineWidth", 1.0);
    grid on
    ylabel("\theta_2 [deg]")
    legend(["raw", "wrapped"], "Location", "best")

    nexttile
    plot(sig.t(idx), sig.omega1(idx), "LineWidth", 1.0);
    hold on
    plot(sig.t(idx), sig.omega2(idx), "LineWidth", 1.0);
    grid on
    ylabel("\omega [rad/s]")
    legend(["omega1", "omega2"], "Location", "best")

    nexttile
    plot(sig.t(idx), sig.current_cmd(idx), "LineWidth", 1.0);
    hold on
    plot(sig.t(idx), sig.current(idx), "LineWidth", 1.0);
    grid on
    ylabel("current [A]")
    legend(["i_{cmd}", "i"], "Location", "best")

    nexttile
    stairs(sig.t(idx), sig.enable(idx), "LineWidth", 1.0);
    grid on
    ylabel("enable")
    xlabel("time [s]")
end

%%

%% Save this inspected run, if it looks correct
% Pick the line matching the hardware deployment condition:
%
% saved = saveCurrentWorkspaceSwingupHardwareRun(simout1, ...
%     ActionScale=0.4, CurrentLimitAbs=4.0);
%
% saved = saveCurrentWorkspaceSwingupHardwareRun(simout1, ...
%     ActionScale=1.0, CurrentLimitAbs=4.0);
%
% saved = saveCurrentWorkspaceSwingupHardwareRun(simout1, ...
%     ActionScale=1.0, CurrentLimitAbs=0.5);
