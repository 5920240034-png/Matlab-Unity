function outputs = demo3DObjects(outputDirectory, meshDirectory)
%DEMO3DOBJECTS Render the Issue #007 cube, sphere and cylinder.
%
%   outputs = demo3DObjects() builds the three geometric objects from
%   coordinates and equations, renders them, and writes evidence files:
%
%       Deliverables/Screenshots/Issue007_3D_Objects.png
%       Deliverables/Screenshots/Issue007_3D_Views.png
%       Deliverables/Screenshots/Issue007_3D_Mesh_Structure.png
%
%       Shared_Data/Meshes/cube.obj
%       Shared_Data/Meshes/sphere.obj
%       Shared_Data/Meshes/cylinder.obj
%
%   outputs = demo3DObjects(outputDirectory) writes the PNG files to the
%   requested folder instead. A second output folder can be supplied for the
%   OBJ meshes:
%
%       demo3DObjects(screenshotFolder, meshFolder)
%
%   Figure windows are shown in the MATLAB desktop and kept invisible under
%   matlab -batch, matching the other Issue demonstrations.

    arguments
        outputDirectory (1,1) string = ""
        meshDirectory (1,1) string = ""
    end

    here = fileparts(mfilename('fullpath'));     % MATLAB/Graphics
    matlabRoot = fileparts(here);                % MATLAB
    projectRoot = fileparts(matlabRoot);         % repository root

    addpath(genpath(matlabRoot));

    if strlength(outputDirectory) == 0
        outputDirectory = string(fullfile( ...
            projectRoot, 'Deliverables', 'Screenshots'));
    end
    if strlength(meshDirectory) == 0
        meshDirectory = string(fullfile( ...
            projectRoot, 'Shared_Data', 'Meshes'));
    end
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end
    if ~isfolder(meshDirectory)
        mkdir(meshDirectory);
    end

    outputs = strings(0, 1);

    fprintf('Clean My Room - Issue #007 3D geometric objects\n');
    fprintf('MATLAB %s on %s\n', version, computer);

    %% Build the three objects from coordinates and equations --------------
    cubeColor = [0.20, 0.52, 0.90];
    sphereColor = [0.15, 0.70, 0.45];
    cylinderColor = [0.95, 0.55, 0.15];

    cubeSize = 3;
    sphereRadius = 1.5;
    cylinderRadius = 1.2;
    cylinderHeight = 3;

    cube = cmr.graphics.Cube3D.create(cubeSize, [0 0 0], cubeColor);
    sphere = cmr.graphics.Sphere3D.create( ...
        sphereRadius, [0 0 0], 40, 56, sphereColor);
    cylinder = cmr.graphics.Cylinder3D.create( ...
        cylinderRadius, cylinderHeight, [0 0 0], 48, cylinderColor);

    fprintf('\nGenerated meshes:\n');
    printMeshSummary(cube);
    printMeshSummary(sphere);
    printMeshSummary(cylinder);

    %% Export the meshes for a future Unity import -------------------------
    meshFiles = [ ...
        cmr.graphics.Mesh3D.exportOBJ(cube, ...
            fullfile(meshDirectory, 'cube.obj')); ...
        cmr.graphics.Mesh3D.exportOBJ(sphere, ...
            fullfile(meshDirectory, 'sphere.obj')); ...
        cmr.graphics.Mesh3D.exportOBJ(cylinder, ...
            fullfile(meshDirectory, 'cylinder.obj'))];

    fprintf('\nExported OBJ meshes:\n');
    for index = 1:numel(meshFiles)
        info = dir(meshFiles(index));
        fprintf('  %s (%d bytes)\n', meshFiles(index), info.bytes);
    end

    %% Figure 1 - shaded gallery -------------------------------------------
    fig1 = figure('Visible', figureVisibility(), 'Color', 'w', ...
        'Name', 'Issue #007 - 3D geometric objects', ...
        'Position', [60 80 1620 620]);
    layout1 = tiledlayout(fig1, 1, 3, ...
        'TileSpacing', 'compact', 'Padding', 'compact');

    axCube = nexttile(layout1);
    cubePatch = drawCube(axCube, cube);
    finishObjectAxes(axCube, cubePatch, 'Cube: 8 vertices, 6 quad faces');

    axSphere = nexttile(layout1);
    sphereSurface = drawSphere(axSphere, sphere);
    finishObjectAxes(axSphere, sphereSurface, ...
        'Sphere: parametric (theta, phi) surface');

    axCylinder = nexttile(layout1);
    cylinderSurface = drawCylinder(axCylinder, cylinder);
    finishObjectAxes(axCylinder, cylinderSurface, ...
        'Cylinder: side surface plus two caps');

    sgtitle(fig1, { ...
        'Issue #007 - Basic 3D geometric objects constructed in MATLAB', ...
        'Cube: vertices + quad faces | Sphere: x = r sin(phi) cos(theta), y = r sin(phi) sin(theta), z = r cos(phi) | Cylinder: circular rings + caps'}, ...
        'FontWeight', 'bold', 'FontSize', 11, 'Interpreter', 'none');

    file1 = fullfile(outputDirectory, 'Issue007_3D_Objects.png');
    exportFigure(fig1, file1);
    outputs(end + 1, 1) = file1;
    maybeCloseFigure(fig1);

    %% Figure 2 - the same scene from four viewing angles -----------------
    fig2 = figure('Visible', figureVisibility(), 'Color', 'w', ...
        'Name', 'Issue #007 - viewing angles', ...
        'Position', [100 60 1320 1020]);
    layout2 = tiledlayout(fig2, 2, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');

    views = [ ...
        45, 25; ...    % isometric
         0,  0; ...    % front
        90,  0; ...    % side
         0, 90];      % top
    viewNames = { ...
        'Isometric view (az = 45 deg, el = 25 deg)', ...
        'Front view (az = 0 deg, el = 0 deg)', ...
        'Side view (az = 90 deg, el = 0 deg)', ...
        'Top view (az = 0 deg, el = 90 deg)'};

    for index = 1:size(views, 1)
        ax = nexttile(layout2);
        drawScene(ax, cube, sphere, cylinder);
        view(ax, views(index, 1), views(index, 2));
        styleSceneAxes(ax);
        title(ax, viewNames{index}, 'FontWeight', 'bold', 'FontSize', 10);
    end

    sgtitle(fig2, { ...
        'Issue #007 - one scene, four viewing angles', ...
        'axis equal, grid on, orthographic projection: cube, sphere and cylinder keep their proportions'}, ...
        'FontWeight', 'bold', 'FontSize', 11);

    file2 = fullfile(outputDirectory, 'Issue007_3D_Views.png');
    exportFigure(fig2, file2);
    outputs(end + 1, 1) = file2;
    maybeCloseFigure(fig2);

    %% Figure 3 - mesh construction ----------------------------------------
    sphereWire = cmr.graphics.Sphere3D.create( ...
        sphereRadius, [0 0 0], 12, 24, sphereColor);
    cylinderWire = cmr.graphics.Cylinder3D.create( ...
        cylinderRadius, cylinderHeight, [0 0 0], 24, cylinderColor);

    fig3 = figure('Visible', figureVisibility(), 'Color', 'w', ...
        'Name', 'Issue #007 - mesh structure', ...
        'Position', [60 80 1620 620]);
    layout3 = tiledlayout(fig3, 1, 3, ...
        'TileSpacing', 'compact', 'Padding', 'compact');

    axCubeMesh = nexttile(layout3);
    drawCubeWireframe(axCubeMesh, cube);
    title(axCubeMesh, sprintf('Cube mesh: %d vertices, %d quad faces', ...
        cube.vertexCount, cube.faceCount), 'FontWeight', 'bold');
    styleMeshAxes(axCubeMesh);

    axSphereMesh = nexttile(layout3);
    drawSphereWireframe(axSphereMesh, sphereWire);
    title(axSphereMesh, sprintf('Sphere mesh: %d vertices, %d faces', ...
        sphereWire.vertexCount, sphereWire.faceCount), 'FontWeight', 'bold');
    styleMeshAxes(axSphereMesh);

    axCylinderMesh = nexttile(layout3);
    drawCylinderWireframe(axCylinderMesh, cylinderWire);
    title(axCylinderMesh, sprintf('Cylinder mesh: %d vertices, %d faces', ...
        cylinderWire.vertexCount, cylinderWire.faceCount), 'FontWeight', 'bold');
    styleMeshAxes(axCylinderMesh);

    sgtitle(fig3, { ...
        'Issue #007 - polygon mesh construction', ...
        'Cube: 8 corners + 6 quads | Sphere: pole vertices, latitude rings and longitude bands | Cylinder: two rings + side quads + two caps'}, ...
        'FontWeight', 'bold', 'FontSize', 11, 'Interpreter', 'none');

    file3 = fullfile(outputDirectory, 'Issue007_3D_Mesh_Structure.png');
    exportFigure(fig3, file3);
    outputs(end + 1, 1) = file3;
    maybeCloseFigure(fig3);

    %% Console verification summary ---------------------------------------
    fprintf('\nMesh verification:\n');
    fprintf('  cube     : %d vertices, %d faces, volume = %.4f, surface = %.4f\n', ...
        cube.vertexCount, cube.faceCount, ...
        cube.parameters.volume, cube.parameters.surfaceArea);
    fprintf('  sphere   : %d vertices, %d faces, radius = %.4f\n', ...
        sphere.vertexCount, sphere.faceCount, sphere.parameters.radius);
    fprintf('  cylinder : %d vertices, %d faces, radius = %.4f, height = %.4f\n', ...
        cylinder.vertexCount, cylinder.faceCount, ...
        cylinder.parameters.radius, cylinder.parameters.height);

    [minimum, maximum] = cmr.graphics.Mesh3D.bounds(cube);
    fprintf('  cube bounds: [%.2f %.2f %.2f] to [%.2f %.2f %.2f]\n', ...
        minimum, maximum);

    fprintf('\nSaved %d evidence figures:\n', numel(outputs));
    for index = 1:numel(outputs)
        fprintf('  %s\n', outputs(index));
    end
end

%% Local drawing helpers ----------------------------------------------------
function patchHandle = drawCube(ax, mesh)
    % A cube has six quad faces, so patch can receive the 6-by-4 matrix
    % directly. This keeps the visible edges on the real cube edges instead
    % of showing triangulation diagonals.
    faces = cell2mat(mesh.faces);
    patchHandle = patch(ax, 'Vertices', mesh.vertices, 'Faces', faces, ...
        'FaceColor', mesh.color, 'EdgeColor', [0.10 0.15 0.22], ...
        'LineWidth', 0.9, 'FaceLighting', 'flat');
end

function surfaceHandle = drawSphere(ax, mesh)
    p = mesh.parameters;
    [X, Y, Z] = cmr.graphics.Sphere3D.coordinates( ...
        p.radius, p.center, p.latitudeBands, p.longitudeBands);

    % Truecolor CData keeps the object uniformly coloured while
    % shading interp smoothly interpolates the surface lighting.
    C = repmat(reshape(mesh.color, 1, 1, 3), size(X, 1), size(X, 2), 1);
    surfaceHandle = surf(ax, X, Y, Z, C, ...
        'EdgeColor', 'none', 'FaceColor', 'interp', ...
        'FaceLighting', 'gouraud');
end

function surfaceHandle = drawCylinder(ax, mesh)
    % The side surf, both fill3 caps and any caller graphics must coexist, so
    % hold must be on: high-level fill3 calls clear the axes when hold is off.
    wasHeld = ishold(ax);
    hold(ax, 'on');

    p = mesh.parameters;
    [~, X, Y, Z] = cmr.graphics.Cylinder3D.sideGrid( ...
        p.radius, p.height, p.center, p.radialSegments);
    C = repmat(reshape(mesh.color, 1, 1, 3), size(X, 1), size(X, 2), 1);

    surfaceHandle = surf(ax, X, Y, Z, C, ...
        'EdgeColor', 'none', 'FaceColor', 'interp', ...
        'FaceLighting', 'gouraud');

    [capX, capY] = cmr.graphics.Cylinder3D.capCoordinates( ...
        p.radius, p.center, p.radialSegments);
    bottomZ = p.center(3) - p.height / 2;
    topZ = p.center(3) + p.height / 2;
    capColor = min(1, mesh.color + 0.06);

    fill3(ax, capX, capY, repmat(bottomZ, size(capX)), capColor, ...
        'EdgeColor', 'none', 'FaceLighting', 'flat');
    fill3(ax, capX, capY, repmat(topZ, size(capX)), capColor, ...
        'EdgeColor', 'none', 'FaceLighting', 'flat');

    if ~wasHeld
        hold(ax, 'off');
    end
end

function drawScene(ax, cube, sphere, cylinder)
    cubeX = -4.5;
    cylinderX = 4.5;

    % Move the primitive meshes without changing their stored geometry.
    cubeMesh = cube;
    cubeMesh.vertices = cube.vertices + [cubeX, 0, 0];
    cubeMesh.parameters.center = cube.parameters.center + [cubeX, 0, 0];

    sphereMesh = sphere;

    cylinderMesh = cylinder;
    cylinderMesh.vertices = cylinder.vertices + [cylinderX, 0, 0];
    cylinderMesh.parameters.center = ...
        cylinder.parameters.center + [cylinderX, 0, 0];

    hold(ax, 'on');

    % Draw the smooth surfaces first, then the cube last so the cube keeps
    % its flat-coloured faces. The surf handles already carry their own
    % FaceColor/FaceLighting interpolation, so no axes-wide shading call is
    % needed (and an axes-wide call would corrupt the fill3 caps).
    drawSphere(ax, sphereMesh);
    drawCylinder(ax, cylinderMesh);
    cubePatch = drawCube(ax, cubeMesh);

    text(ax, cubeX, 0, 2.25, 'Cube', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 10);
    text(ax, 0, 0, 2.25, 'Sphere', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 10);
    text(ax, cylinderX, 0, 2.25, 'Cylinder', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 10);

    camlight(ax, 'headlight');
    material(ax, 'dull');
    set(cubePatch, 'FaceLighting', 'flat');
    hold(ax, 'off');
end

function finishObjectAxes(ax, graphicHandle, titleText)
    axis(ax, 'equal');
    grid(ax, 'on');
    box(ax, 'on');
    xlim(ax, [-2.1, 2.1]);
    ylim(ax, [-2.1, 2.1]);
    zlim(ax, [-2.1, 2.1]);
    xlabel(ax, 'x');
    ylabel(ax, 'y');
    zlabel(ax, 'z');
    view(ax, 45, 25);
    camlight(ax, 'headlight');
    material(ax, 'dull');
    title(ax, titleText, 'FontWeight', 'bold', 'FontSize', 10);

    % The cube came from patch, the other two from surf. Setting the
    % properties here keeps the cube's edges crisp and the curved objects
    % smooth.
    if isa(graphicHandle, 'matlab.graphics.primitive.Patch')
        set(graphicHandle, 'FaceLighting', 'flat');
    end
end

function styleSceneAxes(ax)
    axis(ax, 'equal');
    grid(ax, 'on');
    box(ax, 'on');
    xlim(ax, [-6.7, 6.2]);
    ylim(ax, [-2.2, 2.2]);
    zlim(ax, [-2.0, 2.7]);
    xlabel(ax, 'x');
    ylabel(ax, 'y');
    zlabel(ax, 'z');
    camlight(ax, 'headlight');
    material(ax, 'dull');
end

function styleMeshAxes(ax)
    axis(ax, 'equal');
    grid(ax, 'on');
    box(ax, 'on');
    xlim(ax, [-2.1, 2.1]);
    ylim(ax, [-2.1, 2.1]);
    zlim(ax, [-2.1, 2.1]);
    xlabel(ax, 'x');
    ylabel(ax, 'y');
    zlabel(ax, 'z');
    view(ax, 45, 25);
end

function drawCubeWireframe(ax, mesh)
    wasHeld = ishold(ax);
    hold(ax, 'on');

    patch(ax, 'Vertices', mesh.vertices, 'Faces', cell2mat(mesh.faces), ...
        'FaceColor', 'none', 'EdgeColor', [0.16, 0.32, 0.55], ...
        'LineWidth', 1.2);
    plot3(ax, mesh.vertices(:, 1), mesh.vertices(:, 2), mesh.vertices(:, 3), ...
        'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.98, 0.80, 0.20], ...
        'MarkerEdgeColor', [0.20, 0.15, 0.05]);

    if ~wasHeld
        hold(ax, 'off');
    end
end

function drawSphereWireframe(ax, mesh)
    wasHeld = ishold(ax);
    hold(ax, 'on');

    p = mesh.parameters;
    [X, Y, Z] = cmr.graphics.Sphere3D.coordinates( ...
        p.radius, p.center, p.latitudeBands, p.longitudeBands);
    surf(ax, X, Y, Z, 'FaceColor', 'none', ...
        'EdgeColor', [0.20, 0.55, 0.36], 'LineWidth', 0.5);
    plot3(ax, mesh.vertices(1, 1), mesh.vertices(1, 2), mesh.vertices(1, 3), ...
        'o', 'MarkerSize', 6, 'MarkerFaceColor', [0.98, 0.80, 0.20], ...
        'MarkerEdgeColor', [0.20, 0.15, 0.05]);
    plot3(ax, mesh.vertices(end, 1), mesh.vertices(end, 2), mesh.vertices(end, 3), ...
        'o', 'MarkerSize', 6, 'MarkerFaceColor', [0.98, 0.80, 0.20], ...
        'MarkerEdgeColor', [0.20, 0.15, 0.05]);

    if ~wasHeld
        hold(ax, 'off');
    end
end

function drawCylinderWireframe(ax, mesh)
    wasHeld = ishold(ax);
    hold(ax, 'on');

    p = mesh.parameters;
    [~, X, Y, Z] = cmr.graphics.Cylinder3D.sideGrid( ...
        p.radius, p.height, p.center, p.radialSegments);
    surf(ax, X, Y, Z, 'FaceColor', 'none', ...
        'EdgeColor', [0.75, 0.40, 0.10], 'LineWidth', 0.8);

    [capX, capY] = cmr.graphics.Cylinder3D.capCoordinates( ...
        p.radius, p.center, p.radialSegments);
    bottomZ = p.center(3) - p.height / 2;
    topZ = p.center(3) + p.height / 2;
    fill3(ax, capX, capY, repmat(bottomZ, size(capX)), 'w', ...
        'FaceColor', 'none', 'EdgeColor', [0.75, 0.40, 0.10], ...
        'LineWidth', 0.9);
    fill3(ax, capX, capY, repmat(topZ, size(capX)), 'w', ...
        'FaceColor', 'none', 'EdgeColor', [0.75, 0.40, 0.10], ...
        'LineWidth', 0.9);

    if ~wasHeld
        hold(ax, 'off');
    end
end

function printMeshSummary(mesh)
    [minimum, maximum] = cmr.graphics.Mesh3D.bounds(mesh);
    fprintf('  %-8s : %4d vertices, %4d faces, bounds [%.2f %.2f %.2f] to [%.2f %.2f %.2f]\n', ...
        char(mesh.name), mesh.vertexCount, mesh.faceCount, ...
        minimum, maximum);
end

function visibility = figureVisibility()
    % Show figure windows in the desktop, stay headless in -batch.
    if usejava('desktop')
        visibility = 'on';
    else
        visibility = 'off';
    end
end

function reportSaved(filePath)
    info = dir(filePath);
    if isempty(info)
        error('demo3DObjects:exportFailed', ...
            'Figure was not written: %s', filePath);
    end
    fprintf('Saved %s (%d bytes)\n', filePath, info.bytes);
end

function exportFigure(fig, filePath)
    % exportgraphics can fail transiently in headless matlab -batch sessions
    % on some Windows GPU/driver combinations. A drawnow plus one retry
    % recovers without hiding a real failure: the original error is rethrown
    % when the second attempt also fails.
    try
        exportgraphics(fig, char(filePath), 'Resolution', 130);
    catch firstError
        drawnow;
        try
            exportgraphics(fig, char(filePath), 'Resolution', 130);
        catch
            rethrow(firstError);
        end
    end
    reportSaved(filePath);
end

function maybeCloseFigure(fig)
    % Keep figures open in the MATLAB desktop, but release their graphics
    % memory immediately in matlab -batch so the next figure can be built on
    % memory-constrained machines.
    if ~usejava('desktop')
        close(fig);
    end
end
