classdef Validator
%VALIDATOR Authoritative placement validation performed by MATLAB.

    methods (Static)
        function result = validate(definition, objectId, targetId)
            %VALIDATE Check one placement against an activity definition.
            result = struct( ...
                'valid', false, ...
                'correct', false, ...
                'code', "", ...
                'message', "");

            if ~isa(definition, 'cmr.activities.Definition')
                result.code = cmr.net.Protocol.ErrorInvalidRequest;
                result.message = "Unknown activity definition.";
                return
            end

            objectId = string(objectId);
            targetId = string(targetId);

            if ~definition.hasObject(objectId)
                result.code = cmr.net.Protocol.ErrorUnknownObject;
                result.message = "Unknown object '" + objectId + "'.";
                return
            end

            if ~definition.hasTarget(targetId)
                result.code = cmr.net.Protocol.ErrorUnknownTarget;
                result.message = "Unknown target '" + targetId + "'.";
                return
            end

            result.valid = true;
            result.correct = definition.targetFor(objectId) == targetId;
            if result.correct
                result.message = "Correct placement";
            else
                result.message = "Incorrect placement. Try again.";
            end
        end
    end
end
