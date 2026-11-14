classdef tSession < matlab.unittest.TestCase
%TSESSION Unit tests for authoritative game progress tracking.
%
%   These tests verify that stars and activity completion are decided by
%   MATLAB only. Unity has no equivalent logic.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (Test)
        function startsEmpty(testCase)
            session = cmr.game.Session(3);
            testCase.verifyEqual(session.Stars, 0);
            testCase.verifyEmpty(session.CompletedActivities);
            testCase.verifyFalse(session.isGameCompleted());
        end

        function correctPlacementScoresWithoutCompleting(testCase)
            definition = testCase.makeDefinition("COLOR", 2);
            session = cmr.game.Session(3);

            outcome = session.applyPlacement(definition, "object_1", true);

            testCase.verifyTrue(outcome.newlySolved);
            testCase.verifyFalse(outcome.completed);
            testCase.verifyEqual(outcome.score, 1);
            testCase.verifyEqual(outcome.stars, 0);
        end

        function completingActivityAwardsOneStar(testCase)
            definition = testCase.makeDefinition("COLOR", 2);
            session = cmr.game.Session(3);

            session.applyPlacement(definition, "object_1", true);
            outcome = session.applyPlacement(definition, "object_2", true);

            testCase.verifyTrue(outcome.completed);
            testCase.verifyEqual(outcome.score, 2);
            testCase.verifyEqual(outcome.stars, 1);
            testCase.verifyTrue(session.isCompleted("COLOR"));
        end

        function duplicatePlacementDoesNotIncreaseScore(testCase)
            definition = testCase.makeDefinition("COLOR", 2);
            session = cmr.game.Session(3);

            session.applyPlacement(definition, "object_1", true);
            outcome = session.applyPlacement(definition, "object_1", true);

            testCase.verifyFalse(outcome.newlySolved);
            testCase.verifyFalse(outcome.completed);
            testCase.verifyEqual(outcome.score, 1);
        end

        function incorrectPlacementDoesNotScore(testCase)
            definition = testCase.makeDefinition("COLOR", 2);
            session = cmr.game.Session(3);

            outcome = session.applyPlacement(definition, "object_1", false);

            testCase.verifyFalse(outcome.newlySolved);
            testCase.verifyFalse(outcome.completed);
            testCase.verifyEqual(outcome.score, 0);
            testCase.verifyEqual(outcome.stars, 0);
        end

        function completingActivityTwiceDoesNotAwardExtraStar(testCase)
            definition = testCase.makeDefinition("COLOR", 2);
            session = cmr.game.Session(3);

            session.applyPlacement(definition, "object_1", true);
            session.applyPlacement(definition, "object_2", true);

            outcome = session.applyPlacement(definition, "object_1", true);

            testCase.verifyFalse(outcome.completed);
            testCase.verifyEqual(outcome.stars, 1);
            testCase.verifyEqual(numel(session.CompletedActivities), 1);
        end

        function gameCompletesAfterAllActivities(testCase)
            session = cmr.game.Session(3);
            ids = ["COLOR", "TASTE", "MATH"];

            for id = ids
                definition = testCase.makeDefinition(id, 1);
                session.applyPlacement(definition, "object_1", true);
            end

            progress = session.progress();

            testCase.verifyEqual(progress.stars, 3);
            testCase.verifyEqual(string(progress.completedActivities), ids);
            testCase.verifyTrue(progress.gameCompleted);
            testCase.verifyTrue(session.isGameCompleted());
        end

        function resetClearsProgress(testCase)
            definition = testCase.makeDefinition("COLOR", 1);
            session = cmr.game.Session(3);
            session.applyPlacement(definition, "object_1", true);

            session.reset();

            testCase.verifyEqual(session.Stars, 0);
            testCase.verifyEmpty(session.CompletedActivities);
            testCase.verifyFalse(session.isGameCompleted());
        end
    end

    methods (Access = private)
        function definition = makeDefinition(~, id, objectCount)
            objects = repmat(struct('id', "", 'target', ""), 1, objectCount);
            targets = strings(1, objectCount);
            for k = 1:objectCount
                objects(k).id = "object_" + k;
                objects(k).target = "target_" + k;
                targets(k) = "target_" + k;
            end
            definition = cmr.activities.Definition(id, objects, targets, "Test");
        end
    end
end
