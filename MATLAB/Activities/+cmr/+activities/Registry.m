classdef Registry < handle
%REGISTRY In-memory collection of activity definitions keyed by activity id.
%
%   Definitions are loaded from JSON files under Shared_Data/ActivityData.
%   Invalid files are skipped with a warning so one bad file cannot stop the
%   server from starting.

    properties (SetAccess = private)
        DataDirectory string = ""
    end

    properties (Access = private)
        Activities containers.Map
    end

    methods
        function obj = Registry(dataDirectory)
            obj.Activities = containers.Map('KeyType', 'char', 'ValueType', 'any');
            if nargin >= 1
                directory = string(dataDirectory);
                if strlength(directory) > 0
                    obj.loadDirectory(directory);
                end
            end
        end

        function register(obj, definition)
            if ~isa(definition, 'cmr.activities.Definition')
                error('cmr:activities:Registry:invalidDefinition', ...
                    'Only cmr.activities.Definition objects can be registered.');
            end
            obj.Activities(char(definition.Id)) = definition;
        end

        function definition = get(obj, activityId)
            key = char(string(activityId));
            if isKey(obj.Activities, key)
                definition = obj.Activities(key);
            else
                definition = [];
            end
        end

        function tf = has(obj, activityId)
            tf = isKey(obj.Activities, char(string(activityId)));
        end

        function n = count(obj)
            n = obj.Activities.Count;
        end

        function ids = activityIds(obj)
            ids = string(keys(obj.Activities));
        end

        function loadDirectory(obj, directory)
            directory = string(directory);
            if strlength(directory) == 0 || ~isfolder(directory)
                return
            end

            obj.DataDirectory = directory;
            files = dir(fullfile(directory, "*.json"));
            for k = 1:numel(files)
                path = fullfile(files(k).folder, files(k).name);
                try
                    raw = jsondecode(fileread(path));
                    definition = cmr.activities.Definition.fromStruct(raw);
                    obj.register(definition);
                catch err
                    warning('cmr:activities:Registry:invalidFile', ...
                        'Skipping activity file "%s": %s', files(k).name, err.message);
                end
            end
        end
    end
end
