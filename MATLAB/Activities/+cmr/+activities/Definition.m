classdef Definition
%DEFINITION Immutable activity definition owned by MATLAB.
%
%   A definition maps every object to exactly one correct target. Unity only
%   receives object identifiers and never knows the correct answers.

    properties (SetAccess = private)
        Id string
        Title string
        Objects struct
        Targets string
    end

    methods
        function obj = Definition(id, objects, targets, title)
            arguments
                id (1,1) string
                objects struct
                targets (1,:) string
                title (1,1) string = ""
            end

            if strlength(id) == 0
                error('cmr:activities:Definition:emptyId', ...
                    'Activity id must not be empty.');
            end
            if isempty(targets)
                error('cmr:activities:Definition:noTargets', ...
                    'Activity "%s" has no targets.', id);
            end
            if numel(unique(targets)) ~= numel(targets)
                error('cmr:activities:Definition:duplicateTargets', ...
                    'Activity "%s" has duplicate targets.', id);
            end

            objectIds = strings(1, numel(objects));
            for k = 1:numel(objects)
                if ~isfield(objects, 'id') || ~isfield(objects, 'target')
                    error('cmr:activities:Definition:invalidObject', ...
                        'Activity "%s" objects need "id" and "target" fields.', id);
                end
                objectIds(k) = string(objects(k).id);
                if ~any(targets == string(objects(k).target))
                    error('cmr:activities:Definition:unknownTarget', ...
                        'Object "%s" references unknown target "%s".', ...
                        string(objects(k).id), string(objects(k).target));
                end
            end
            if numel(unique(objectIds)) ~= numel(objectIds)
                error('cmr:activities:Definition:duplicateObjects', ...
                    'Activity "%s" has duplicate object ids.', id);
            end
            if isempty(objectIds)
                error('cmr:activities:Definition:noObjects', ...
                    'Activity "%s" has no objects.', id);
            end

            obj.Id = id;
            obj.Title = title;
            obj.Objects = objects;
            obj.Targets = targets;
        end

        function n = objectCount(obj)
            n = numel(obj.Objects);
        end

        function tf = hasObject(obj, objectId)
            tf = any(obj.objectIds() == string(objectId));
        end

        function tf = hasTarget(obj, targetId)
            tf = any(obj.Targets == string(targetId));
        end

        function target = targetFor(obj, objectId)
            target = "";
            for k = 1:numel(obj.Objects)
                if string(obj.Objects(k).id) == string(objectId)
                    target = string(obj.Objects(k).target);
                    return
                end
            end
        end

        function ids = objectIds(obj)
            ids = strings(1, 0);
            for k = 1:numel(obj.Objects)
                ids(end + 1) = string(obj.Objects(k).id); %#ok<AGROW>
            end
        end
    end

    methods (Static)
        function def = fromStruct(raw)
            %FROMSTRUCT Build a definition from decoded activity JSON.
            if ~isstruct(raw) || ~isscalar(raw)
                error('cmr:activities:Definition:invalidFile', ...
                    'Activity definition must be a JSON object.');
            end
            required = ["id", "objects", "targets"];
            for name = required
                if ~isfield(raw, name)
                    error('cmr:activities:Definition:invalidFile', ...
                        'Activity definition is missing field "%s".', name);
                end
            end

            id = string(raw.id);

            rawObjects = raw.objects;
            if iscell(rawObjects)
                rawObjects = [rawObjects{:}];
            end
            if ~isstruct(rawObjects) || isempty(rawObjects)
                error('cmr:activities:Definition:invalidFile', ...
                    'Activity "%s" field "objects" must be a non-empty array.', id);
            end

            objects = repmat(struct('id', "", 'target', ""), 1, numel(rawObjects));
            for k = 1:numel(rawObjects)
                objects(k).id = string(rawObjects(k).id);
                objects(k).target = string(rawObjects(k).target);
            end

            targets = string(raw.targets);
            targets = reshape(targets, 1, []);

            title = "";
            if isfield(raw, 'title')
                title = string(raw.title);
            end

            def = cmr.activities.Definition(id, objects, targets, title);
        end
    end
end
