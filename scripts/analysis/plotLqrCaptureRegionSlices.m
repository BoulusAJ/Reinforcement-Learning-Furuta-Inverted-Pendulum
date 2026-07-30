function out = plotLqrCaptureRegionSlices(options)
%PLOTLQRCAPTUREREGIONSLICES Plot 2D/3D slices of the upright LQR capture ellipsoid.
%
% The full local LQR capture metric is four-dimensional:
%
%   x = [theta1_error; theta2_upright_error; omega1; omega2]
%   V = x' * P_oben * x
%
% This script plots useful lower-dimensional slices of V = rho. Figures are
% saved as PNG previews and MATLAB FIG files. The FIG files remain interactive
% in MATLAB, so the 3D plots can be rotated and zoomed.
%
% Example:
%
%   addpath(genpath("scripts"));
%   out = plotLqrCaptureRegionSlices();
%
% Optional name-value arguments:
%
%   OutputDir     string, optional explicit output directory
%   Visible       logical, default true
%   SaveFig       logical, default true
%   IMax          double, default 1.5
%   Rhos          double vector, default [0.08 0.10 rhoCurrentLimit]
%   Omega1Slices  double vector, default [5 2 0 -2 -5]

arguments
    options.OutputDir (1,1) string = ""
    options.Visible (1,1) logical = true
    options.SaveFig (1,1) logical = true
    options.IMax (1,1) double = 1.5
    options.Rhos double = []
    options.Omega1Slices double = [5 2 0 -2 -5]
end

repoRoot = localFindRepoRoot();
labPath = fullfile(repoRoot, "references", "zhaw_rotary_pendulum_lab", "lab_model");
addpath(labPath);

param = get_parameter();
theta0 = [0; pi];
[A, B] = linearize_furuta_equilibrium(theta0, param);
B = B * param.km; % Current input instead of torque input.

Q = diag([1 10 0.001 0.001]);
R = 0.5 * 10;
[K, P, poles] = lqr(A, B, Q, R);

