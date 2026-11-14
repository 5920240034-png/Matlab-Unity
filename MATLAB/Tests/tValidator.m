classdef tValidator < matlab.unittest.TestCase
%TVALIDATOR Unit tests for authoritative placement validation.

    properties
        Definition
    end

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (TestMethodSetup)
        function createDefinition(testCase)
            objects = [ ...
                struct('id', "object_01", 'target', "basket_red"); ...
                struct('id', "object_02", 'target', "basket_blue")];
            testCase.Definition = cmr.activities.Definition("COLOR", objects, ...
                ["basket_red", "basket_blue", "basket_green"], "Color Sorting");
        end
    end

    methods (Test)
        function acceptsCorrectPlacement(testCase)
            result = cmr.activities.Validator.validate( ...
                testCase.Definition, "object_01", "basket_red");
            testCase.verifyTrue(result.valid);
            testCase.verifyTrue(result.correct);
            testCase.verifyEqual(result.message, "Correct placement");
        end

        function rejectsIncorrectPlacement(testCase)
            result = cmr.activities.Validator.validate( ...
                testCase.Definition, "object_01", "basket_blue");
            testCase.verifyTrue(result.valid);
            testCase.verifyFalse(result.correct);
        end

        function reportsUnknownObject(testCase)
            result = cmr.activities.Validator.validate( ...
                testCase.Definition, "object_99", "basket_red");
            testCase.verifyFalse(result.valid);
            testCase.verifyEqual(result.code, cmr.net.Protocol.ErrorUnknownObject);
        end

        function reportsUnknownTarget(testCase)
            result = cmr.activities.Validator.validate( ...
                testCase.Definition, "object_01", "basket_purple");
            testCase.verifyFalse(result.valid);
            testCase.verifyEqual(result.code, cmr.net.Protocol.ErrorUnknownTarget);
        end
    end
end
