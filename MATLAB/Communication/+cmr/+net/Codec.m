classdef Codec
%CODEC JSON encoding and decoding for protocol messages.
%
%   The codec never throws for malformed input. Decode failures are returned
%   as an error code plus a human readable detail so the server can answer
%   with a structured ERROR message instead of crashing.

    methods (Static)
        function json = encode(message)
            %ENCODE Serialize a scalar struct to a single-line JSON string.
            if ~isstruct(message) || ~isscalar(message)
                error('cmr:net:Codec:invalidMessage', ...
                    'Protocol messages must be scalar structs.');
            end
            json = jsonencode(message);
        end

        function line = encodeLine(message)
            %ENCODeline Serialize and append the newline frame delimiter.
            line = [cmr.net.Codec.encode(message), newline];
        end

        function [message, code, detail] = decode(rawLine)
            %DECODE Parse one JSON object from a single line of text.
            message = struct([]);
            code = "";
            detail = "";

            text = strtrim(string(rawLine));
            if strlength(text) == 0
                code = cmr.net.Protocol.ErrorInvalidJson;
                detail = "Empty message.";
                return
            end

            try
                decoded = jsondecode(char(text));
            catch err
                code = cmr.net.Protocol.ErrorInvalidJson;
                detail = "Malformed JSON: " + string(err.message);
                return
            end

            if ~isstruct(decoded) || ~isscalar(decoded)
                code = cmr.net.Protocol.ErrorInvalidRequest;
                detail = "Top-level JSON value must be an object.";
                return
            end

            if ~cmr.net.Codec.hasText(decoded, "type")
                code = cmr.net.Protocol.ErrorInvalidRequest;
                detail = "Missing or invalid required field 'type'.";
                return
            end

            message = decoded;
        end

        function tf = hasText(message, field)
            %HASTEXT True when the field exists and holds a non-empty string.
            tf = isfield(message, field);
            if ~tf
                return
            end
            value = message.(field);
            tf = (ischar(value) || isstring(value)) && strlength(string(value)) > 0;
        end

        function value = text(message, field, default)
            %TEXT Read a text field as a string scalar.
            if nargin < 3
                default = "";
            end
            if cmr.net.Codec.hasText(message, field)
                value = string(message.(field));
            else
                value = default;
            end
        end

        function [ok, detail] = requireText(message, field)
            %REQUIRETEXT Validate that a required text field is present.
            ok = cmr.net.Codec.hasText(message, field);
            if ok
                detail = "";
            else
                detail = "Missing or invalid required field '" + field + "'.";
            end
        end

        function [ok, position, detail] = readPosition(message)
            %READPOSITION Validate the normalized activity-space position.
            %
            %   Coordinate convention: x and y are normalized values in
            %   [0, 1] measured inside the activity canvas sent by Unity.
            %   Origin is the top-left corner, x grows right, y grows down,
            %   independent of screen resolution and aspect ratio.
            ok = false;
            position = struct('x', 0, 'y', 0);
            detail = "";

            if ~isfield(message, 'position') || ~isstruct(message.position)
                detail = "Missing or invalid required field 'position'.";
                return
            end

            raw = message.position;
            if ~isfield(raw, 'x') || ~isfield(raw, 'y')
                detail = "Field 'position' must contain numeric 'x' and 'y'.";
                return
            end

            x = double(raw.x);
            y = double(raw.y);
            if ~isscalar(x) || ~isscalar(y) || ~isfinite(x) || ~isfinite(y)
                detail = "Fields 'position.x' and 'position.y' must be finite numbers.";
                return
            end

            position = struct('x', x, 'y', y);
            ok = true;
        end
    end
end
