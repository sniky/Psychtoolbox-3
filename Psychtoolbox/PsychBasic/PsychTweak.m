function varargout = PsychTweak(cmd, varargin) %#ok<STOUT>
% PsychTweak() - Apply tweaks to various Psychtoolbox parameters.
%
% This function allows to tweak some low-level operating parameters of
% Psychtoolbox. Such tweaks often affect all mex files, not only specific
% files. You must execute this function before any other Psychtoolbox mex
% file is used, otherwise mex files will not pick up consistent settings
% and weird things may happen! If in doubt, execute "clear mex" before
% executing this function.
%
% Currently the function mostly implements tweaks for MS-Windows to allow
% to cope with the brokeness of the system, especially in the domain of
% timing and timestamping.
%
%
% Available subfunctions:
% =======================
%
% MS-Windows only tweaks:
% -----------------------
%
% PsychTweak('BackwardTimejumpTolerance', secs);
% -- Allow system clock to report a time that is up to 'secs' in the past,
% ie., for time to jump backwards, without triggering any clock error
% handling. Some broken or deficient computer hardware shows this
% misbehaviour and MS-Windows can't cope with it. Normally PTB would
% trigger workarounds and error handling, but a small amount of this error
% apparently must be tolerated even on the latest generation of processor
% hardware to make some systems workable at all under MS-Windows.
%
% By default, PTB tolerates up to 100 nanoseconds aka 1e-7 secs of error.
%
% Some Intel Core i5 / i7 cpu's have been reported to exhibit errors of
% multiple microseconds, sometimes up to even over 10 microseconds!
%
%
% PsychTweak('ForwardTimejumpTolerance', secs);
% -- Allow system clock to report a time that is up to 'secs' in the future,
% ie., for time to jump forward, without triggering any clock error
% handling. Some broken or deficient computer hardware shows this
% misbehaviour and MS-Windows can't cope with it. Normally PTB would
% trigger workarounds and error handling, but a small amount of this error
% apparently must be tolerated even on the latest generation of processor
% hardware to make some systems workable at all under MS-Windows.
%
% By default, PTB tolerates up to 250 msecs aka 0.25 secs of error, not
% because we expect such large errors on a well working system, but because
% the detection logic needs to allow some room for fuzzyness to avoid false
% alerts on heavily loaded systems.
%
%
% PsychTweak('ExecuteOnCPUCores', corelist);
% -- Restrict execution of timing sensitive Psychtoolbox processing threads
% to a subset of logical processor cores on a multi-core / multi-processor
% computer. This allows to workaround some bugs in timing hardware, but can
% seriously degrade performance and general timing behaviour of
% Psychtoolbox under more demanding workloads, so this may either help or
% hurt, depending on the system setup and application.
% 'corelist' must be a vector with the numbers of cores that PTB threads
% are allowed to execute on, numbering starts with zero, ie., the 1st
% processor core has the number zero.
%
% By default, PTB does not restrict threads on Windows Vista and later, or
% on other operating systems than Windows, but restricts all threads to
% core zero on Windows XP. The most meaningful use of this parameter is to
% either restrict processing to core zero for Windows Vista and later if
% you know that this helps, or to allow threads on WindowsXP to execute on
% all available cores if you know that your system configuration is not
% susceptible to timing bugs in multi-core mode. PTB will normally
% automatically switch to single-core operation on any OS if timing bugs
% are detected -- it tries to fix itself.
%
%
% PsychTweak('ClockWorkarounds' [, warning = 1][, lockCores = 1][, lowres = 0][, abort = 0][, defaultlowres = 0]);
% -- Define how PTB should behave if it detects clock problems due to
% broken or misconfigured hardware. All flags are boolean with 1 = enable,
% 0 = disable, and all flags are optional with reasonable default settings.
%
% 'warning': 1 = Print critical warning messages to the command window to
% warn user about potentially broken timing in its scripts.
% This setting is on by default.
%
% 'lockCores': 1 = On first signs of trouble, switch to single processor
% operation, locking all processing threads to cpu core zero, then
% continue. Many multi-processor related clock bugs can be "fixed" this
% way, but performance and execution timing may be seriously impaired if
% all threads have to compete for computation time on one single processor
% core, while all other cores on a multi-core machine are essentially
% unused and idle. See help for 'ExecuteOnCPUCores' for more explanation.
% This setting is on by default.
%
% 'lowres': 1 = Switch to a low-resolution backup timer if the 'lockCores'
% workaround is disabled or proven ineffective to solve the problem. The
% lowres timer has only +/- 1 msec resolution and this workaround may only
% allow you to continue with very simple experiment scripts. Experiment
% scripts involving sound via PsychPortAudio + ASIO sound hardware,
% Videocapture or Videorecording, and other types of hardware input/output
% may fail in weird ways. Even for simple scripts, this may create new
% weird timing related problems.
% This setting is off by default due to the trouble it can cause.
%
% 'abort': 1 = Abort userscript / session if clock problems can't be fixed
% / worked around sufficiently well via the 'lockCores' workaround, ie., if
% after enabling the workaround a successive clock error gets detected.
% This setting is off by default.
%
% 'defaultlowres': 1 = Use low-res backup timer by default, ignore the
% high-precision clock. This may help a script on a broken system to limp
% along, but is not recommended for production use, because it has the same
% problems as the 'lowres' workaround.
% This setting is off by default.
%
%

