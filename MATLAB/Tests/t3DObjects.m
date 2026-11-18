classdef t3DObjects < matlab.unittest.TestCase
%T3DOBJECTS Unit tests for cube, sphere and cylinder generation (Issue #007).

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture({ ...
                root, fullfile(root, 'Graphics')}));
        end
    end

    methods (Test)
        % ------------------------------------------------------------- cube
        function cubeHasEightVerticesAndSixFaces(testCase)
            mesh = cmr.graphics.Cube3D.create(2, [0 0 0], [0.2 0.5 0.9]);

            testCase.verifyEqual(mesh.vertexCount, 8);
            testCase.verifyEqual(mesh.faceCount, 6);
            testCase.verifySize(mesh.vertices, [8 3]);
            testCase.verifyEqual(size(mesh.faces), [1 6]);
        end

        function cubeVerticesAreExpectedCorners(testCase)
            sideLength = 2;
            center = [1 -2 3];
            mesh = cmr.graphics.Cube3D.create(sideLength, center);

            expected = center + sideLength / 2 * [ ...
                -1 -1 -1; 1 -1 -1; 1 1 -1; -1 1 -1; ...
                -1 -1 1; 1 -1 1; 1 1 1; -1 1 1];

            testCase.verifyEqual(sortrows(mesh.vertices), sortrows(expected), ...
                'AbsTol', 1e-12);
        end

        function cubeFacesAreQuadsWithOutwardNormals(testCase)
            center = [2 -1 4];
            mesh = cmr.graphics.Cube3D.create(3, center);
            normals = cmr.graphics.Mesh3D.faceNormals(mesh);

            testCase.verifyTrue(all(cellfun(@numel, mesh.faces) == 4));

            for faceIndex = 1:mesh.faceCount
                faceCenter = mean( ...
                    mesh.vertices(mesh.faces{faceIndex}, :), 1);
                outward = faceCenter - center;

                testCase.verifyGreaterThan(dot(normals(faceIndex, :), outward), 0, ...
                    sprintf('Face %d must point outwards.', faceIndex));
                testCase.verifyEqual( ...
                    max(abs(normals(faceIndex, :))), 1, 'AbsTol', 1e-12, ...
                    'Cube face normals must be axis-aligned.');
            end
        end

        function cubeEdgesHaveSideLength(testCase)
            sideLength = 3.5;
            mesh = cmr.graphics.Cube3D.create(sideLength);

            edges = zeros(0, 2);
            for faceIndex = 1:mesh.faceCount
                face = mesh.faces{faceIndex};
                for corner = 1:numel(face)
                    a = face(corner);
                    b = face(mod(corner, numel(face)) + 1);
                    edges(end + 1, :) = sort([a, b]); %#ok<AGROW>
                end
            end
            edges = unique(edges, 'rows');

            testCase.verifySize(edges, [12 2]);
            for edgeIndex = 1:size(edges, 1)
                length = norm(mesh.vertices(edges(edgeIndex, 1), :) ...
                    - mesh.vertices(edges(edgeIndex, 2), :));
                testCase.verifyEqual(length, sideLength, 'AbsTol', 1e-12);
            end
        end

        function cubeMetadataMatchesGeometry(testCase)
            sideLength = 3;
            mesh = cmr.graphics.Cube3D.create(sideLength);

            testCase.verifyEqual(mesh.parameters.volume, 27, 'AbsTol', 1e-12);
            testCase.verifyEqual(mesh.parameters.surfaceArea, 54, ...
                'AbsTol', 1e-12);
            [minimum, maximum] = cmr.graphics.Mesh3D.bounds(mesh);
            testCase.verifyEqual(maximum - minimum, [3 3 3], 'AbsTol', 1e-12);
        end

        function cubeRejectsInvalidInputs(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Cube3D.create(0), ...
                'cmr:graphics:Cube3D:invalidSideLength');
            testCase.verifyError( ...
                @() cmr.graphics.Cube3D.create(NaN), ...
                'cmr:graphics:Cube3D:invalidSideLength');
            testCase.verifyError( ...
                @() cmr.graphics.Cube3D.create(2, [0 0]), ...
                'cmr:graphics:Cube3D:invalidCenter');
            testCase.verifyError( ...
                @() cmr.graphics.Cube3D.create(2, [0 0 NaN]), ...
                'cmr:graphics:Cube3D:invalidCenter');
            testCase.verifyError( ...
                @() cmr.graphics.Cube3D.create(2, [0 0 0], [1.2 0 0]), ...
                'cmr:graphics:Mesh3D:invalidColor');
        end

        % ----------------------------------------------------------- sphere
        function sphereParameterRange(testCase)
            [theta, phi] = cmr.graphics.Sphere3D.parameterValues(6, 8);

            testCase.verifySize(theta, [1 9]);
            testCase.verifySize(phi, [1 7]);
            testCase.verifyEqual(theta(1), 0);
            testCase.verifyEqual(theta(end), 2 * pi, 'AbsTol', 1e-12);
            testCase.verifyEqual(phi(1), 0);
            testCase.verifyEqual(phi(end), pi, 'AbsTol', 1e-12);
            testCase.verifyEqual(diff(theta), repmat(2 * pi / 8, 1, 8), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(diff(phi), repmat(pi / 6, 1, 6), ...
                'AbsTol', 1e-12);
        end

        function sphereGridSizeAndSeam(testCase)
            center = [1 2 3];
            radius = 2;
            [X, Y, Z] = cmr.graphics.Sphere3D.coordinates( ...
                radius, center, 6, 8);

            testCase.verifySize(X, [7 9]);
            testCase.verifySize(Y, [7 9]);
            testCase.verifySize(Z, [7 9]);
            testCase.verifyEqual(X(:, 1), X(:, end), 'AbsTol', 1e-12);
            testCase.verifyEqual(Y(:, 1), Y(:, end), 'AbsTol', 1e-12);
            testCase.verifyEqual(Z(:, 1), Z(:, end), 'AbsTol', 1e-12);
            testCase.verifyEqual(X(1, :), repmat(center(1), 1, 9), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(Y(1, :), repmat(center(2), 1, 9), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(Z(1, :), repmat(center(3) + radius, 1, 9), ...
                'AbsTol', 1e-12);
        end

        function sphereCoordinatesSatisfyEquation(testCase)
            center = [1 -2 0.5];
            radius = 2.5;
            [X, Y, Z] = cmr.graphics.Sphere3D.coordinates( ...
                radius, center, 12, 16);

            radialSquared = (X - center(1)).^2 + (Y - center(2)).^2 ...
                + (Z - center(3)).^2;
            testCase.verifyEqual(radialSquared, ...
                repmat(radius^2, size(X)), 'AbsTol', 1e-10);
        end

        function sphereMeshCounts(testCase)
            latitudeBands = 6;
            longitudeBands = 8;
            mesh = cmr.graphics.Sphere3D.create( ...
                1, [0 0 0], latitudeBands, longitudeBands);

            expectedVertices = 2 + (latitudeBands - 1) * longitudeBands;
            expectedFaces = latitudeBands * longitudeBands;

            testCase.verifyEqual(mesh.vertexCount, expectedVertices);
            testCase.verifyEqual(mesh.faceCount, expectedFaces);
            testCase.verifyEqual( ...
                sum(cellfun(@numel, mesh.faces) == 3), 2 * longitudeBands);
            testCase.verifyEqual( ...
                sum(cellfun(@numel, mesh.faces) == 4), ...
                (latitudeBands - 2) * longitudeBands);
        end

        function sphereVerticesLieOnRadius(testCase)
            center = [1 2 3];
            radius = 2.5;
            mesh = cmr.graphics.Sphere3D.create(radius, center, 10, 12);

            distances = vecnorm(mesh.vertices - center, 2, 2);
            testCase.verifyEqual(distances, ...
                repmat(radius, mesh.vertexCount, 1), 'AbsTol', 1e-12);

            northCount = sum(abs(mesh.vertices(:, 3) - (center(3) + radius)) ...
                < 1e-12);
            southCount = sum(abs(mesh.vertices(:, 3) - (center(3) - radius)) ...
                < 1e-12);
            testCase.verifyEqual(northCount, 1);
            testCase.verifyEqual(southCount, 1);
        end

        function sphereFacesPointOutward(testCase)
            center = [0 0 0];
            mesh = cmr.graphics.Sphere3D.create(1, center, 8, 12);
            normals = cmr.graphics.Mesh3D.faceNormals(mesh);

            testCase.verifyEqual(vecnorm(normals, 2, 2), ...
                ones(mesh.faceCount, 1), 'AbsTol', 1e-12);

            for faceIndex = 1:mesh.faceCount
                faceCenter = mean( ...
                    mesh.vertices(mesh.faces{faceIndex}, :), 1);
                radial = faceCenter / norm(faceCenter);
                testCase.verifyGreaterThan(dot(normals(faceIndex, :), radial), 0, ...
                    sprintf('Sphere face %d must point outwards.', faceIndex));
            end
        end

        function sphereMetadataMatchesAnalyticalValues(testCase)
            radius = 1.75;
            mesh = cmr.graphics.Sphere3D.create(radius, [0 0 0], 12, 16);

            testCase.verifyEqual(mesh.parameters.volume, ...
                4 * pi * radius^3 / 3, 'AbsTol', 1e-12);
            testCase.verifyEqual(mesh.parameters.surfaceArea, ...
                4 * pi * radius^2, 'AbsTol', 1e-12);
        end

        function sphereRejectsInvalidInputs(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Sphere3D.create(0), ...
                'cmr:graphics:Sphere3D:invalidRadius');
            testCase.verifyError( ...
                @() cmr.graphics.Sphere3D.create(1, [0 0]), ...
                'cmr:graphics:Sphere3D:invalidCenter');
            testCase.verifyError( ...
                @() cmr.graphics.Sphere3D.create(1, [0 0 0], 1, 8), ...
                'cmr:graphics:Sphere3D:invalidLatitudeBands');
            testCase.verifyError( ...
                @() cmr.graphics.Sphere3D.create(1, [0 0 0], 4, 2), ...
                'cmr:graphics:Sphere3D:invalidLongitudeBands');
            testCase.verifyError( ...
                @() cmr.graphics.Sphere3D.create(1, [0 0 0], 4.5, 8), ...
                'cmr:graphics:Sphere3D:invalidLatitudeBands');
        end

        % --------------------------------------------------------- cylinder
        function cylinderParameterValues(testCase)
            theta = cmr.graphics.Cylinder3D.parameterValues(8);

            testCase.verifySize(theta, [1 8]);
            testCase.verifyEqual(theta(1), 0);
            testCase.verifyTrue(theta(end) < 2 * pi);
            testCase.verifyEqual(diff(theta), repmat(2 * pi / 8, 1, 7), ...
                'AbsTol', 1e-12);
        end

        function cylinderVertexAndFaceCounts(testCase)
            radialSegments = 10;
            mesh = cmr.graphics.Cylinder3D.create( ...
                1.5, 4, [0 0 0], radialSegments);

            testCase.verifyEqual(mesh.vertexCount, 2 * radialSegments);
            testCase.verifyEqual(mesh.faceCount, radialSegments + 2);
            testCase.verifyEqual( ...
                sum(cellfun(@numel, mesh.faces) == 4), radialSegments);
            testCase.verifyEqual( ...
                sum(cellfun(@numel, mesh.faces) == radialSegments), 2);
        end

        function cylinderRadiusHeightAndCentre(testCase)
            radius = 1.5;
            height = 4;
            center = [2 -3 1];
            radialSegments = 12;
            mesh = cmr.graphics.Cylinder3D.create( ...
                radius, height, center, radialSegments);

            radialDistances = hypot( ...
                mesh.vertices(:, 1) - center(1), ...
                mesh.vertices(:, 2) - center(2));
            testCase.verifyEqual(radialDistances, ...
                repmat(radius, mesh.vertexCount, 1), 'AbsTol', 1e-12);

            bottomZ = center(3) - height / 2;
            topZ = center(3) + height / 2;
            testCase.verifyEqual(sum(abs(mesh.vertices(:, 3) - bottomZ) < 1e-12), ...
                radialSegments);
            testCase.verifyEqual(sum(abs(mesh.vertices(:, 3) - topZ) < 1e-12), ...
                radialSegments);
            testCase.verifyEqual(max(mesh.vertices(:, 3)) ...
                - min(mesh.vertices(:, 3)), height, 'AbsTol', 1e-12);
        end

        function cylinderCapsUseEveryRingVertex(testCase)
            radialSegments = 9;
            mesh = cmr.graphics.Cylinder3D.create( ...
                1, 2, [0 0 0], radialSegments);

            bottomCap = mesh.faces{radialSegments + 1};
            topCap = mesh.faces{radialSegments + 2};

            testCase.verifyEqual(sort(bottomCap), 1:radialSegments);
            testCase.verifyEqual(sort(topCap), ...
                radialSegments + (1:radialSegments));
            testCase.verifyEqual(bottomCap, fliplr(1:radialSegments));
        end

        function cylinderFacesPointOutward(testCase)
            radius = 2;
            height = 5;
            center = [1 2 3];
            radialSegments = 8;
            mesh = cmr.graphics.Cylinder3D.create( ...
                radius, height, center, radialSegments);
            normals = cmr.graphics.Mesh3D.faceNormals(mesh);

            for segment = 1:radialSegments
                faceCenter = mean( ...
                    mesh.vertices(mesh.faces{segment}, :), 1);
                radial = [faceCenter(1) - center(1), ...
                          faceCenter(2) - center(2), 0];
                radial = radial / norm(radial);

                testCase.verifyGreaterThan( ...
                    dot(normals(segment, :), radial), 0, ...
                    sprintf('Cylinder side %d must point outwards.', segment));
            end

            testCase.verifyEqual(normals(radialSegments + 1, :), ...
                [0 0 -1], 'AbsTol', 1e-12);
            testCase.verifyEqual(normals(radialSegments + 2, :), ...
                [0 0 1], 'AbsTol', 1e-12);
        end

        function cylinderSideGridMatchesMesh(testCase)
            radius = 1.5;
            height = 4;
            center = [1 2 3];
            radialSegments = 8;
            [theta, X, Y, Z] = cmr.graphics.Cylinder3D.sideGrid( ...
                radius, height, center, radialSegments);
            mesh = cmr.graphics.Cylinder3D.create( ...
                radius, height, center, radialSegments);

            testCase.verifySize(theta, [1 9]);
            testCase.verifySize(X, [2 9]);
            testCase.verifySize(Y, [2 9]);
            testCase.verifySize(Z, [2 9]);

            bottomRing = mesh.vertices(1:radialSegments, :);
            topRing = mesh.vertices(radialSegments + (1:radialSegments), :);

            testCase.verifyEqual([X(1, 1:end - 1)', Y(1, 1:end - 1)', ...
                Z(1, 1:end - 1)'], bottomRing, 'AbsTol', 1e-12);
            testCase.verifyEqual([X(2, 1:end - 1)', Y(2, 1:end - 1)', ...
                Z(2, 1:end - 1)'], topRing, 'AbsTol', 1e-12);
            testCase.verifyEqual(X(:, 1), X(:, end), 'AbsTol', 1e-12);
            testCase.verifyEqual(Y(:, 1), Y(:, end), 'AbsTol', 1e-12);
        end

        function cylinderCapCoordinatesAreClosedCircles(testCase)
            radius = 2;
            center = [1 -1 3];
            radialSegments = 12;
            [X, Y] = cmr.graphics.Cylinder3D.capCoordinates( ...
                radius, center, radialSegments);

            testCase.verifySize(X, [1 13]);
            testCase.verifySize(Y, [1 13]);
            testCase.verifyEqual(X(1), X(end), 'AbsTol', 1e-12);
            testCase.verifyEqual(Y(1), Y(end), 'AbsTol', 1e-12);
            testCase.verifyEqual( ...
                hypot(X - center(1), Y - center(2)), ...
                repmat(radius, 1, 13), 'AbsTol', 1e-12);
        end

        function cylinderMetadataApproachesCircle(testCase)
            radius = 2;
            height = 5;
            mesh = cmr.graphics.Cylinder3D.create( ...
                radius, height, [0 0 0], 720);

            volumeError = abs(mesh.parameters.volume ...
                - pi * radius^2 * height) ...
                / (pi * radius^2 * height);
            areaError = abs(mesh.parameters.surfaceArea ...
                - (2 * pi * radius * height + 2 * pi * radius^2)) ...
                / (2 * pi * radius * height + 2 * pi * radius^2);

            testCase.verifyLessThan(volumeError, 1e-4);
            testCase.verifyLessThan(areaError, 1e-4);
        end

        function cylinderMetadataIsExactForSquarePrism(testCase)
            radius = 2;
            height = 5;
            radialSegments = 4;
            mesh = cmr.graphics.Cylinder3D.create( ...
                radius, height, [0 0 0], radialSegments);

            sideLength = 2 * radius * sin(pi / radialSegments);
            capArea = 0.5 * radialSegments * radius^2 ...
                * sin(2 * pi / radialSegments);
            expectedVolume = capArea * height;
            expectedArea = radialSegments * sideLength * height + 2 * capArea;

            testCase.verifyEqual(mesh.parameters.volume, expectedVolume, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(mesh.parameters.surfaceArea, expectedArea, ...
                'AbsTol', 1e-12);
        end

        function cylinderRejectsInvalidInputs(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Cylinder3D.create(0, 2), ...
                'cmr:graphics:Cylinder3D:invalidRadius');
            testCase.verifyError( ...
                @() cmr.graphics.Cylinder3D.create(1, 0), ...
                'cmr:graphics:Cylinder3D:invalidHeight');
            testCase.verifyError( ...
                @() cmr.graphics.Cylinder3D.create(1, 2, [0 0]), ...
                'cmr:graphics:Cylinder3D:invalidCenter');
            testCase.verifyError( ...
                @() cmr.graphics.Cylinder3D.create(1, 2, [0 0 0], 2), ...
                'cmr:graphics:Cylinder3D:invalidRadialSegments');
            testCase.verifyError( ...
                @() cmr.graphics.Cylinder3D.create(1, 2, [0 0 0], 3.5), ...
                'cmr:graphics:Cylinder3D:invalidRadialSegments');
        end

        function allPrimitiveMeshesTriangulateWithoutDegenerateFaces(testCase)
            meshes = { ...
                cmr.graphics.Cube3D.create(2), ...
                cmr.graphics.Sphere3D.create(1, [0 0 0], 8, 12), ...
                cmr.graphics.Cylinder3D.create(1, 2, [0 0 0], 12)};

            for index = 1:numel(meshes)
                triangles = cmr.graphics.Mesh3D.triangulate(meshes{index});
                testCase.verifyFalse(isempty(triangles));
                testCase.verifyTrue(all(isfinite(triangles(:))));
                testCase.verifyTrue(all(triangles(:) >= 1));
                testCase.verifyTrue(all(triangles(:) <= meshes{index}.vertexCount));
            end
        end
    end
end
