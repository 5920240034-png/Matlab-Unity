classdef Cylinder3D
%CYLINDER3D Circular cylinder built from two rings, side quads and caps.
%
%   The cylinder axis is the z axis. Its centre is the midpoint of the
%   axis, so the bottom cap is at cz - height/2 and the top cap is at
%   cz + height/2.
%
%   With N radial segments and theta_j = 2*pi*(j-1)/N:
%
%       bottom_j = (cx + r cos(theta_j), cy + r sin(theta_j), cz - h/2)
%       top_j    = (cx + r cos(theta_j), cy + r sin(theta_j), cz + h/2)
%
%   The mesh stores N bottom vertices (indices 1..N), N top vertices
%   (indices N+1..2N), N side quads and two n-gon cap faces. The caps use
%   the same ring vertices, so the mesh is closed and exportable.
%
%   Example:
%       [theta, X, Y, Z] = cmr.graphics.Cylinder3D.sideGrid( ...
%           1, 2, [0 0 0], 36);
%       surf(X, Y, Z); shading interp; axis equal;
%
%       mesh = cmr.graphics.Cylinder3D.create(1, 2, [0 0 0], 36);

    methods (Static)
        function theta = parameterValues(radialSegments)
            %PARAMETERVALUES Distinct angles around the circular cross-section.
            %
            %   theta = Cylinder3D.parameterValues(radialSegments) returns a
            %   1-by-radialSegments row from 0 to 2*pi, excluding the
            %   duplicated seam at 2*pi.
            arguments
                radialSegments (1,1) double = 36
            end

            radialSegments = cmr.graphics.Cylinder3D.checkSegments( ...
                radialSegments);
            theta = linspace(0, 2 * pi, radialSegments + 1);
            theta(end) = [];
        end

        function [theta, X, Y, Z] = sideGrid(radius, height, center, radialSegments)
            %SIDEGRID Parametric side surface suitable for SURF.
            %
            %   [theta, X, Y, Z] = Cylinder3D.sideGrid(radius, height, ...
            %       center, radialSegments) returns a 2-by-(N+1) grid. The
            %       two rows are the bottom and top rings; the final column
            %       repeats the first one so SURF closes the seam.
            arguments
                radius (1,1) double = 1
                height (1,1) double = 2
                center = [0, 0, 0]
                radialSegments (1,1) double = 36
            end

            [radius, height, center, radialSegments] = ...
                cmr.graphics.Cylinder3D.checkGeometry( ...
                radius, height, center, radialSegments);

            theta = linspace(0, 2 * pi, radialSegments + 1);
            ringX = center(1) + radius .* cos(theta);
            ringY = center(2) + radius .* sin(theta);
            bottomZ = center(3) - height / 2;
            topZ = center(3) + height / 2;

            X = repmat(ringX, 2, 1);
            Y = repmat(ringY, 2, 1);
            Z = [repmat(bottomZ, 1, radialSegments + 1); ...
                 repmat(topZ, 1, radialSegments + 1)];
        end

        function [X, Y] = capCoordinates(radius, center, radialSegments)
            %CAPCOORDINATES Closed circle coordinates for FILL3 cap drawing.
            %
            %   [X, Y] = Cylinder3D.capCoordinates(radius, center, ...
            %       radialSegments) returns 1-by-(N+1) rows. Multiply a
            %       constant z value by ones(size(X)) to place a cap.
            arguments
                radius (1,1) double = 1
                center = [0, 0, 0]
                radialSegments (1,1) double = 36
            end

            radius = cmr.graphics.Cylinder3D.checkRadius(radius);
            center = cmr.graphics.Cylinder3D.checkCenter(center);
            radialSegments = cmr.graphics.Cylinder3D.checkSegments( ...
                radialSegments);

            theta = linspace(0, 2 * pi, radialSegments + 1);
            X = center(1) + radius .* cos(theta);
            Y = center(2) + radius .* sin(theta);
        end

        function mesh = create(radius, height, center, radialSegments, color)
            %CREATE Build a closed cylinder mesh.
            %
            %   mesh = Cylinder3D.create(radius, height, center, ...
            %       radialSegments, color)
            arguments
                radius (1,1) double = 1
                height (1,1) double = 2
                center = [0, 0, 0]
                radialSegments (1,1) double = 36
                color (1,3) double = [0.95, 0.55, 0.15]
            end

            [radius, height, center, radialSegments] = ...
                cmr.graphics.Cylinder3D.checkGeometry( ...
                radius, height, center, radialSegments);

            theta = cmr.graphics.Cylinder3D.parameterValues( ...
                radialSegments);
            bottomZ = center(3) - height / 2;
            topZ = center(3) + height / 2;

            verticalOffset = [ ...
                radius .* cos(theta); ...
                radius .* sin(theta)];
            bottomRing = [ ...
                center(1) + verticalOffset(1, :); ...
                center(2) + verticalOffset(2, :); ...
                repmat(bottomZ, 1, radialSegments)]';
            topRing = [ ...
                center(1) + verticalOffset(1, :); ...
                center(2) + verticalOffset(2, :); ...
                repmat(topZ, 1, radialSegments)]';

            vertices = [bottomRing; topRing];

            faces = cell(1, radialSegments + 2);
            for segment = 1:radialSegments
                nextSegment = mod(segment, radialSegments) + 1;
                faces{segment} = [ ...
                    segment, ...
                    nextSegment, ...
                    radialSegments + nextSegment, ...
                    radialSegments + segment];
            end

            % Bottom ring is counter-clockwise seen from +z, so reversing it
            % makes the bottom cap normal point along -z.
            faces{radialSegments + 1} = fliplr(1:radialSegments);
            faces{radialSegments + 2} = radialSegments + (1:radialSegments);

            segmentLength = 2 * radius * sin(pi / radialSegments);
            capArea = 0.5 * radialSegments * radius^2 ...
                * sin(2 * pi / radialSegments);
            lateralArea = radialSegments * segmentLength * height;

            parameters = struct( ...
                'radius', radius, ...
                'height', height, ...
                'center', center, ...
                'radialSegments', radialSegments, ...
                'volume', capArea * height, ...
                'surfaceArea', lateralArea + 2 * capArea, ...
                'idealVolume', pi * radius^2 * height, ...
                'idealSurfaceArea', ...
                    2 * pi * radius * height + 2 * pi * radius^2);

            mesh = cmr.graphics.Mesh3D.create( ...
                "cylinder", vertices, faces, color, parameters);
        end
    end

    methods (Static, Access = private)
        function radius = checkRadius(radius)
            if ~isreal(radius) || ~isfinite(radius) || radius <= 0
                error('cmr:graphics:Cylinder3D:invalidRadius', ...
                    'Cylinder radius must be a finite positive number.');
            end
        end

        function height = checkHeight(height)
            if ~isreal(height) || ~isfinite(height) || height <= 0
                error('cmr:graphics:Cylinder3D:invalidHeight', ...
                    'Cylinder height must be a finite positive number.');
            end
        end

        function center = checkCenter(center)
            if ~(isnumeric(center) && isreal(center) ...
                    && numel(center) == 3 && all(isfinite(center(:))))
                error('cmr:graphics:Cylinder3D:invalidCenter', ...
                    'Cylinder centre must be a finite [x y z] point.');
            end
            center = double(center(:))';
        end

        function segments = checkSegments(segments)
            if ~(isscalar(segments) && isreal(segments) ...
                    && isfinite(segments) && segments == round(segments) ...
                    && segments >= 3)
                error('cmr:graphics:Cylinder3D:invalidRadialSegments', ...
                    'Cylinder radialSegments must be an integer greater than or equal to 3.');
            end
            segments = double(segments);
        end

        function [radius, height, center, segments] = checkGeometry( ...
                radius, height, center, segments)
            radius = cmr.graphics.Cylinder3D.checkRadius(radius);
            height = cmr.graphics.Cylinder3D.checkHeight(height);
            center = cmr.graphics.Cylinder3D.checkCenter(center);
            segments = cmr.graphics.Cylinder3D.checkSegments(segments);
        end
    end
end
