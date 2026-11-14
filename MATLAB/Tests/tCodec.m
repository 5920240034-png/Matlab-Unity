classdef tCodec < matlab.unittest.TestCase
%TCODEC Unit tests for JSON encoding/decoding and field validation.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (Test)
        function encodesCompactJson(testCase)
            json = cmr.net.Codec.encode(struct('type', "PING", 'requestId', "req_1"));
            testCase.verifyClass(json, 'char');
            testCase.verifySubstring(json, '"type":"PING"');
            testCase.verifySubstring(json, '"requestId":"req_1"');
        end

        function encodeLineEndsWithNewline(testCase)
            line = cmr.net.Codec.encodeLine(struct('type', "PING"));
            testCase.verifyTrue(endsWith(string(line), newline));
        end

        function encodesNestedStruct(testCase)
            message = struct('type', "PLACE_REQ", ...
                'position', struct('x', 0.45, 'y', 0.62));
            json = cmr.net.Codec.encode(message);
            testCase.verifySubstring(json, '"position":{"x":0.45,"y":0.62}');
        end

        function decodesValidMessage(testCase)
            [message, code] = cmr.net.Codec.decode('{"type":"PING","requestId":"req_9"}');
            testCase.verifyEqual(code, "");
            testCase.verifyEqual(string(message.type), "PING");
            testCase.verifyEqual(string(message.requestId), "req_9");
        end

        function rejectsMalformedJson(testCase)
            [message, code] = cmr.net.Codec.decode('{ "type": "PING", ');
            testCase.verifyEqual(code, cmr.net.Protocol.ErrorInvalidJson);
            testCase.verifyTrue(isempty(message));
        end

        function rejectsEmptyMessage(testCase)
            [~, code] = cmr.net.Codec.decode('   ');
            testCase.verifyEqual(code, cmr.net.Protocol.ErrorInvalidJson);
        end

        function rejectsNonObjectJson(testCase)
            [~, code] = cmr.net.Codec.decode('[1,2,3]');
            testCase.verifyEqual(code, cmr.net.Protocol.ErrorInvalidRequest);
        end

        function rejectsMissingType(testCase)
            [~, code] = cmr.net.Codec.decode('{"requestId":"req_1"}');
            testCase.verifyEqual(code, cmr.net.Protocol.ErrorInvalidRequest);
        end

        function rejectsNonTextType(testCase)
            [~, code] = cmr.net.Codec.decode('{"type":42}');
            testCase.verifyEqual(code, cmr.net.Protocol.ErrorInvalidRequest);
        end

        function requireTextRejectsMissingField(testCase)
            [ok, detail] = cmr.net.Codec.requireText(struct(), "requestId");
            testCase.verifyFalse(ok);
            testCase.verifySubstring(detail, "requestId");
        end

        function requireTextAcceptsValue(testCase)
            [ok, detail] = cmr.net.Codec.requireText(struct('requestId', "abc"), "requestId");
            testCase.verifyTrue(ok);
            testCase.verifyEqual(detail, "");
        end

        function readsValidPosition(testCase)
            message = struct('position', struct('x', 0.5, 'y', 0.25));
            [ok, position] = cmr.net.Codec.readPosition(message);
            testCase.verifyTrue(ok);
            testCase.verifyEqual(position.x, 0.5);
            testCase.verifyEqual(position.y, 0.25);
        end

        function rejectsMissingPosition(testCase)
            [ok, ~, detail] = cmr.net.Codec.readPosition(struct());
            testCase.verifyFalse(ok);
            testCase.verifySubstring(detail, "position");
        end

        function rejectsNonFinitePosition(testCase)
            message = struct('position', struct('x', Inf, 'y', 0));
            [ok, ~, detail] = cmr.net.Codec.readPosition(message);
            testCase.verifyFalse(ok);
            testCase.verifySubstring(detail, "finite");
        end

        function toleratesUnknownFields(testCase)
            [message, code] = cmr.net.Codec.decode( ...
                '{"type":"PING","requestId":"r1","extra":true}');
            testCase.verifyEqual(code, "");
            testCase.verifyEqual(string(message.type), "PING");
        end

        function encodesSingleElementStringArrayAsJsonArray(testCase)
            % Regression: jsonencode turns a scalar string into a JSON
            % string. A one-element completedActivities list must still be an
            % array so Unity's string[] decoder accepts it.
            message = struct('type', "GAME_PROGRESS");
            message.completedActivities = cellstr("COLOR");
            json = cmr.net.Codec.encode(message);
            testCase.verifySubstring(json, '"completedActivities":["COLOR"]');
        end

        function encodesEmptyStringArrayAsJsonArray(testCase)
            message = struct('type', "GAME_PROGRESS");
            message.completedActivities = cellstr(strings(1, 0));
            json = cmr.net.Codec.encode(message);
            testCase.verifySubstring(json, '"completedActivities":[]');
        end

        function encodesMultipleStringArrayAsJsonArray(testCase)
            message = struct('type', "GAME_PROGRESS");
            message.completedActivities = cellstr(["COLOR", "TASTE"]);
            json = cmr.net.Codec.encode(message);
            testCase.verifySubstring(json, ...
                '"completedActivities":["COLOR","TASTE"]');
        end
    end
end