rhoCurrentLimit = options.IMax^2 / (K / P * K');
if isempty(options.Rhos)
    rhos = [0.08 0.10 rhoCurrentLimit];
else
    rhos = options.Rhos;
end
rhos = unique(rhos, "stable");

if strlength(options.OutputDir) == 0
    paths = getFurutaPaths(ProjectRoot=repoRoot);
    outDir = fullfile(paths.OutputsRoot, "lqr_capture_region");
else
    outDir = options.OutputDir;
    if ~localIsAbsolutePath(outDir)
        outDir = fullfile(repoRoot, outDir);
    end
end
if ~exist(outDir, "dir")
    mkdir(outDir);
end

visible = "off";
if options.Visible
    visible = "on";
end

colors = lines(numel(rhos));
labels = localRhoLabels(rhos, rhoCurrentLimit, options.IMax);

paths = strings(0, 1);

fig = localPlotTheta2Omega2(P, rhos, labels, colors, visible);
paths(end+1, 1) = localSaveFigure(fig, outDir, "theta2_omega2_slice", options.SaveFig);

fig = localPlotTheta1Omega1(P, rhos, labels, colors, visible);
paths(end+1, 1) = localSaveFigure(fig, outDir, "theta1_omega1_slice", options.SaveFig);

fig = localPlotTheta2Omega2ByTheta1(P, rhos, labels, colors, visible);
paths(end+1, 1) = localSaveFigure(fig, outDir, "theta2_omega2_by_theta1_offsets", options.SaveFig);

for omega1 = options.Omega1Slices(:).'
    fig = localPlot3DSlice(P, rhos, labels, colors, omega1, visible);
    fileStem = "theta1_theta2_omega2_slice_omega1_" + localNumForFile(omega1);
    paths(end+1, 1) = localSaveFigure(fig, outDir, fileStem, options.SaveFig);
end

out = struct( ...
    K=K, ...
    P=P, ...
    Poles=poles, ...
    Rhos=rhos, ...
    RhoCurrentLimit=rhoCurrentLimit, ...
    IMax=options.IMax, ...
    OutputDir=string(outDir), ...
    FigurePngPaths=paths);

save(fullfile(outDir, "lqr_capture_region_data.mat"), ...
    "A", "B", "K", "P", "poles", "Q", "R", "rhos", "rhoCurrentLimit");
end

function tf = localIsAbsolutePath(pathValue)
if ispc
    tf = ~isempty(regexp(pathValue, "^[A-Za-z]:[\\/]", "once")) ...
        || startsWith(pathValue, "\\");
else
    tf = startsWith(pathValue, "/");
end
end

function fig = localPlotTheta2Omega2(P, rhos, labels, colors, visible)
theta2Deg = linspace(-30, 30, 501);
omega2 = linspace(-6, 6, 501);
[TH2, OM2] = meshgrid(deg2rad(theta2Deg), omega2);
V = localQuadraticGrid(P, zeros(size(TH2)), TH2, zeros(size(TH2)), OM2);

fig = figure(Color="w", Visible=visible, Name="LQR capture slice: theta2 vs omega2");
ax = axes(fig);
hold(ax, "on");
contourf(ax, theta2Deg, omega2, V, 40, LineStyle="none", HandleVisibility="off");
colormap(ax, turbo);
cb = colorbar(ax);
cb.Label.String = "V = x^T P x";
for i = 1:numel(rhos)
    contour(ax, theta2Deg, omega2, V, [rhos(i) rhos(i)], ...
        Color=colors(i, :), LineWidth=2.2, DisplayName=labels(i));
end
xline(ax, 0, Color=[0.3 0.3 0.3], LineStyle=":", HandleVisibility="off");
yline(ax, 0, Color=[0.3 0.3 0.3], LineStyle=":", HandleVisibility="off");
grid(ax, "on");
xlabel(ax, "\theta_2 upright error [deg]");
ylabel(ax, "\omega_2 [rad/s]");
title(ax, "\theta_2 / \omega_2 LQR capture slice (\theta_1 = 0, \omega_1 = 0)");
legend(ax, Location="northeastoutside");
end

function fig = localPlotTheta1Omega1(P, rhos, labels, colors, visible)
theta1Deg = linspace(-60, 60, 501);
omega1 = linspace(-8, 8, 501);
[TH1, OM1] = meshgrid(deg2rad(theta1Deg), omega1);
V = localQuadraticGrid(P, TH1, zeros(size(TH1)), OM1, zeros(size(TH1)));

fig = figure(Color="w", Visible=visible, Name="LQR capture slice: theta1 vs omega1");
ax = axes(fig);
hold(ax, "on");
contourf(ax, theta1Deg, omega1, V, 40, LineStyle="none", HandleVisibility="off");
colormap(ax, turbo);
cb = colorbar(ax);
cb.Label.String = "V = x^T P x";
for i = 1:numel(rhos)
    contour(ax, theta1Deg, omega1, V, [rhos(i) rhos(i)], ...
        Color=colors(i, :), LineWidth=2.2, DisplayName=labels(i));
end
xline(ax, 0, Color=[0.3 0.3 0.3], LineStyle=":", HandleVisibility="off");
yline(ax, 0, Color=[0.3 0.3 0.3], LineStyle=":", HandleVisibility="off");
grid(ax, "on");
xlabel(ax, "\theta_1 error [deg]");
ylabel(ax, "\omega_1 [rad/s]");
title(ax, "\theta_1 / \omega_1 LQR capture slice (\theta_2 = 0, \omega_2 = 0)");
legend(ax, Location="northeastoutside");
end

function fig = localPlotTheta2Omega2ByTheta1(P, rhos, labels, colors, visible)
theta1OffsetsDeg = [-20 -10 0 10 20];
theta2Deg = linspace(-30, 30, 401);
omega2 = linspace(-6, 6, 401);
[TH2, OM2] = meshgrid(deg2rad(theta2Deg), omega2);

fig = figure(Color="w", Visible=visible, Name="LQR capture slices: theta1 offsets");
tl = tiledlayout(fig, 2, 3, TileSpacing="compact", Padding="compact");
for k = 1:numel(theta1OffsetsDeg)
    ax = nexttile(tl);
    theta1 = deg2rad(theta1OffsetsDeg(k)) * ones(size(TH2));
    V = localQuadraticGrid(P, theta1, TH2, zeros(size(TH2)), OM2);
    hold(ax, "on");
    contourf(ax, theta2Deg, omega2, V, 35, LineStyle="none", HandleVisibility="off");
    for i = 1:numel(rhos)
        contour(ax, theta2Deg, omega2, V, [rhos(i) rhos(i)], ...
            Color=colors(i, :), LineWidth=1.8, DisplayName=labels(i));
    end
    xline(ax, 0, Color=[0.3 0.3 0.3], LineStyle=":", HandleVisibility="off");
    yline(ax, 0, Color=[0.3 0.3 0.3], LineStyle=":", HandleVisibility="off");
    grid(ax, "on");
    title(ax, "\theta_1 = " + theta1OffsetsDeg(k) + " deg");
    xlabel(ax, "\theta_2 [deg]");
    ylabel(ax, "\omega_2 [rad/s]");
end
ax = nexttile(tl);
axis(ax, "off");
hold(ax, "on");
for i = 1:numel(rhos)
    plot(ax, nan, nan, Color=colors(i, :), LineWidth=2.2, DisplayName=labels(i));
end
legend(ax, Location="best");
title(tl, "\theta_2 / \omega_2 capture slices for fixed \theta_1 offsets (\omega_1 = 0)");
end

function fig = localPlot3DSlice(P, rhos, labels, colors, omega1, visible)
theta1Deg = linspace(-60, 60, 89);
theta2Deg = linspace(-30, 30, 89);
omega2 = linspace(-6, 6, 89);
[TH1, TH2, OM2] = meshgrid(deg2rad(theta1Deg), deg2rad(theta2Deg), omega2);
OM1 = omega1 * ones(size(TH1));
V = localQuadraticGrid(P, TH1, TH2, OM1, OM2);

fig = figure(Color="w", Visible=visible, ...
    Name=sprintf("LQR capture 3D slice: omega1 = %+g rad/s", omega1));
ax = axes(fig);
hold(ax, "on");
surfaceCount = 0;
for i = 1:numel(rhos)
    if min(V, [], "all") <= rhos(i) && max(V, [], "all") >= rhos(i)
        fv = isosurface(theta1Deg, theta2Deg, omega2, V, rhos(i));
        if ~isempty(fv.vertices)
            p = patch(ax, fv);
            p.FaceColor = colors(i, :);
            p.EdgeColor = "none";
            p.FaceAlpha = 0.22 + 0.12 * (i == numel(rhos));
            p.DisplayName = labels(i);
            surfaceCount = surfaceCount + 1;
        end
    end
end
if surfaceCount == 0
    text(ax, 0, 0, 0, "No plotted rho surface intersects this grid", ...
        HorizontalAlignment="center", FontWeight="bold");
end
grid(ax, "on");
xlabel(ax, "\theta_1 error [deg]");
ylabel(ax, "\theta_2 upright error [deg]");
zlabel(ax, "\omega_2 [rad/s]");
title(ax, sprintf("3D capture slice at \\omega_1 = %+g rad/s", omega1));
view(ax, 38, 24);
axis(ax, "vis3d");
camlight(ax, "headlight");
lighting(ax, "gouraud");
legend(ax, Location="northeastoutside");
rotate3d(fig, "on");
end

function V = localQuadraticGrid(P, theta1, theta2, omega1, omega2)
V = P(1,1).*theta1.^2 + P(2,2).*theta2.^2 + ...
    P(3,3).*omega1.^2 + P(4,4).*omega2.^2 + ...
    2*P(1,2).*theta1.*theta2 + 2*P(1,3).*theta1.*omega1 + ...
    2*P(1,4).*theta1.*omega2 + 2*P(2,3).*theta2.*omega1 + ...
    2*P(2,4).*theta2.*omega2 + 2*P(3,4).*omega1.*omega2;
end

function labels = localRhoLabels(rhos, rhoCurrentLimit, iMax)
labels = strings(size(rhos));
for i = 1:numel(rhos)
    if abs(rhos(i) - rhoCurrentLimit) < 1e-6
        labels(i) = sprintf("\\rho = %.4f (%.1f A limit)", rhos(i), iMax);
    else
        labels(i) = sprintf("\\rho = %.4f", rhos(i));
    end
end
end

function pngPath = localSaveFigure(fig, outDir, fileStem, saveFig)
pngPath = fullfile(outDir, fileStem + ".png");
exportgraphics(fig, pngPath, Resolution=200);
if saveFig
    savefig(fig, fullfile(outDir, fileStem + ".fig"));
end
end

function root = localFindRepoRoot()
root = string(pwd);
while root ~= ""
    if isfolder(fullfile(root, ".git"))
        return
    end
    parent = string(fileparts(root));
    if parent == root
        break
    end
    root = parent;
end
error("plotLqrCaptureRegionSlices:RepoRootNotFound", ...
    "Could not find repository root from current directory.");
end

function s = localNumForFile(x)
if x >= 0
    prefix = "plus";
else
    prefix = "minus";
end
s = prefix + replace(sprintf("%.3g", abs(x)), ".", "p");
end