% History:
% 9.07.2012  mk  Wrote it.
%

if nargin < 1 || isempty(cmd)
    help PsychTweak;
    return;
end

% This routine must be called before any PTB mex files are loaded,
% otherwise they won't pick up the tweak settings consistently. Check if
% any ptb mex files are loaded:

% inmem not yet implemented as of Octave 3.6.x, so Matlab only:
if exist('inmem') %#ok<EXIST>
    % Get list of all loaded mex files in cell array mexf:
    [foo, mexf] = inmem('-completenames'); %#ok<ASGLU>
    % We check for files who are stored in a filesystem path that has the
    % string 'psychtoolbox' in its name. We cannot simply check for
    % PsychtoolboxRoot, as users may place mex files in non-standard
    % locations, but one would at least hope they store them in something
    % with 'psychtoolbox' in its name:
    for i=1:length(mexf)
        if ~isempty(strfind(lower(mexf{i}), lower('psychtoolbox')))
            error('At least one Psychtoolbox mex file is already loaded: (%s). PsychTweak must be executed before any other Psychtoolbox mex file!', mexf{i});
        end
    end
end

if strcmpi(cmd, 'BackwardTimejumpTolerance')
    if length(varargin) < 1
        error('Must provide a timing threshold in seconds.');
    end
    
    val = varargin{1} * 1e9;
    if val < 0 || val > intmax
        error('Value must be between 0 and 2 seconds.');
    end

    setenv('PSYCH_BACKWARD_TIMEJUMP_TOLERANCE_NSECS', sprintf('%i', round(val)));
    return;
end

if strcmpi(cmd, 'ForwardTimejumpTolerance')
    if length(varargin) < 1
        error('Must provide a timing threshold in seconds.');
    end
    
    val = varargin{1} * 1e3;
    if val < 0 || val > intmax
        error('Value must be between 0 and 2 million seconds.');
    end
    
    setenv('PSYCH_FORWARD_TIMEJUMP_TOLERANCE_MSECS', sprintf('%i', round(val)));
    return;
end

if strcmpi(cmd, 'ExecuteOnCPUCores')
    if length(varargin) < 1
        error('Must provide a list of cpu cores to run Psychtoolbox threads on.');
    end
    
    val = varargin{1};
    if ~isnumeric(val) || ~isvector(val) || min(val) < 0 || max(val) > 31
        error('%s: Parameter must be an integer vector of cpu core ids between 0 and 31.', cmd);
    end
    val = round(val);
    
    % Convert core id's in parameter to cpu bitmask:
    cpumask = 0;
    for i=1:length(val)
       cpumask = cpumask + 2^(val(i));
    end
    
    setenv('PSYCH_CPU_MASK', sprintf('%i', round(cpumask)));
    return;
end

if strcmpi(cmd, 'ClockWorkarounds')
    if length(varargin) < 1
        error('Must provide a parameter list.');
    end
    
    if length(varargin) >= 1 && ~isempty(varargin{1})
        warningout = round(varargin{1});
    else
        warningout = 1;
    end
    
    if length(varargin) >= 2 && ~isempty(varargin{2})
        corelockwa = round(varargin{2});
    else
        corelockwa = 1;
    end
    
    if length(varargin) >= 3 && ~isempty(varargin{3})
        lowreswa = round(varargin{3});
    else
        lowreswa = 0;
    end
    
    if length(varargin) >= 4 && ~isempty(varargin{4})
        errabort = round(varargin{4});
    else
        errabort = 0;
    end
    
    if length(varargin) >= 5 && ~isempty(varargin{5})
        lowresdef = round(varargin{5});
    else
        lowresdef = 0;
    end
    
    val = 0;
    
    if warningout
        val = val + 1;
    end
    
    if corelockwa
        val = val + 2;
    end
    
    if lowreswa
        val = val + 4;
    end

    if errabort
        val = val + 8;
    end

    if lowresdef
        val = val + 16;
    end

    setenv('PSYCH_CLOCKERROR_MODE', sprintf('%i', round(val)));
    return;
end

% Nothing dispatched? Give help to the helpless:
help PsychTweak;
error('Invalid or unknown command specified.');

end