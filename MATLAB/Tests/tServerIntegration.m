classdef tServerIntegration < matlab.unittest.TestCase
%TSERVERINTEGRATION End-to-end protocol tests against real TCP sockets.
%
%   A real cmr.net.Server listens on 127.0.0.1:55101 (port 55001 stays free
%   for the game) and a real tcpclient plays the Unity client role. This
%   exercises framing, decoding, dispatch, responses and reconnection.

    properties (Access = private)
        Server
        Client
        RxBuffer uint8 = uint8([])
        PendingMessages = {}
        PendingRawLines = strings(1, 0)
    end

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (TestMethodSetup)
        function createServerAndClient(testCase)
            testsDirectory = string(fileparts(mfilename('fullpath')));
            registry = cmr.activities.Registry(fullfile(testsDirectory, 'fixtures'));
            session = cmr.game.Session(3);

            testCase.Server = cmr.net.Server(registry, session, ...
                'Port', 55101, 'Verbose', false);
            testCase.Server.start();
            testCase.Client = tcpclient("127.0.0.1", 55101);
            testCase.RxBuffer = uint8([]);
            testCase.PendingMessages = {};
            testCase.PendingRawLines = strings(1, 0);
            testCase.waitForConnection(true, 5);
        end
    end

    methods (TestMethodTeardown)
        function closeServerAndClient(testCase)
            if ~isempty(testCase.Client)
                try
                    delete(testCase.Client);
                catch
                    % Client socket may already be closed.
                end
                testCase.Client = [];
            end
            if ~isempty(testCase.Server)
                testCase.Server.stop();
                testCase.Server = [];
            end
        end
    end

    methods (Test)
        function serverAcceptsConnection(testCase)
            testCase.verifyTrue(testCase.Server.Running);
            testCase.verifyTrue(testCase.Server.ClientConnected);
        end

        function pingReturnsPong(testCase)
            testCase.sendLine('{"type":"PING","requestId":"req_ping"}');
            messages = testCase.readMessages(1);

            testCase.verifyEqual(numel(messages), 1, ...
                'Expected exactly one PONG reply.');
            reply = messages{1};
            testCase.verifyEqual(string(reply.type), "PONG");
            testCase.verifyEqual(string(reply.requestId), "req_ping");
            testCase.verifyEqual(string(reply.status), "CONNECTED");
            testCase.assertNoMessages(0.4);
        end

        function correctPlacementReturnsResult(testCase)
            testCase.placeObject("req_place_1", "object_01", "basket_red", 0.45, 0.62);
            messages = testCase.readMessages(2);

            testCase.verifyEqual(numel(messages), 2, ...
                'Expected PLACE_RES followed by ACTIVITY_RESULT.');
            placement = messages{1};
            testCase.verifyEqual(string(placement.type), "PLACE_RES");
            testCase.verifyEqual(string(placement.requestId), "req_place_1");
            testCase.verifyEqual(string(placement.activity), "COLOR");
            testCase.verifyTrue(placement.valid);
            testCase.verifyTrue(placement.correct);
            testCase.verifyEqual(placement.position.x, 0.45);
            testCase.verifyEqual(placement.position.y, 0.62);
            testCase.verifyEqual(placement.score, 1);

            result = messages{2};
            testCase.verifyEqual(string(result.type), "ACTIVITY_RESULT");
            testCase.verifyEqual(string(result.requestId), "req_place_1");
            testCase.verifyTrue(result.correct);
            testCase.verifyFalse(result.completed);
            testCase.verifyEqual(result.stars, 0);
            testCase.assertNoMessages(0.4);
        end

        function secondCorrectPlacementCompletesActivity(testCase)
            testCase.placeObject("req_a", "object_01", "basket_red", 0.2, 0.2);
            testCase.readMessages(2);

            testCase.placeObject("req_b", "object_02", "basket_blue", 0.7, 0.7);
            messages = testCase.readMessages(3);

            testCase.verifyEqual(numel(messages), 3, ...
                'Expected PLACE_RES, ACTIVITY_RESULT and GAME_PROGRESS.');
            placement = messages{1};
            testCase.verifyEqual(string(placement.type), "PLACE_RES");
            testCase.verifyEqual(placement.score, 2);

            result = messages{2};
            testCase.verifyEqual(string(result.type), "ACTIVITY_RESULT");
            testCase.verifyTrue(result.completed);
            testCase.verifyEqual(result.stars, 1);

            progress = messages{3};
            testCase.verifyEqual(string(progress.type), "GAME_PROGRESS");
            testCase.verifyEqual(progress.stars, 1);
            testCase.verifyEqual(string(progress.completedActivities), "COLOR");
            testCase.verifyFalse(progress.gameCompleted);
            testCase.assertNoMessages(0.4);
        end

        function completedActivitiesIsAlwaysJsonArray(testCase)
            % Regression: MATLAB's jsonencode converts a scalar string into
            % a JSON string. Unity's string[] field then stays null, so the
            % server must always emit an array on the wire.
            testCase.placeObject("req_arr_a", "object_01", "basket_red", 0.2, 0.2);
            testCase.readMessages(2);

            testCase.placeObject("req_arr_b", "object_02", "basket_blue", 0.7, 0.7);
            [messages, rawLines] = testCase.readMessages(3);

            testCase.verifyEqual(string(messages{3}.type), "GAME_PROGRESS");
            testCase.verifySubstring(rawLines(3), ...
                '"completedActivities":["COLOR"]');
            testCase.verifyFalse(contains(rawLines(3), ...
                '"completedActivities":"COLOR"'), ...
                'GAME_PROGRESS must not encode completedActivities as a JSON string.');
        end

        function incorrectPlacementIsReported(testCase)
            testCase.placeObject("req_wrong", "object_01", "basket_blue", 0.3, 0.3);
            messages = testCase.readMessages(2);

            placement = messages{1};
            testCase.verifyEqual(string(placement.type), "PLACE_RES");
            testCase.verifyTrue(placement.valid);
            testCase.verifyFalse(placement.correct);
            testCase.verifyEqual(placement.score, 0);

            result = messages{2};
            testCase.verifyEqual(string(result.type), "ACTIVITY_RESULT");
            testCase.verifyFalse(result.correct);
            testCase.verifyFalse(result.completed);
            testCase.verifyEqual(result.stars, 0);
        end

        function unknownActivityReturnsStructuredError(testCase)
            testCase.placeObject("req_unknown_a", "object_01", "basket_red", 0.1, 0.1, "MISSING");
            messages = testCase.readMessages(1);

            testCase.verifyEqual(string(messages{1}.type), "ERROR");
            testCase.verifyEqual(string(messages{1}.requestId), "req_unknown_a");
            testCase.verifyEqual(string(messages{1}.code), "UNKNOWN_ACTIVITY");
        end

        function unknownObjectReturnsStructuredError(testCase)
            testCase.placeObject("req_unknown_o", "object_99", "basket_red", 0.1, 0.1);
            messages = testCase.readMessages(1);

            testCase.verifyEqual(string(messages{1}.type), "ERROR");
            testCase.verifyEqual(string(messages{1}.code), "UNKNOWN_OBJECT");
        end

        function unknownTargetReturnsStructuredError(testCase)
            testCase.placeObject("req_unknown_t", "object_01", "basket_purple", 0.1, 0.1);
            messages = testCase.readMessages(1);

            testCase.verifyEqual(string(messages{1}.type), "ERROR");
            testCase.verifyEqual(string(messages{1}.code), "UNKNOWN_TARGET");
        end

        function missingRequiredFieldReturnsStructuredError(testCase)
            testCase.sendLine('{"type":"PLACE_REQ","requestId":"req_missing","activity":"COLOR","objectId":"object_01"}');
            messages = testCase.readMessages(1);

            testCase.verifyEqual(string(messages{1}.type), "ERROR");
            testCase.verifyEqual(string(messages{1}.requestId), "req_missing");
            testCase.verifyEqual(string(messages{1}.code), "INVALID_REQUEST");
            testCase.verifySubstring(string(messages{1}.message), "targetId");
        end

        function invalidJsonReturnsStructuredError(testCase)
            testCase.sendLine('{"type":"PING",');
            messages = testCase.readMessages(1);

            testCase.verifyEqual(string(messages{1}.type), "ERROR");
            testCase.verifyEqual(string(messages{1}.code), "INVALID_JSON");
            testCase.verifyEqual(string(messages{1}.requestId), "");
        end

        function unsupportedTypeIsRejected(testCase)
            testCase.sendLine('{"type":"HAND","requestId":"req_hand"}');
            messages = testCase.readMessages(1);

            testCase.verifyEqual(string(messages{1}.type), "ERROR");
            testCase.verifyEqual(string(messages{1}.requestId), "req_hand");
            testCase.verifyEqual(string(messages{1}.code), "UNSUPPORTED_TYPE");
        end

        function multipleMessagesInOneWriteAreFramed(testCase)
            payload = sprintf( ...
                '{"type":"PING","requestId":"req_m1"}\n{"type":"PING","requestId":"req_m2"}\n');
            testCase.sendRaw(payload);
            messages = testCase.readMessages(2);

            testCase.verifyEqual(numel(messages), 2);
            testCase.verifyEqual(string(messages{1}.requestId), "req_m1");
            testCase.verifyEqual(string(messages{2}.requestId), "req_m2");
            testCase.verifyEqual(string(messages{1}.type), "PONG");
            testCase.verifyEqual(string(messages{2}.type), "PONG");
        end

        function partialMessageIsReassembled(testCase)
            payload = '{"type":"PING","requestId":"req_partial"}';
            split = floor(numel(payload) / 2);

            testCase.sendRaw(payload(1:split));
            testCase.assertNoMessages(0.3);

            testCase.sendRaw(payload(split + 1:end));
            testCase.sendRaw(char(10));
            messages = testCase.readMessages(1);

            testCase.verifyEqual(numel(messages), 1);
            testCase.verifyEqual(string(messages{1}.type), "PONG");
            testCase.verifyEqual(string(messages{1}.requestId), "req_partial");
        end

        function duplicateRequestIdIsIgnored(testCase)
            testCase.sendLine('{"type":"PING","requestId":"req_dup"}');
            messages = testCase.readMessages(1);
            testCase.verifyEqual(string(messages{1}.requestId), "req_dup");

            testCase.sendLine('{"type":"PING","requestId":"req_dup"}');
            testCase.assertNoMessages(0.5);

            testCase.sendLine('{"type":"PING","requestId":"req_after_dup"}');
            messages = testCase.readMessages(1);
            testCase.verifyEqual(string(messages{1}.requestId), "req_after_dup");
            testCase.verifyEqual(string(messages{1}.type), "PONG");
        end

        function serverSurvivesDisconnectAndAcceptsReconnect(testCase)
            delete(testCase.Client);
            testCase.Client = [];
            testCase.RxBuffer = uint8([]);
            testCase.PendingMessages = {};
            testCase.PendingRawLines = strings(1, 0);
            testCase.waitForConnection(false, 5);

            testCase.verifyFalse(testCase.Server.ClientConnected);
            testCase.verifyTrue(testCase.Server.Running);

            testCase.Client = tcpclient("127.0.0.1", 55101);
            testCase.waitForConnection(true, 5);
            testCase.verifyTrue(testCase.Server.ClientConnected);

            testCase.sendLine('{"type":"PING","requestId":"req_reconnected"}');
            messages = testCase.readMessages(1);

            testCase.verifyEqual(numel(messages), 1);
            testCase.verifyEqual(string(messages{1}.type), "PONG");
            testCase.verifyEqual(string(messages{1}.requestId), "req_reconnected");
        end

        function stopReleasesConnection(testCase)
            testCase.Server.stop();

            testCase.verifyFalse(testCase.Server.Running);
            testCase.verifyFalse(testCase.Server.ClientConnected);
        end
    end

    methods (Access = private)
        function waitForConnection(testCase, expected, timeoutSeconds)
            deadline = tic;
            while testCase.Server.ClientConnected ~= expected && toc(deadline) < timeoutSeconds
                pause(0.05);
            end
        end

        function sendLine(testCase, text)
            writeline(testCase.Client, string(text));
        end

        function sendRaw(testCase, text)
            write(testCase.Client, uint8(char(text)));
        end

        function placeObject(testCase, requestId, objectId, targetId, x, y, activity)
            if nargin < 7
                activity = "COLOR";
            end
            message = struct( ...
                'type', "PLACE_REQ", ...
                'requestId', string(requestId), ...
                'activity', string(activity), ...
                'objectId', string(objectId), ...
                'targetId', string(targetId), ...
                'position', struct('x', x, 'y', y));
            testCase.sendLine(jsonencode(message));
        end

        function [messages, rawLines] = readMessages(testCase, count, timeoutSeconds)
            if nargin < 3
                timeoutSeconds = 5;
            end

            testCase.pump();
            deadline = tic;
            while numel(testCase.PendingMessages) < count && toc(deadline) < timeoutSeconds
                pause(0.02);
                testCase.pump();
            end

            take = min(count, numel(testCase.PendingMessages));
            messages = testCase.PendingMessages(1:take);
            rawLines = testCase.PendingRawLines(1:take);
            testCase.PendingMessages(1:take) = [];
            testCase.PendingRawLines(1:take) = [];
        end

        function assertNoMessages(testCase, waitSeconds)
            if nargin < 2
                waitSeconds = 0.4;
            end
            deadline = tic;
            while toc(deadline) < waitSeconds
                pause(0.02);
                testCase.pump();
            end
            testCase.verifyEmpty(testCase.PendingMessages, ...
                'Expected no additional messages from the server.');
        end

        function pump(testCase)
            if isempty(testCase.Client)
                return
            end
            available = testCase.Client.NumBytesAvailable;
            if available <= 0
                return
            end
            data = read(testCase.Client, available, "uint8");
            testCase.RxBuffer = [testCase.RxBuffer, reshape(data, 1, [])];
            [lines, testCase.RxBuffer] = testCase.extractLines(testCase.RxBuffer);
            for k = 1:numel(lines)
                testCase.PendingMessages{end + 1} = jsondecode(lines(k));
                testCase.PendingRawLines(end + 1) = lines(k);
            end
        end
    end

    methods (Static, Access = private)
        function [lines, remainder] = extractLines(buffer)
            lines = strings(1, 0);
            remainder = buffer;
            while true
                index = find(remainder == uint8(10), 1, 'first');
                if isempty(index)
                    break;
                end
                lines(end + 1) = string( ...
                    native2unicode(remainder(1:index - 1), "UTF-8")); %#ok<AGROW>
                remainder = remainder(index + 1:end);
            end
        end
    end
end
