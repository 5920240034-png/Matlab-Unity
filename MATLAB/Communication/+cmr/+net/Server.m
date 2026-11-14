classdef Server < handle
%SERVER TCP server implementing the MATLAB side of the protocol.
%
%   The server owns the socket, the newline framing buffer, request
%   de-duplication and dispatch. Activity definitions (validation data) and
%   game progress are delegated to collaborator objects so the network layer
%   stays independent from activity and scoring logic.

    properties (SetAccess = private)
        Host (1,1) string
        Port (1,1) double
        Timeout (1,1) double
        MaxMessageBytes (1,1) double
        Registry
        Session
        Verbose (1,1) logical
    end

    properties (SetAccess = private)
        Running (1,1) logical = false
        ClientConnected (1,1) logical = false
    end

    properties (Access = private)
        Tcp = []
        RxBuffer uint8 = uint8([])
        SeenRequests containers.Map
        SeenOrder = strings(1, 0)
    end

    methods
        function obj = Server(registry, session, options)
            arguments
                registry = []
                session = []
                options.Host (1,1) string = cmr.net.Protocol.DefaultHost
                options.Port (1,1) double {mustBeInteger, mustBePositive} = cmr.net.Protocol.DefaultPort
                options.Timeout (1,1) double = cmr.net.Protocol.DefaultTimeout
                options.MaxMessageBytes (1,1) double = cmr.net.Protocol.MaxMessageBytes
                options.Verbose (1,1) logical = true
            end

            if options.Port > 65535
                error('cmr:net:Server:invalidPort', 'Port must be between 1 and 65535.');
            end

            obj.Host = options.Host;
            obj.Port = options.Port;
            obj.Timeout = options.Timeout;
            obj.MaxMessageBytes = options.MaxMessageBytes;
            obj.Verbose = options.Verbose;

            if isempty(registry)
                registry = cmr.activities.Registry("");
            end
            if isempty(session)
                session = cmr.game.Session(cmr.net.Protocol.ExpectedActivityCount);
            end
            obj.Registry = registry;
            obj.Session = session;

            obj.SeenRequests = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        end

        function start(obj)
            %START Create the listening socket and install callbacks.
            if obj.Running
                return
            end

            obj.Tcp = tcpserver(obj.Host, obj.Port, ...
                'Timeout', obj.Timeout, ...
                'ConnectionChangedFcn', @(src, ~) obj.onConnectionChanged(src));
            configureTerminator(obj.Tcp, "LF");
            % Byte mode lets us frame newline-delimited messages ourselves so
            % partial packets and several messages per packet are both safe.
            configureCallback(obj.Tcp, "byte", 1, @(src, ~) obj.onBytesAvailable(src));

            obj.Running = true;
            obj.logEvent("Listening on " + obj.Host + ":" + string(obj.Port));
        end

        function run(obj, durationSeconds)
            %RUN Block and service callbacks until stopped or time elapses.
            if nargin < 2
                durationSeconds = Inf;
            end
            startedAt = tic;
            while obj.Running && toc(startedAt) < durationSeconds
                pause(0.05);
            end
        end

        function stop(obj)
            %STOP Stop listening and release the socket resources.
            if ~obj.Running && isempty(obj.Tcp)
                return
            end

            if ~isempty(obj.Tcp) && isvalid(obj.Tcp)
                try
                    configureCallback(obj.Tcp, "off");
                catch
                    % Socket may already be closed by the peer.
                end
                try
                    delete(obj.Tcp);
                catch
                    % Nothing else to release.
                end
            end

            obj.Tcp = [];
            obj.RxBuffer = uint8([]);
            obj.Running = false;
            obj.ClientConnected = false;
            obj.logEvent("Server stopped");
        end

        function delete(obj)
            obj.stop();
        end
    end

    methods (Access = private)
        function onConnectionChanged(obj, src)
            if src.Connected
                obj.RxBuffer = uint8([]);
                obj.ClientConnected = true;
                obj.logEvent("Client connected from " + ...
                    string(src.ClientAddress) + ":" + string(src.ClientPort));
            else
                obj.RxBuffer = uint8([]);
                obj.ClientConnected = false;
                obj.logEvent("Client disconnected");
            end
        end

        function onBytesAvailable(obj, src)
            try
                count = src.NumBytesAvailable;
                if count <= 0
                    return
                end
                data = read(src, count, "uint8");
                obj.RxBuffer = [obj.RxBuffer, reshape(data, 1, [])];
                obj.drainBuffer();
            catch err
                obj.logEvent("Read error: " + string(err.message));
            end
        end

        function drainBuffer(obj)
            while true
                delimiter = find(obj.RxBuffer == uint8(10), 1, 'first');
                if isempty(delimiter)
                    break
                end
                lineBytes = obj.RxBuffer(1:delimiter - 1);
                obj.RxBuffer(1:delimiter) = [];
                obj.handleLineBytes(lineBytes);
            end

            if numel(obj.RxBuffer) > obj.MaxMessageBytes
                obj.RxBuffer = uint8([]);
                obj.sendError("", cmr.net.Protocol.ErrorMessageTooLarge, ...
                    "Message exceeded the maximum size of " + ...
                    string(obj.MaxMessageBytes) + " bytes.");
            end
        end

        function handleLineBytes(obj, lineBytes)
            lineBytes = lineBytes(lineBytes ~= uint8(13)); % tolerate CRLF clients
            if isempty(lineBytes)
                return
            end
            if numel(lineBytes) > obj.MaxMessageBytes
                obj.sendError("", cmr.net.Protocol.ErrorMessageTooLarge, ...
                    "Message exceeded the maximum size of " + ...
                    string(obj.MaxMessageBytes) + " bytes.");
                return
            end
            line = native2unicode(lineBytes, "UTF-8");
            obj.handleLine(line);
        end

        function handleLine(obj, rawLine)
            [message, code, detail] = cmr.net.Codec.decode(rawLine);
            if code ~= ""
                obj.sendError("", code, detail);
                return
            end

            [hasId, detail] = cmr.net.Codec.requireText(message, "requestId");
            if ~hasId
                obj.sendError("", cmr.net.Protocol.ErrorInvalidRequest, detail);
                return
            end

            requestId = string(message.requestId);
            if obj.isDuplicate(requestId)
                obj.logEvent("Ignoring duplicate requestId " + requestId);
                return
            end
            obj.rememberRequest(requestId);

            messageType = string(message.type);
            try
                switch messageType
                    case cmr.net.Protocol.TypePing
                        obj.handlePing(requestId);
                    case cmr.net.Protocol.TypePlaceRequest
                        obj.handlePlace(message, requestId);
                    otherwise
                        obj.sendError(requestId, cmr.net.Protocol.ErrorUnsupportedType, ...
                            "Unsupported message type: " + messageType);
                end
            catch err
                obj.logEvent("Unhandled error for " + messageType + ": " + string(err.message));
                obj.sendError(requestId, cmr.net.Protocol.ErrorInternal, ...
                    "The server failed to process the request.");
            end
        end

        function handlePing(obj, requestId)
            obj.send(struct( ...
                'type', cmr.net.Protocol.TypePong, ...
                'requestId', requestId, ...
                'status', cmr.net.Protocol.connectedStatus()));
        end

        function handlePlace(obj, message, requestId)
            [hasActivity, detail] = cmr.net.Codec.requireText(message, "activity");
            if ~hasActivity
                obj.sendError(requestId, cmr.net.Protocol.ErrorInvalidRequest, detail);
                return
            end
            [hasObject, detail] = cmr.net.Codec.requireText(message, "objectId");
            if ~hasObject
                obj.sendError(requestId, cmr.net.Protocol.ErrorInvalidRequest, detail);
                return
            end
            [hasTarget, detail] = cmr.net.Codec.requireText(message, "targetId");
            if ~hasTarget
                obj.sendError(requestId, cmr.net.Protocol.ErrorInvalidRequest, detail);
                return
            end
            [hasPosition, position, detail] = cmr.net.Codec.readPosition(message);
            if ~hasPosition
                obj.sendError(requestId, cmr.net.Protocol.ErrorInvalidRequest, detail);
                return
            end

            activity = string(message.activity);
            objectId = string(message.objectId);
            targetId = string(message.targetId);

            definition = obj.Registry.get(activity);
            if isempty(definition)
                obj.sendError(requestId, cmr.net.Protocol.ErrorUnknownActivity, ...
                    "Unknown activity '" + activity + "'.");
                return
            end

            result = cmr.activities.Validator.validate(definition, objectId, targetId);
            if ~result.valid
                obj.sendError(requestId, result.code, result.message);
                return
            end

            outcome = obj.Session.applyPlacement(definition, objectId, result.correct);

            obj.send(struct( ...
                'type', cmr.net.Protocol.TypePlaceResponse, ...
                'requestId', requestId, ...
                'activity', activity, ...
                'valid', true, ...
                'correct', result.correct, ...
                'position', position, ...
                'score', outcome.score, ...
                'message', result.message));

            obj.send(struct( ...
                'type', cmr.net.Protocol.TypeActivityResult, ...
                'requestId', requestId, ...
                'activity', activity, ...
                'correct', result.correct, ...
                'completed', outcome.completed, ...
                'stars', outcome.stars, ...
                'message', result.message));

            if outcome.completed
                progress = obj.Session.progress();
                message = struct( ...
                    'type', cmr.net.Protocol.TypeGameProgress, ...
                    'stars', progress.stars, ...
                    'gameCompleted', progress.gameCompleted);
                % A MATLAB scalar string encodes as a JSON string. Assigning
                % a cell array keeps "completedActivities" a JSON array for
                % zero, one and several completed activities.
                message.completedActivities = cellstr(progress.completedActivities);
                obj.send(message);
            end
        end

        function send(obj, message)
            if isempty(obj.Tcp) || ~isvalid(obj.Tcp)
                obj.logEvent("Send skipped: no active connection");
                return
            end
            try
                writeline(obj.Tcp, string(cmr.net.Codec.encode(message)));
            catch err
                obj.logEvent("Send error: " + string(err.message));
            end
        end

        function sendError(obj, requestId, code, detail)
            obj.send(struct( ...
                'type', cmr.net.Protocol.TypeError, ...
                'requestId', string(requestId), ...
                'code', string(code), ...
                'message', string(detail)));
        end

        function tf = isDuplicate(obj, requestId)
            tf = isKey(obj.SeenRequests, char(requestId));
        end

        function rememberRequest(obj, requestId)
            key = char(requestId);
            obj.SeenRequests(key) = true;
            obj.SeenOrder(end + 1) = requestId;

            while numel(obj.SeenOrder) > cmr.net.Protocol.MaxRememberedRequests
                oldest = char(obj.SeenOrder(1));
                obj.SeenOrder(1) = [];
                if isKey(obj.SeenRequests, oldest)
                    remove(obj.SeenRequests, oldest);
                end
            end
        end

        function logEvent(obj, text)
            if ~obj.Verbose
                return
            end
            stamp = char(datetime('now', 'Format', 'HH:mm:ss.SSS'));
            fprintf('[%s] %s\n', stamp, text);
        end
    end
end
