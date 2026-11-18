classdef Mesh3D
%MESH3D Polygon mesh container, validation and ASCII OBJ export.
%
%   A mesh is a struct with the following fields:
%
%       name          Short object name, for example "cube".
%       vertices      N-by-3 matrix of [x y z] coordinates.
%       faces         1-by-F cell array. Each cell is a row vector of
%                     1-based vertex indices describing one polygon.
%       vertexCount   Number of vertices (N).
%       faceCount     Number of polygon faces (F).
%       color         1-by-3 RGB colour with components in [0, 1].
%       parameters    Struct with the construction parameters and the
%                     analytical volume and surface area when available.
%
%   Faces are ordered counter-clockwise when seen from outside the object.
%   Face normals therefore point outwards. Polygon faces may have different
%   sizes: the cube uses quads, the sphere uses quads plus pole triangles,
%   and the cylinder uses side quads plus two n-gon caps. Call TRIANGULATE
%   before rendering with a triangle-only consumer or before OBJ export.
%
%   Example:
%       cube = cmr.graphics.Cube3D.create(2);
%       triangles = cmr.graphics.Mesh3D.triangulate(cube);
%       cmr.graphics.Mesh3D.exportOBJ(cube, 'cube.obj');

    methods (Static)
        function mesh = create(name, vertices, faces, color, parameters)
            %CREATE Validate raw polygon data and return a mesh struct.
            %
            %   mesh = Mesh3D.create(name, vertices, faces, color, parameters)
            %
            %   faces may be a cell array of index vectors, or a numeric
            %   matrix whose rows are faces. Mixed face sizes require the
            %   cell-array form.
            arguments
                name (1,1) string
                vertices (:,3) double
                faces
                color (1,3) double = [0.65, 0.65, 0.65]
                parameters = struct()
            end

            if strlength(name) == 0
                error('cmr:graphics:Mesh3D:invalidName', ...
                    'Mesh name must not be empty.');
            end
            if size(vertices, 1) < 3
                error('cmr:graphics:Mesh3D:invalidVertices', ...
                    'A mesh needs at least three vertices.');
            end
            if ~isreal(vertices) || any(~isfinite(vertices(:)))
                error('cmr:graphics:Mesh3D:invalidVertices', ...
                    'Mesh vertices must be finite real x-y-z coordinates.');
            end
            if ~isstruct(parameters) || ~isscalar(parameters)
                error('cmr:graphics:Mesh3D:invalidParameters', ...
                    'Mesh parameters must be a scalar struct.');
            end

            cmr.graphics.Mesh3D.checkColor(color);
            faces = cmr.graphics.Mesh3D.normaliseFaces( ...
                faces, size(vertices, 1));

            mesh = struct();
            mesh.name = name;
            mesh.vertices = vertices;
            mesh.faces = faces;
            mesh.vertexCount = size(vertices, 1);
            mesh.faceCount = numel(faces);
            mesh.color = color;
            mesh.parameters = parameters;
        end

        function [triangles, sourceFace] = triangulate(mesh)
            %TRIANGULATE Convert every polygon face into a triangle fan.
            %
            %   [triangles, sourceFace] = Mesh3D.triangulate(mesh) returns
            %   an M-by-3 matrix of triangle vertex indices and an M-by-1
            %   vector that maps each triangle back to its source polygon.
            %   A polygon with k vertices produces k-2 triangles.
            cmr.graphics.Mesh3D.mustBeMesh(mesh);

            triangleCount = 0;
            for index = 1:numel(mesh.faces)
                triangleCount = triangleCount + numel(mesh.faces{index}) - 2;
            end

            triangles = zeros(triangleCount, 3);
            sourceFace = zeros(triangleCount, 1);
            cursor = 0;

            for index = 1:numel(mesh.faces)
                face = mesh.faces{index};
                for corner = 2:(numel(face) - 1)
                    cursor = cursor + 1;
                    triangles(cursor, :) = ...
                        [face(1), face(corner), face(corner + 1)];
                    sourceFace(cursor) = index;
                end
            end
        end

        function normals = faceNormals(mesh)
            %FACENORMALS Unit outward normal of every polygon face.
            %
            %   Newell's method is used so that non-planar quads (for
            %   example the latitude bands of a sphere) still receive a
            %   stable average normal. Degenerate faces are rejected.
            cmr.graphics.Mesh3D.mustBeMesh(mesh);

            normals = zeros(numel(mesh.faces), 3);

            for faceIndex = 1:numel(mesh.faces)
                face = mesh.faces{faceIndex};
                faceVertices = mesh.vertices(face, :);

                normal = [0, 0, 0];
                for corner = 1:numel(face)
                    current = faceVertices(corner, :);
                    next = faceVertices(mod(corner, numel(face)) + 1, :);

                    normal(1) = normal(1) ...
                        + (current(2) - next(2)) * (current(3) + next(3));
                    normal(2) = normal(2) ...
                        + (current(3) - next(3)) * (current(1) + next(1));
                    normal(3) = normal(3) ...
                        + (current(1) - next(1)) * (current(2) + next(2));
                end

                length = norm(normal);
                if length < 1e-12
                    error('cmr:graphics:Mesh3D:degenerateFace', ...
                        'Face %d has no well-defined normal.', faceIndex);
                end

                normals(faceIndex, :) = normal / length;
            end
        end

        function [minimum, maximum] = bounds(mesh)
            %BOUNDS Axis-aligned bounding box of the mesh vertices.
            cmr.graphics.Mesh3D.mustBeMesh(mesh);

            minimum = min(mesh.vertices, [], 1);
            maximum = max(mesh.vertices, [], 1);
        end

        function filePath = exportOBJ(mesh, filePath)
            %EXPORTOBJ Write the mesh as an ASCII Wavefront OBJ file.
            %
            %   filePath = Mesh3D.exportOBJ(mesh, filePath) writes the
            %   triangulated mesh so it can be imported by Unity or another
            %   engine. A missing .obj extension is added automatically and
            %   missing parent folders are created. The writer uses only
            %   base MATLAB, so no toolbox or third-party dependency is
            %   required.
            cmr.graphics.Mesh3D.mustBeMesh(mesh);

            if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
                error('cmr:graphics:Mesh3D:invalidFilePath', ...
                    'OBJ destination must be a character vector or string scalar.');
            end

            filePath = string(filePath);
            if strlength(filePath) == 0
                error('cmr:graphics:Mesh3D:invalidFilePath', ...
                    'OBJ destination must not be empty.');
            end

            [folderPath, baseName, extension] = fileparts(filePath);
            if ~strcmpi(extension, ".obj")
                filePath = fullfile(folderPath, baseName + ".obj");
            end

            if strlength(folderPath) > 0 && ~isfolder(folderPath)
                mkdir(folderPath);
            end

            fileID = fopen(char(filePath), 'w');
            if fileID == -1
                error('cmr:graphics:Mesh3D:exportFailed', ...
                    'Could not open %s for writing.', filePath);
            end
            cleanup = onCleanup(@() fclose(fileID)); %#ok<NASGU>

            triangles = cmr.graphics.Mesh3D.triangulate(mesh);
            objectName = regexprep(char(mesh.name), '\s+', '_');

            fprintf(fileID, '# Clean My Room - Issue #007\n');
            fprintf(fileID, '# Generated by cmr.graphics.Mesh3D\n');
            fprintf(fileID, 'o %s\n', objectName);
            fprintf(fileID, '# %d vertices, %d polygon faces, %d triangles\n', ...
                mesh.vertexCount, mesh.faceCount, size(triangles, 1));

            fprintf(fileID, 'v %.10g %.10g %.10g\n', mesh.vertices.');
            fprintf(fileID, 'f %d %d %d\n', triangles.');
        end
    end

    methods (Static, Access = private)
        function faces = normaliseFaces(faces, vertexCount)
            if iscell(faces)
                rawFaces = faces;
            elseif isnumeric(faces) && ismatrix(faces) && size(faces, 2) >= 3
                rawFaces = num2cell(faces, 2);
            elseif isnumeric(faces) && isvector(faces) && numel(faces) >= 3
                rawFaces = {faces};
            else
                error('cmr:graphics:Mesh3D:invalidFaces', ...
                    'Faces must be a cell array or a numeric matrix of indices.');
            end

            if isempty(rawFaces)
                error('cmr:graphics:Mesh3D:invalidFaces', ...
                    'A mesh needs at least one face.');
            end

            faces = cell(1, numel(rawFaces));

            for faceIndex = 1:numel(rawFaces)
                face = rawFaces{faceIndex};

                valid = isnumeric(face) && isreal(face) && isvector(face) ...
                    && numel(face) >= 3 && all(isfinite(face(:))) ...
                    && all(face(:) == round(face(:)));

                if ~valid
                    error('cmr:graphics:Mesh3D:invalidFace', ...
                        'Face %d must contain at least three finite integer vertex indices.', ...
                        faceIndex);
                end

                face = double(face(:))';

                if any(face < 1) || any(face > vertexCount)
                    error('cmr:graphics:Mesh3D:faceIndexOutOfRange', ...
                        'Face %d references a vertex outside 1..%d.', ...
                        faceIndex, vertexCount);
                end
                if numel(unique(face)) ~= numel(face)
                    error('cmr:graphics:Mesh3D:repeatedFaceVertex', ...
                        'Face %d contains a repeated vertex index.', faceIndex);
                end

                faces{faceIndex} = face;
            end
        end

        function mustBeMesh(mesh)
            required = {'name', 'vertices', 'faces', 'color'};

            if ~isstruct(mesh) || ~isscalar(mesh)
                error('cmr:graphics:Mesh3D:invalidMesh', ...
                    'Expected a scalar mesh struct.');
            end
            for index = 1:numel(required)
                if ~isfield(mesh, required{index})
                    error('cmr:graphics:Mesh3D:invalidMesh', ...
                        'Mesh struct is missing the "%s" field.', required{index});
                end
            end
            if ~iscell(mesh.faces) || isempty(mesh.faces)
                error('cmr:graphics:Mesh3D:invalidMesh', ...
                    'Mesh faces must be a non-empty cell array.');
            end
            if ~(isnumeric(mesh.vertices) && isreal(mesh.vertices) ...
                    && size(mesh.vertices, 2) == 3 ...
                    && all(isfinite(mesh.vertices(:))))
                error('cmr:graphics:Mesh3D:invalidMesh', ...
                    'Mesh vertices must be a finite N-by-3 matrix.');
            end
        end

        function checkColor(color)
            if ~isreal(color) || any(~isfinite(color)) ...
                    || any(color < 0) || any(color > 1)
                error('cmr:graphics:Mesh3D:invalidColor', ...
                    'Mesh colour must contain three RGB components in [0, 1].');
            end
        end
    end
end
