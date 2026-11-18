classdef tMesh3D < matlab.unittest.TestCase
%TMESH3D Unit tests for the shared polygon mesh and OBJ export (Issue #007).

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture({ ...
                root, fullfile(root, 'Graphics')}));
        end
    end

    methods (Test)
        function createAcceptsNumericFaceMatrix(testCase)
            mesh = tMesh3D.squareMesh();

            testCase.verifyEqual(mesh.name, "square");
            testCase.verifyEqual(mesh.vertexCount, 4);
            testCase.verifyEqual(mesh.faceCount, 1);
            testCase.verifyEqual(mesh.faces{1}, [1 2 3 4]);
            testCase.verifyEqual(mesh.color, [0.2 0.4 0.6]);
        end

        function createAcceptsMixedCellFaces(testCase)
            vertices = [0 0 0; 2 0 0; 2 2 0; 0 2 0; 3 1 0];
            faces = {[1 2 3 4], [2 5 3]};

            mesh = cmr.graphics.Mesh3D.create( ...
                "mixed", vertices, faces, [0.5 0.5 0.5]);

            testCase.verifyEqual(mesh.faceCount, 2);
            testCase.verifyEqual(mesh.faces{1}, [1 2 3 4]);
            testCase.verifyEqual(mesh.faces{2}, [2 5 3]);
        end

        function createPreservesParameters(testCase)
            parameters = struct('radius', 2, 'label', "test");
            mesh = cmr.graphics.Mesh3D.create( ...
                "parameterised", [0 0 0; 1 0 0; 0 1 0], ...
                [1 2 3], [0 0 1], parameters);

            testCase.verifyEqual(mesh.parameters.radius, 2);
            testCase.verifyEqual(mesh.parameters.label, "test");
        end

        function createRejectsTooFewVertices(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create("bad", [0 0 0; 1 0 0], [1 2], [0 0 0]), ...
                'cmr:graphics:Mesh3D:invalidVertices');
        end

        function createRejectsNonFiniteVertices(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "bad", [0 0 0; 1 0 0; NaN 0 0], [1 2 3], [0 0 0]), ...
                'cmr:graphics:Mesh3D:invalidVertices');
        end

        function createRejectsEmptyName(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "", [0 0 0; 1 0 0; 0 1 0], [1 2 3], [0 0 0]), ...
                'cmr:graphics:Mesh3D:invalidName');
        end

        function createRejectsInvalidColor(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "bad", [0 0 0; 1 0 0; 0 1 0], [1 2 3], [1.2 0 0]), ...
                'cmr:graphics:Mesh3D:invalidColor');
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "bad", [0 0 0; 1 0 0; 0 1 0], [1 2 3], [0 0]), ...
                'MATLAB:validation:IncompatibleSize');
        end

        function createRejectsNonStructParameters(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "bad", [0 0 0; 1 0 0; 0 1 0], [1 2 3], [0 0 0], 5), ...
                'cmr:graphics:Mesh3D:invalidParameters');
        end

        function createRejectsOutOfRangeFaceIndex(testCase)
            vertices = [0 0 0; 1 0 0; 0 1 0];
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "bad", vertices, [1 2 4], [0 0 0]), ...
                'cmr:graphics:Mesh3D:faceIndexOutOfRange');
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "bad", vertices, [0 1 2], [0 0 0]), ...
                'cmr:graphics:Mesh3D:faceIndexOutOfRange');
        end

        function createRejectsTooShortFace(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "bad", [0 0 0; 1 0 0; 0 1 0], [1 2], [0 0 0]), ...
                'cmr:graphics:Mesh3D:invalidFaces');
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "bad", [0 0 0; 1 0 0; 0 1 0], {[1 2]}, [0 0 0]), ...
                'cmr:graphics:Mesh3D:invalidFace');
        end

        function createRejectsRepeatedFaceVertex(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.create( ...
                "bad", [0 0 0; 1 0 0; 0 1 0], [1 2 2], [0 0 0]), ...
                'cmr:graphics:Mesh3D:repeatedFaceVertex');
        end

        function createConvertsRowFaceInput(testCase)
            mesh = cmr.graphics.Mesh3D.create( ...
                "rowface", [0 0 0; 1 0 0; 0 1 0], [1 2 3], [0 0 0]);

            testCase.verifyEqual(mesh.faceCount, 1);
            testCase.verifyEqual(mesh.faces{1}, [1 2 3]);
        end

        function triangulateQuadReturnsTwoTriangles(testCase)
            mesh = tMesh3D.squareMesh();
            [triangles, sourceFace] = cmr.graphics.Mesh3D.triangulate(mesh);

            testCase.verifyEqual(triangles, [1 2 3; 1 3 4]);
            testCase.verifyEqual(sourceFace, [1; 1]);
        end

        function triangulateMixedFacesUsesFanOrder(testCase)
            vertices = [0 0 0; 1 0 0; 1 1 0; 0 1 0; 2 0.5 0];
            faces = {[1 2 3], [1 2 5 4 3]};
            mesh = cmr.graphics.Mesh3D.create( ...
                "mixed", vertices, faces, [0 0 0]);

            [triangles, sourceFace] = cmr.graphics.Mesh3D.triangulate(mesh);

            testCase.verifyEqual(triangles, [ ...
                1 2 3; ...
                1 2 5; ...
                1 5 4; ...
                1 4 3]);
            testCase.verifyEqual(sourceFace, [1; 2; 2; 2]);
        end

        function triangulateRejectsMalformedMesh(testCase)
            bad = struct('name', "bad", 'vertices', zeros(4, 3), ...
                'faces', {{}}, 'color', [0 0 0]);

            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.triangulate(bad), ...
                'cmr:graphics:Mesh3D:invalidMesh');
        end

        function boundsReturnsAxisAlignedBox(testCase)
            mesh = tMesh3D.squareMesh();
            [minimum, maximum] = cmr.graphics.Mesh3D.bounds(mesh);

            testCase.verifyEqual(minimum, [0 0 0]);
            testCase.verifyEqual(maximum, [2 2 0]);
        end

        function faceNormalsOfSquarePointAlongPositiveZ(testCase)
            mesh = tMesh3D.squareMesh();
            normals = cmr.graphics.Mesh3D.faceNormals(mesh);

            testCase.verifySize(normals, [1 3]);
            testCase.verifyEqual(normals, [0 0 1], 'AbsTol', 1e-12);
        end

        function faceNormalsRejectDegenerateFace(testCase)
            mesh = cmr.graphics.Mesh3D.create( ...
                "collinear", [0 0 0; 1 0 0; 2 0 0; 3 0 0], ...
                [1 2 3 4], [0 0 0]);

            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.faceNormals(mesh), ...
                'cmr:graphics:Mesh3D:degenerateFace');
        end

        function exportOBJWritesVerticesAndTriangles(testCase)
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>

            mesh = tMesh3D.cubeMesh();
            filePath = cmr.graphics.Mesh3D.exportOBJ( ...
                mesh, fullfile(folder, 'cube.obj'));

            testCase.verifyTrue(isfile(filePath));
            text = string(fileread(filePath));
            lines = splitlines(text);

            testCase.verifyEqual(sum(startsWith(lines, "v ")), 8);
            testCase.verifyEqual(sum(startsWith(lines, "f ")), 12);
            testCase.verifyTrue(contains(text, "o cube"));
            testCase.verifyTrue(contains(text, ...
                "# 8 vertices, 6 polygon faces, 12 triangles"));
        end

        function exportOBJAddsMissingExtension(testCase)
            folder = string(tempname);
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>

            mesh = tMesh3D.squareMesh();
            filePath = cmr.graphics.Mesh3D.exportOBJ( ...
                mesh, fullfile(folder, 'square'));

            testCase.verifyTrue(endsWith(filePath, ".obj"));
            testCase.verifyTrue(isfile(filePath));
        end

        function exportOBJCreatesMissingFolder(testCase)
            root = string(tempname);
            cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

            filePath = cmr.graphics.Mesh3D.exportOBJ( ...
                tMesh3D.squareMesh(), fullfile(root, 'nested', 'mesh.obj'));

            testCase.verifyTrue(isfile(filePath));
            testCase.verifyEqual(string(fileparts(filePath)), ...
                fullfile(root, 'nested'));
        end

        function exportOBJRejectsInvalidDestination(testCase)
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.exportOBJ(tMesh3D.squareMesh(), 123), ...
                'cmr:graphics:Mesh3D:invalidFilePath');
            testCase.verifyError( ...
                @() cmr.graphics.Mesh3D.exportOBJ(tMesh3D.squareMesh(), ""), ...
                'cmr:graphics:Mesh3D:invalidFilePath');
        end
    end

    methods (Static, Access = private)
        function mesh = squareMesh()
            mesh = cmr.graphics.Mesh3D.create( ...
                "square", ...
                [0 0 0; 2 0 0; 2 2 0; 0 2 0], ...
                [1 2 3 4], ...
                [0.2 0.4 0.6]);
        end

        function mesh = cubeMesh()
            mesh = cmr.graphics.Mesh3D.create( ...
                "cube", ...
                [0 0 0; 1 0 0; 1 1 0; 0 1 0; ...
                 0 0 1; 1 0 1; 1 1 1; 0 1 1], ...
                {[1 4 3 2], [5 6 7 8], [1 2 6 5], ...
                 [2 3 7 6], [3 4 8 7], [4 1 5 8]}, ...
                [0.2 0.4 0.6]);
        end
    end
end
