classdef Sphere3D
%SPHERE3D Parametric sphere surface and watertight polygon mesh.
%
%   Parametrisation (angles in radians):
%
%       x = cx + r * sin(phi) * cos(theta)
%       y = cy + r * sin(phi) * sin(theta)
%       z = cz + r * cos(phi)
%
%   with
%
%       theta in [0, 2*pi]   (longitude, around the z axis)
%       phi   in [0, pi]     (polar angle: 0 = north pole, pi = south pole)
%
%   The grid returned by COORDINATES contains a repeated seam column
%   (theta = 0 and theta = 2*pi) and repeated pole rows, which is exactly
%   what SURF needs for a smooth closed appearance. CREATE removes those
%   duplicates and stores one north pole, one south pole and the interior
%   latitude rings, which gives a clean exportable mesh.
%
%   Example:
%       [X, Y, Z] = cmr.graphics.Sphere3D.coordinates(1, [0 0 0], 30, 40);
%       surf(X, Y, Z); shading interp; axis equal;
%
%       mesh = cmr.graphics.Sphere3D.create(1, [0 0 0], 30, 40);

    methods (Static)
        function [theta, phi] = parameterValues(latitudeBands, longitudeBands)
            %PARAMETERVALUES Endpoint-inclusive theta and phi vectors.
            %
            %   [theta, phi] = Sphere3D.parameterValues(latitudeBands, ...
            %       longitudeBands)
            %
            %   theta has longitudeBands+1 samples from 0 to 2*pi and phi
            %   has latitudeBands+1 samples from 0 to pi. The endpoints are
            %   included so the full surface is covered.
            arguments
                latitudeBands (1,1) double = 36
                longitudeBands (1,1) double = 48
            end

            latitudeBands = cmr.graphics.Sphere3D.checkBandCount( ...
                latitudeBands, 'latitudeBands', 2, ...
                'cmr:graphics:Sphere3D:invalidLatitudeBands');
            longitudeBands = cmr.graphics.Sphere3D.checkBandCount( ...
                longitudeBands, 'longitudeBands', 3, ...
                'cmr:graphics:Sphere3D:invalidLongitudeBands');

            theta = linspace(0, 2 * pi, longitudeBands + 1);
            phi = linspace(0, pi, latitudeBands + 1);
        end

        function [X, Y, Z] = coordinates(radius, center, latitudeBands, longitudeBands)
            %COORDINATES Parametric sphere grid suitable for SURF.
            %
            %   [X, Y, Z] = Sphere3D.coordinates(radius, center, ...
            %       latitudeBands, longitudeBands) returns
            %   (latitudeBands+1)-by-(longitudeBands+1) matrices.
            arguments
                radius (1,1) double = 1
                center = [0, 0, 0]
                latitudeBands (1,1) double = 36
                longitudeBands (1,1) double = 48
            end

            radius = cmr.graphics.Sphere3D.checkRadius(radius);
            center = cmr.graphics.Sphere3D.checkCenter(center);

            [theta, phi] = cmr.graphics.Sphere3D.parameterValues( ...
                latitudeBands, longitudeBands);
            [Theta, Phi] = meshgrid(theta, phi);

            X = center(1) + radius .* sin(Phi) .* cos(Theta);
            Y = center(2) + radius .* sin(Phi) .* sin(Theta);
            Z = center(3) + radius .* cos(Phi);
        end

        function mesh = create(radius, center, latitudeBands, longitudeBands, color)
            %CREATE Build a watertight sphere polygon mesh.
            %
            %   mesh = Sphere3D.create(radius, center, latitudeBands, ...
            %       longitudeBands, color)
            %
            %   The mesh has one north pole vertex, one south pole vertex and
            %   (latitudeBands-1) rings of longitudeBands vertices. Faces are
            %   triangles at the poles and quads between the rings.
            arguments
                radius (1,1) double = 1
                center = [0, 0, 0]
                latitudeBands (1,1) double = 36
                longitudeBands (1,1) double = 48
                color (1,3) double = [0.15, 0.70, 0.45]
            end

            radius = cmr.graphics.Sphere3D.checkRadius(radius);
            center = cmr.graphics.Sphere3D.checkCenter(center);
            [theta, phi] = cmr.graphics.Sphere3D.parameterValues( ...
                latitudeBands, longitudeBands);

            ringCount = latitudeBands - 1;
            vertexCount = 2 + ringCount * longitudeBands;
            vertices = zeros(vertexCount, 3);

            % Vertex 1 is the north pole; the final vertex is the south pole.
            vertices(1, :) = center + [0, 0, radius];
            southIndex = vertexCount;

            for ring = 1:ringCount
                ringPhi = phi(ring + 1);   % skip phi = 0 (north pole)
                for longitude = 1:longitudeBands
                    ringTheta = theta(longitude); % skip duplicated seam
                    index = 1 + (ring - 1) * longitudeBands + longitude;

                    % Parametric sphere equations evaluated on the ring.
                    vertices(index, :) = center + radius * [ ...
                        sin(ringPhi) * cos(ringTheta), ...
                        sin(ringPhi) * sin(ringTheta), ...
                        cos(ringPhi)];
                end
            end

            vertices(southIndex, :) = center + [0, 0, -radius];

            faceCount = latitudeBands * longitudeBands;
            faces = cell(1, faceCount);
            faceCursor = 0;

            % North cap: the pole, then two adjacent vertices of ring 1.
            for longitude = 1:longitudeBands
                nextLongitude = mod(longitude, longitudeBands) + 1;
                faceCursor = faceCursor + 1;
                faces{faceCursor} = [ ...
                    1, ...
                    1 + longitude, ...
                    1 + nextLongitude];
            end

            % Middle bands: quad between ring r and ring r+1.
            for ring = 1:(latitudeBands - 2)
                upperStart = 1 + (ring - 1) * longitudeBands + 1;
                lowerStart = 1 + ring * longitudeBands + 1;

                for longitude = 1:longitudeBands
                    nextLongitude = mod(longitude, longitudeBands) + 1;
                    faceCursor = faceCursor + 1;
                    faces{faceCursor} = [ ...
                        upperStart + longitude - 1, ...
                        lowerStart + longitude - 1, ...
                        lowerStart + nextLongitude - 1, ...
                        upperStart + nextLongitude - 1];
                end
            end

            % South cap: the pole, then the next and current vertex of the
            % final ring. Reversing the order keeps the normal outward.
            lastRingStart = 1 + (latitudeBands - 2) * longitudeBands + 1;
            for longitude = 1:longitudeBands
                nextLongitude = mod(longitude, longitudeBands) + 1;
                faceCursor = faceCursor + 1;
                faces{faceCursor} = [ ...
                    southIndex, ...
                    lastRingStart + nextLongitude - 1, ...
                    lastRingStart + longitude - 1];
            end

            parameters = struct( ...
                'radius', radius, ...
                'center', center, ...
                'latitudeBands', latitudeBands, ...
                'longitudeBands', longitudeBands, ...
                'volume', 4 * pi * radius^3 / 3, ...
                'surfaceArea', 4 * pi * radius^2);

            mesh = cmr.graphics.Mesh3D.create( ...
                "sphere", vertices, faces, color, parameters);
        end
    end

    methods (Static, Access = private)
        function radius = checkRadius(radius)
            if ~isreal(radius) || ~isfinite(radius) || radius <= 0
                error('cmr:graphics:Sphere3D:invalidRadius', ...
                    'Sphere radius must be a finite positive number.');
            end
        end

        function center = checkCenter(center)
            if ~(isnumeric(center) && isreal(center) ...
                    && numel(center) == 3 && all(isfinite(center(:))))
                error('cmr:graphics:Sphere3D:invalidCenter', ...
                    'Sphere centre must be a finite [x y z] point.');
            end
            center = double(center(:))';
        end

        function value = checkBandCount(value, name, minimum, identifier)
            if ~(isscalar(value) && isreal(value) && isfinite(value) ...
                    && value == round(value) && value >= minimum)
                error(identifier, ...
                    '%s must be an integer greater than or equal to %d.', ...
                    name, minimum);
            end
            value = double(value);
        end
    end
end
