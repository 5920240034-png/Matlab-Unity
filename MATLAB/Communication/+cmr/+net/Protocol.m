classdef Protocol
%PROTOCOL Shared constants for the MATLAB-Unity TCP/JSON protocol.
%
%   MATLAB is the TCP server. Unity is the TCP client. Messages are UTF-8
%   encoded JSON objects, one per line (newline-delimited framing).

    properties (Constant)
        Version = "1.0";
        DefaultHost = "127.0.0.1";
        DefaultPort = 55001;
        DefaultTimeout = 30;
        MaxMessageBytes = 65536;
        ExpectedActivityCount = 3;
        MaxRememberedRequests = 512;
    end

    properties (Constant)
        TypePing = "PING";
        TypePong = "PONG";
        TypePlaceRequest = "PLACE_REQ";
        TypePlaceResponse = "PLACE_RES";
        TypeActivityResult = "ACTIVITY_RESULT";
        TypeGameProgress = "GAME_PROGRESS";
        TypeError = "ERROR";
    end

    properties (Constant)
        ErrorInvalidJson = "INVALID_JSON";
        ErrorInvalidRequest = "INVALID_REQUEST";
        ErrorUnsupportedType = "UNSUPPORTED_TYPE";
        ErrorUnknownActivity = "UNKNOWN_ACTIVITY";
        ErrorUnknownObject = "UNKNOWN_OBJECT";
        ErrorUnknownTarget = "UNKNOWN_TARGET";
        ErrorMessageTooLarge = "MESSAGE_TOO_LARGE";
        ErrorInternal = "INTERNAL_ERROR";
    end

    methods (Static)
        function types = supportedTypes()
            types = [ ...
                cmr.net.Protocol.TypePing, ...
                cmr.net.Protocol.TypePlaceRequest];
        end

        function tf = isSupportedType(messageType)
            tf = any(cmr.net.Protocol.supportedTypes() == string(messageType));
        end

        function status = connectedStatus()
            status = "CONNECTED";
        end
    end
end
