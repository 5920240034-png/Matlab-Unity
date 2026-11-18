classdef Cube3D
%CUBE3D Axis-aligned cube built from eight vertices and six quad faces.
%
%   The cube is centred at CENTER and has the given side length. Its eight
%   vertices are the combinations of the half-length offsets along x, y and
%   z. The six faces are written counter-clockwise as seen from outside, so
%   their normals point away from the centre.
%
%   Vertex order:
%
%       1 (-h,-h,-h)   2 (+h,-h,-h)   3 (+h,+h,-h)   4 (-h,+h,-h)
%       5 (-h,-h,+h)   6 (+h,-h,+h)   7 (+h,+h,+h)   8 (-h,+h,+h)
%
%   Face order:
%
%       bottom  [1 4 3 2]      top     [5 6 7 8]
%       front   [1 2 6 5]      right   [2 3 7 6]
%       back    [3 4 8 7]      left    [4 1 5 8]
%
%   Example:
%       cube = cmr.graphics.Cube3D.create(2, [0 0 0], [0.2 0.55 0.9]);

    methods (Static)
        function [vertices, faces] = verticesAndFaces(sideLength, center)
            %VERTICESANDFACES Return the raw cube vertices and six faces.
            %
            %   [vertices, faces] = Cube3D.verticesAndFaces(sideLength, center)
            %
            %   sideLength is the edge length and center is [x y z].
            arguments
                sideLength (1,1) double = 2
                center = [0, 0, 0]
            end

            sideLength = cmr.graphics.Cube3D.checkSideLength(sideLength);
            center = cmr.graphics.Cube3D.checkCenter(center);
            half = sideLength / 2;

            % Each row is a combination of the three half-length offsets.
            offsets = [ ...
                -half, -half, -half; ...
                 half, -half, -half; ...
                 half,  half, -half; ...
                -half,  half, -half; ...
                -half, -half,  half; ...
                 half, -half,  half; ...
                 half,  half,  half; ...
                -half,  half,  half];

            vertices = center + offsets;

            faces = { ...
                [1, 4, 3, 2], ...   % bottom, normal -z
                [5, 6, 7, 8], ...   % top, normal +z
                [1, 2, 6, 5], ...   % front, normal -y
                [2, 3, 7, 6], ...   % right, normal +x
                [3, 4, 8, 7], ...   % back, normal +y
                [4, 1, 5, 8]};      % left, normal -x
        end

        function mesh = create(sideLength, center, color)
            %CREATE Build a validated cube mesh.
            %
            %   mesh = Cube3D.create(sideLength, center, color)
            arguments
                sideLength (1,1) double = 2
                center = [0, 0, 0]
                color (1,3) double = [0.20, 0.55, 0.90]
            end

            [vertices, faces] = cmr.graphics.Cube3D.verticesAndFaces( ...
                sideLength, center);

            parameters = struct( ...
                'sideLength', sideLength, ...
                'center', center, ...
                'volume', sideLength^3, ...
                'surfaceArea', 6 * sideLength^2);

            mesh = cmr.graphics.Mesh3D.create( ...
                "cube", vertices, faces, color, parameters);
        end
    end

    methods (Static, Access = private)
        function sideLength = checkSideLength(sideLength)
            if ~isreal(sideLength) || ~isfinite(sideLength) || sideLength <= 0
                error('cmr:graphics:Cube3D:invalidSideLength', ...
                    'Cube side length must be a finite positive number.');
            end
        end

        function center = checkCenter(center)
            if ~(isnumeric(center) && isreal(center) ...
                    && numel(center) == 3 && all(isfinite(center(:))))
                error('cmr:graphics:Cube3D:invalidCenter', ...
                    'Cube centre must be a finite [x y z] point.');
            end
            center = double(center(:))';
        end
    end
end
