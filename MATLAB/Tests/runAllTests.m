function results = runAllTests()
%RUNALLTESTS Run the full MATLAB unit and protocol test suite.
%
%   results = runAllTests() discovers every matlab.unittest.TestCase class
%   under MATLAB/Tests, runs it and throws when any test fails. The throw is
%   intentional: it makes "matlab -batch runAllTests" exit with an error so
%   CI and the project owner cannot mistake a failed run for a passing one.

    testsDirectory = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(testsDirectory);

    addpath(genpath(projectRoot));
    addpath(testsDirectory);

    suite = matlab.unittest.TestSuite.fromFolder( ...
        testsDirectory, 'IncludingSubfolders', true);

    runner = matlab.unittest.TestRunner.withTextOutput( ...
        'OutputDetail', matlab.unittest.Verbosity.Detailed);

    results = runner.run(suite);

    passed = sum([results.Passed]);
    failed = sum([results.Failed]);
    incomplete = sum([results.Incomplete]);
    total = numel(results);
    duration = sum([results.Duration]);

    fprintf('\n=== MATLAB TEST SUMMARY ===\n');
    fprintf('Total      : %d\n', total);
    fprintf('Passed     : %d\n', passed);
    fprintf('Failed     : %d\n', failed);
    fprintf('Incomplete : %d\n', incomplete);
    fprintf('Duration   : %.2f s\n', duration);
    fprintf('===========================\n');

    if failed > 0
        names = string({results([results.Failed]).Name});
        error('cmr:tests:failed', ...
            '%d test(s) failed: %s', failed, strjoin(names, ', '));
    end
end
