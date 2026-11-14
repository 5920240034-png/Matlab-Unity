classdef Session < handle
%SESSION Authoritative game progress for one play session.
%
%   Tracks which objects have been solved per activity, which activities are
%   complete and how many stars have been awarded. Unity never awards stars.

    properties (SetAccess = private)
        Stars (1,1) double = 0
        CompletedActivities string = strings(1, 0)
        TotalActivities (1,1) double
    end

    properties (Access = private)
        Solved containers.Map
    end

    methods
        function obj = Session(totalActivities)
            if nargin < 1 || isempty(totalActivities)
                totalActivities = cmr.net.Protocol.ExpectedActivityCount;
            end
            obj.TotalActivities = totalActivities;
            obj.Solved = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function outcome = applyPlacement(obj, definition, objectId, correct)
            %APPLYPLACEMENT Record a validated placement and update progress.
            %
            %   outcome.completed is true only the first time an activity
            %   reaches all of its objects. Stars are awarded once per
            %   activity, never per placement.
            outcome = struct( ...
                'completed', false, ...
                'newlySolved', false, ...
                'score', 0, ...
                'stars', obj.Stars);

            key = char(definition.Id);
            if ~isKey(obj.Solved, key)
                obj.Solved(key) = strings(1, 0);
            end
            solved = obj.Solved(key);
            objectId = string(objectId);

            if correct && ~any(solved == objectId)
                solved(end + 1) = objectId;
                obj.Solved(key) = solved;
                outcome.newlySolved = true;
            end

            outcome.score = numel(solved);

            alreadyCompleted = any(obj.CompletedActivities == definition.Id);
            if ~alreadyCompleted && outcome.score >= definition.objectCount()
                obj.CompletedActivities(end + 1) = definition.Id;
                obj.Stars = obj.Stars + 1;
                outcome.completed = true;
            end

            outcome.stars = obj.Stars;
        end

        function tf = isCompleted(obj, activityId)
            tf = any(obj.CompletedActivities == string(activityId));
        end

        function tf = isGameCompleted(obj)
            tf = numel(obj.CompletedActivities) >= obj.TotalActivities;
        end

        function progress = progress(obj)
            progress = struct( ...
                'stars', obj.Stars, ...
                'completedActivities', obj.CompletedActivities, ...
                'gameCompleted', obj.isGameCompleted());
        end

        function reset(obj)
            obj.Stars = 0;
            obj.CompletedActivities = strings(1, 0);
            obj.Solved = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
    end
end
