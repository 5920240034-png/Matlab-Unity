function server = startServer(varargin)
%STARTSERVER Start the MATLAB TCP server for the Clean My Room game.
%
%   server = startServer() blocks until Ctrl+C and stops the server on exit.
%   server = startServer(Name, Value) returns a started server handle so the
%   caller owns the lifecycle (used by tests and tooling).
%
%   Name-Value options:
%       Host            Default 127.0.0.1
%       Port            Default 55001
%       DataDirectory   Default Shared_Data/ActivityData
%       TotalActivities Default 3
%       Verbose         Default true

    root = fileparts(mfilename('fullpath'));
    addpath(genpath(root));

    parser = inputParser;
    parser.addParameter('Host', cmr.net.Protocol.DefaultHost, ...
        @(value) isstring(value) || ischar(value));
    parser.addParameter('Port', cmr.net.Protocol.DefaultPort, ...
        @(value) isnumeric(value) && isscalar(value) && value > 0 && value <= 65535);
    parser.addParameter('DataDirectory', "", ...
        @(value) isstring(value) || ischar(value));
    parser.addParameter('TotalActivities', cmr.net.Protocol.ExpectedActivityCount, ...
        @(value) isnumeric(value) && isscalar(value) && value > 0);
    parser.addParameter('Verbose', true, @(value) islogical(value) && isscalar(value));
    parser.parse(varargin{:});

    dataDirectory = string(parser.Results.DataDirectory);
    if strlength(dataDirectory) == 0
        dataDirectory = string(fullfile(root, '..', 'Shared_Data', 'ActivityData'));
    end

    registry = cmr.activities.Registry(dataDirectory);
    session = cmr.game.Session(parser.Results.TotalActivities);

    server = cmr.net.Server(registry, session, ...
        'Host', string(parser.Results.Host), ...
        'Port', parser.Results.Port, ...
        'Verbose', parser.Results.Verbose);

    if isempty(which('tcpserver'))
        error('cmr:startServer:missingTcpserver', ...
            'tcpserver is not available in this MATLAB installation.');
    end

    server.start();

    if nargout == 0
        fprintf('Clean My Room - MATLAB server\n');
        fprintf('Address         : %s:%d\n', server.Host, server.Port);
        fprintf('Activity folder : %s\n', dataDirectory);
        fprintf('Activities      : %d\n', registry.count());
        fprintf('Press Ctrl+C to stop the server.\n');
        cleanup = onCleanup(@() server.stop()); %#ok<NASGU>
        server.run(Inf);
        server.stop();
    end
end
