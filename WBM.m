function outfilename=WBM(filename,url_part,varargin)
% This functions acts as an API for the Wayback Machine (web.archive.org).
%
% With this function you can download captures to the internet archive that matches a date pattern.
% If the current time matches the pattern and there is no valid capture, a capture will be
% generated. Since the WBM time stamps are in UTC, local time will be converted.
%
% This code enables you to use a specific web page in your data processing, without the need to
% check if the page has changed its structure or is not available at all.
%
% Usage instruction about the syntax of the WBM interface are derived from a Wikipedia help page:
% https://en.wikipedia.org/wiki/Help:Using_the_Wayback_Machine
%
% syntax:
% outfilename=WBM(filename,url_part)
% outfilename=WBM(___,options)
% outfilename=WBM(___,Name,Value)
%
% outfilename: Full path of the output file, the variable is empty if the download failed.
% filename   : The target filename in any format that websave (or urlwrite) accepts. If this file
%              already exists, it will be overwritten in most cases.
% url_part   : This url will be searched for on the WBM. The url might be changed (e.g. ':80' is 
%              often added).
% options    : A struct containing the fields date_part, tries, response, ignore, verbose,
%              m_date_r, and flag. Missing fields are filled with default values. Typos will
%              trigger an error.
%
% date_part : A string with the date of the capture. It must be in the yyyymmddHHMMSS format, but
%             doesn't have to be complete. Note that this is represented in UTC. [default='2';]
% tries     : A 1x3 vector. The first value is the total number of times an attempt to load the
%             page is made, the second value is the number of save attempts and the last value is
%             the number of timeouts allowed. [default=[5 4 4];]
% verbose   : A scalar denoting the verbosity. Level 1 includes only warnings about the internet
%             connection being down. Level 2 includes errors  NOT matching the usual pattern as
%             well and level 3 includes all other errors that get rethrown as disp or warning.
%             Level 0 will hide all errors that are caught. [default=3;]
%             Octave uses libcurl, making error catching is bit more difficult. This will result in
%             more errors being rethrown as warnings under Octave than Matlab.
% print_to  : A struct with three fields: 'use_fprintf' (logical) controls if anything that is
%             written to the screen should be printed with fprintf or not. If no fid is provided in
%             the 'fid' field (double), the screen (fid=1) is used. If the 'use_fprintf' field is
%             false, the 'object' field should be an object with a Sting property, e.g. an edit
%             field in a GUI. [default=struct('use_fprintf',true,'fid',1,'object',[]);]
% m_date_r  : A string describing the response to the date missing in the downloaded web page.
%             Usually, either the top bar will be present (which contains links), or the page
%             itself will contain links, so this situation may indicate a problem with the save to
%             the WBM. Allowed values are 'ignore', 'warning' and 'error'. Be aware that non-page
%             content (such as images) will set off this response. Flags other than '*' will also
%             set off this response. [default='warning';] if flags~='*' then [default='ignore']
% response  : The response variable is a cell array, where each row encodes one scenario. The
%             syntax of each row is as follows:
%             #1 If there is a sequence of failure that fit the first cell,
%             #2 and the HTML error codes of the sequence are equal to the second cell,
%             #3 then respond as per the third cell.
%             The sequence of failures are encoded like this:
%             t1: failed attempt to load, t2: failed attempt to save, tx: either failed to load, or
%             failed to save.
%             The error code list must be HTML status codes. The Matlab timeout error is encoded
%             with 4080 (analogous to the HTTP 408 timeout error code). The  error is extracted
%             from the identifier, which is not always possible, especially in the case of Octave.
%             The response in the third cell is either 'load', 'save', 'exit', or 'pause_retry'.
%             Load and save set the preferred type. If a response is not allowed by 'tries' left,
%             the other response (save or load) is tried, until sum(tries(1:2))==0. If the response
%             is set to exit, or there is still no successful download after tries has been
%             exhausted, the output file will be deleted and the script will exit. The pause_retry
%             is intended for use with an error 429. See the err429 parameter for more options.
%             [default={'tx',404,'load';'txtx',[404 404],'save';'tx',403,'save';'t2t2',[403
%             403],'exit';'tx',429,'pause_retry'};]
% err429    : Sometimes the webserver will return an 429 status code. This should trigger a waiting
%             period of a few seconds. This parameter controls the behavior of this function in
%             case of a 429 status code. It is a struct with the following fields. The CountsAsTry
%             field (logical) describes if the attempt should decrease the tries counter. The
%             TimeToWait field (double) contains the time in seconds to wait before retrying. The
%             PrintAtVerbosityLevel field (double) contains the verbosity level at which a text
%             should be printed, showing the user the function did not hang.
%             [default=struct('CountsAsTry',false,'TimeToWait',15, 'PrintAtVerbosityLevel',3);]
% ignore    : The ignore variable is vector with the same type of error codes as in the response
%             variable. Ignored errors will only be ignored for the purposes of the response, they
%             will not prevent the tries vector from decreasing. [default=4080;]
% flag      : The flags can be used to specify an explicit version of the archived page. The
%             options are 'id' (identical), 'js' (Javascript), 'cs' (CSS), 'im' (image) or *
%             (explicitly expand date, shows calendar in browser mode). With the 'id' flag the page
%             is show as captured (i.e. without the WBM banner, making it ideal for e.g. exe
%             files). With the 'id' and '*' flags the date check will fail, so the missing date
%             response (m_date_r) will be invoked. For the 'im' flag you can circumvent this by
%             first loading in the normal mode ('*'), and then extracting the image link from that
%             page. That way you can enforce a date pattern and still get the image. The Wikipedia
%             page suggest that a flag syntax requires a full date, but this seems not to be the
%             case, as the date can still auto-expand. [default='*';]
%
%  _________________________________________________________________
% | Compatibility | Windows 10  | Ubuntu 20.04 LTS | MacOS Catalina |
% |---------------|-------------|------------------|----------------|
% | ML R2020a     |  works      |  not tested      |  not tested    |
% | ML R2015a     |  works      |  not tested      |  not tested    |
% | ML R2011a     |  works      |  not tested      |  not tested    |
% | ML 6.5 (R13)  |  works      |  not tested      |  not tested    |
% | Octave 5.2.0  |  works      |  works           |  not tested    |
% | Octave 4.4.1  |  works      |  not tested      |  works         |
% """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
%
% Version: 1.6
% Date:    2020-06-28
% Author:  H.J. Wisselink
% Licence: CC by-nc-sa 4.0 ( creativecommons.org/licenses/by-nc-sa/4.0 )
% Email=  'h_j_wisselink*alumnus_utwente_nl';
% Real_email = regexprep(Email,{'*','_'},{'@','.'})

%The first time to run this function, test to see if compiling the UTC.c function works and error
%if it doesn't. This test should run only once, so it doesn't matter if it runs before any other
%input checking.
persistent IsFirstRun
if isempty(IsFirstRun)
    IsFirstRun=struct;
    IsFirstRun.boolean=true;
    IsFirstRun.errordlg_text=...
    	{{['The WBM function relies on a compiled c function to get the current time in UTC ',...
        'when offline or for Matlab 6.5. The automatic compiling mechanism appears to have ',...
        'failed. Please manually make sure utc_time.c is compiled for your system.']},...
        'utc_time.c compile failed'};
	IsFirstRun.ME.message='Retrieval of UTC failed.';
    IsFirstRun.ME.identifier='HJW:WBM:UTC_missing';
end
if IsFirstRun.boolean
    try
        %Trigger a compile of utc_time.c (or test it).
        if abs(WBM_getUTC_local-now)>(14.1/24)
            %UTC offsets range from -12 to +14. Larger offsets indicate an issue with either this
            %function or the computer time as detected by Matlab. (0.1 added to prevent float
            %rounding errors triggering a false positive)
            error('HJW:WBM:getUTCfail',['The getUTC function failed,',char(10),...
                'or the difference between now() and the UTC time is more than a day.',char(10),...
                'The getUTC function requires either internet access or folder write access.'])...
                 %#ok<CHARTEN>
        end
    catch
        %Keep it marked as first run so getUTC is tested again next call.
        errordlg(IsFirstRun.errordlg_text{:})
        error(IsFirstRun.ME.identifier,IsFirstRun.ME.message)
    end
    IsFirstRun.boolean=false;
end
if nargin<2
    error('HJW:WBM:nargin','Incorrect number of input argument.')
end
if ~(nargout==0 || nargout==1)
    error('HJW:WBM:nargout','Incorrect number of output argument.')
end
[success,opts,ME]=WBM_parse_inputs(filename,url_part,varargin{:});
if ~success
    %The throwAsCaller function was introduced in R2007b, hence the rethrow here.
    rethrow(ME)
else
    [date_part,tries,response,ignore,verbose,m_date_r,UseURLwrite,flag,err429,print_to]=...
        deal(opts.date_part,opts.tries,opts.response,opts.ignore,opts.verbose,opts.m_date_r,...
        opts.UseURLwrite,opts.flag,opts.err429,opts.print_to);
    SavesAllowed=tries(2)>0;%avoids a warning that logical(tries(2)) would trigger
    isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
end

%Order responses based on pattern length to match. There is no need to do this in the parser, since
%this is fast anyway, and response_lengths is needed in the loop below as well.
response_lengths=cellfun('length',response(:,2));
[response_lengths,order]=sort(response_lengths);
order=order(end:-1:1);%sort(__,'descend'); is not supported in ML6.5
response=response(order,:);
response_lengths=response_lengths(end:-1:1);

prefer_type=1;%prefer loading
success=false;%start loop
response_list_vector=[];%initialize response list
type_list=[];%initialize type list
connection_down_wait_factor=0;%initialize
while ~success && ...          %no successful download yet?
        sum(tries(1:2))>0 ... %any save or load tries left?
        && tries(3)>=0        %timeout limit reached?
    if tries(prefer_type)<=0%no tries left for the preferred type
        %switch 1 to 2 and 2 to 1
        prefer_type=3-prefer_type;
    end
    type=prefer_type;
    try %try download, if successful, exit loop
        if type==1              %load
            SaveAttempt=false;
            tries(type)=tries(type)-1;
            if UseURLwrite
                outfilename=urlwrite(...
                    ['http://web.archive.org/web/' ...
                    date_part flag '_/' url_part],...
                    filename);%#ok<URLWR>
                outfilename=check_filename(filename,outfilename);
            else
                outfilename=websave(filename,...
                    ['https://web.archive.org/web/' ...
                    date_part flag '_/' url_part],...
                    weboptions('Timeout',10));
            end
        elseif type==2          %save
            SaveAttempt=true;
            tries(type)=tries(type)-1;
            if UseURLwrite
                outfilename=urlwrite(...
                    ['http://web.archive.org/save/' url_part],...
                    filename); %#ok<URLWR>
                outfilename=check_filename(filename,outfilename);
            else
                outfilename=websave(filename,...
                    ['https://web.archive.org/save/' url_part],...
                    weboptions('Timeout',10));
            end
        end
        success=true;
        connection_down_wait_factor=0;
        if SavesAllowed && ...
                ~check_date(outfilename,date_part,m_date_r,SaveAttempt)
            %Incorrect date or live page loaded, so try saving.
            success=false;prefer_type=2;
        end
    catch
        %The catch ME syntax was introduced in R2007b. In prior releases, the ME was a struct
        %reachable with lasterror.
        ME=lasterror;%#ok<LERR>
        
        success=false;
        if ~isnetavl
            %if the connection is down, retry in intervals
            while ~isnetavl
                curr_time=datestr(now,'HH:MM:SS');
                if verbose>=1
                    warning(['Internet connection down, ',...
                        'retrying in %d seconds (@%s)'],...
                        2^connection_down_wait_factor,curr_time)
                end
                connection_down_wait_factor=connection_down_wait_factor+1;
                %Cap to a reasonable interval.
                if connection_down_wait_factor==7
                    connection_down_wait_factor=6;
                end
                pause(2^connection_down_wait_factor)
            end
            %Skip the rest of the error processing and retry without reducing points.
            continue
        end
        connection_down_wait_factor=0;
        ME_id=ME.identifier;
        ME_id=strrep(ME_id,':urlwrite:',':webservices:');
        if strcmp(ME_id,'MATLAB:webservices:Timeout')
            code=4080;
            tries(3)=tries(3)-1;
        else
            %raw_code=textscan(ME_id,...
            %    'MATLAB:webservices:HTTP%dStatusCodeError');
            raw_code=strrep(ME_id,'MATLAB:webservices:HTTP','');
            raw_code=strrep(raw_code,'StatusCodeError','');
            raw_code=str2double(raw_code);
            if isnan(raw_code)
                %textscan would have failed
                code=-1;
                if verbose>=2
                    if print_to.use_fprintf
                        if isOctave
                            fprintf(print_to.fid,'%s',ME.message);drawnow
                        else
                            warning(ME.message)
                        end
                    else
                        set(print_to.object,'String',ME.message)
                    end
                end
            else
                %Octave doesn't really returns a identifier for urlwrite, nor do very old releases
                %of Matlab.
                switch ME.message
                    case 'urlwrite: Couldn''t resolve host name'
                        code=404;
                    case ['urlwrite: Peer certificate cannot be ',...
                            'authenticated with given CA certificates']
                        %It's not really a 403, but the result in this context is similar.
                        code=403;
                    otherwise
                        code=raw_code;
                end
            end
        end
        if isempty(code)
            %Some other error occurred, set a code and rethrow as warning. As Octave does not
            %report an HTML error code, this will happen every error. To reduce command window
            %clutter, use disp instead of rethrowing.
            code=-1;
            if verbose>=2
                if print_to.use_fprintf
                    if isOctave
                        fprintf(print_to.fid,'%s',ME.message);drawnow
                    else
                        warning(ME.message)
                    end
                else
                    set(print_to.object,'String',ME.message)
                end
            end
        end
        
        if verbose>=3
            txt=sprintf('Error %d tries(%d,%d,%d) (download of %s)\n',...
                double(code),tries(1),tries(2),tries(3),filename);
            if print_to.use_fprintf
                fprintf(print_to.fid,'%s',txt);
            else
                set(print_to.object,'String',txt)
            end
            drawnow
        end
        if ~any(code==ignore)
            response_list_vector(end+1)=code; %#ok<AGROW>
            type_list(end+1)=type; %#ok<AGROW>
            for n_response_pattern=1:size(response,1)
                if length(response_list_vector)<...
                        response_lengths(n_response_pattern)
                    %Not enough failed attempts (yet) to match against the current pattern.
                    continue
                end
                last_part_of_response_list=response_list_vector(...
                    (end-response_lengths(n_response_pattern)+1):end);
                last_part_of_type_list=type_list(...
                    (end-response_lengths(n_response_pattern)+1):end);
                
                %Compare the last types to the type patterns.
                temp_type_pattern=response{n_response_pattern,1}(2:2:end);
                temp_type_pattern=...
                    strrep(temp_type_pattern,'x',num2str(type));
                type_fits=strcmp(temp_type_pattern,...
                    sprintf('%d',last_part_of_type_list));
                if isequal(...
                        response{n_response_pattern,2},...
                        last_part_of_response_list)...
                        && type_fits
                    %If the last part of the response list matches with the response pattern in the
                    %current element of 'response', set prefer_type to 1 for load, and to 2 for
                    %save.
                    switch response{n_response_pattern,3}
                        %otherwise will not occur: should be caught in the input parser
                        case 'load'
                            prefer_type=1;
                        case 'save'
                            prefer_type=2;
                        case 'exit'
                            %Cause a break in the while loop.
                            tries=[0 0 -1];
                        case 'pause_retry'
                            if ~err429.CountsAsTry
                                %Increment the counter, which has the effect of not counting this
                                %as a try.
                                tries(prefer_type)=tries(prefer_type)+1;
                            end
                            if verbose>=err429.PrintAtVerbosityLevel
                                N=10;
                                s='Waiting a while until the server won''t block us anymore';
                                if print_to.use_fprintf
                                    fprintf(print_to.fid,s);drawnow
                                end
                                for n=1:N
                                    pause(err429.TimeToWait/N)
                                    if print_to.use_fprintf
                                        fprintf(print_to.fid,'.');drawnow
                                    else
                                        s=[s '.']; %#ok<AGROW>
                                        set(print_to.object,s);drawnow
                                    end
                                end
                                if print_to.use_fprintf
                                    fprintf(print_to.fid,'\nContinuing\n');drawnow
                                end
                            else
                                pause(err429.TimeToWait)
                            end
                    end
                    break
                end
            end
        end
    end
end

if ~success || ...
        ( ~SavesAllowed && ...
        ~check_date(outfilename,date_part,m_date_r,SaveAttempt) )
    %If saving isn't allowed and the date doesn't match the date_part, or no successful download
    %was reached within the allowed tries, delete the output file (as it will be either the
    %incorrect date, or 0 bytes).
    if exist(filename,'file'),delete(filename);end
    outfilename=[];
end
if nargout==0
    clear('outfilename');
end
end
function date_correct=check_date(outfilename,date_part,m_date_r,SaveAttempt)
%Check if the date of the downloaded file matches the requested date.
%
%There are two strategies. Strategy 1 is guaranteed to be correct, but isn't always possible.
%Strategy 2 could give an incorrect answer, but is possible in more situations. In the case of
%non-web page files (like e.g. an image), both will fail. This will trigger a missing date error,
%for which you need to input a missing date response (m_date_r).
%
%Strategy 1:
%Rely on the html for the header to provide the date of the currently viewed capture.
%Strategy 2:
%Try a much less clean version: don't rely on the top bar, but look for links that indicate a link
%to the same date in the Wayback Machine. The most common occurring date will be compared with
%date_part.

if ~exist(outfilename,'file')
    date_correct=false;return
    %If the file doesn't exist (not even as a 0 byte file), evidently something went wrong, so
    %retrying or alerting the user is warranted.
end
%Loading an unsaved page may result in a capture of the live page (but no save in the WBM). If this
%happens the time in the file will be very close to the current time if this is the case. If the
%save was actually triggered this is valid, but if this is the result of a load attempt, it is
%unlikely this is correct, in which case it is best to trigger the response to an incorrect date:
%attempt an explicit save.
%Save the time here so any time taken up by file reading and processing doesn't bias the estimation
%of whether or not this is too recent.
if ~SaveAttempt
    currentTime=WBM_getUTC_local;
end

%Strategy 1:
%Rely on the html for the header to provide the date of the currently viewed capture.
StringToMatch='<input type="hidden" name="date" value="';
data=readfile(outfilename);
%ismember can result in a memory error in ML6.5
%ismembc only allows numeric, logical, or char inputs (and Octave lacks it)
%pos=find(ismember(data,'<td class="u" colspan="2">'));
pos=0;
while pos<=numel(data) && (pos==0 || ...
        ~strcmp(stringtrim(data{pos}),'<td class="u" colspan="2">'))
    pos=pos+1;
end
if numel(data)>=(pos+1)
    line=data{pos+1};
    idx=strfind(line,StringToMatch);
    idx=idx+length(StringToMatch)-1;
    date_correct=strcmp(line(idx+(1:length(date_part))),date_part);
    return
end
%Strategy 2:
%Try a much less clean version: don't rely on the top bar, but look for links that indicate a link
%to the same date in the Wayback Machine. The most common occurring date will be compared with
%date_part.
%already loaded: data=readfile(outfilename);
%data(:,2)={' '};data=data';
data=data(:)';data=cell2mat(data);
%data is now a single long string
idx=strfind(data,'/web/');
if numel(idx)==0
    if m_date_r==0     %ignore
        date_correct=true;
        return
    elseif m_date_r==1 %warning
        warning('HJW:WBM:MissingDateWarning',...
            'No date found in file, unable to check date, assuming it is correct.')
        date_correct=true;
        return
    elseif m_date_r==2 %error
        error('HJW:WBM:MissingDateError',...
            ['Could not find date. This can mean there is an ',...
            'error in the save. Try saving manually.'])
    end
end
datelist=cell(size(idx));
data=[data 'abcdefghijklmnopqrstuvwxyz'];%avoid error in the loop below
if exist('isstrprop','builtin')
    for n=1:length(idx)
        for m=1:14
            if ~isstrprop(data(idx(n)+4+m),'digit')
                break
            end
        end
        datelist{n}=data(idx(n)+4+(1:m));
    end
else
    for n=1:length(idx)
        for m=1:14
            if ~any(double(data(idx(n)+4+m))==(48:57))
                break
            end
        end
        datelist{n}=data(idx(n)+4+(1:m));
    end
end
[a,ignore_output,c]=unique(datelist);%#ok<ASGLU> ~
%In some future release, histc might not be supported anymore.
try
    [ignore_output,c2]=max(histc(c,1:max(c)));%#ok<HISTC,ASGLU>
catch
    [ignore_output,c2]=max(accumarray(c,1)); %#ok<ASGLU>
end
line=a{c2};
date_correct=strcmp(line((1:length(date_part))),date_part);

if ~SaveAttempt
    %Check if the time in the file is too close to the current time to be an actual loaded capture.
    %Setting this too high will result in too many save triggers, but setting it too low will lead
    %to captures being missed on slower systems/networks. 15 seconds seems a reasonable middle
    %ground.
    %One extreme situation to be aware of: it is possible for a save to be triggered, the request
    %arrives successfully and the page is saved, but the response from the server is wrong or
    %missing, triggering an HTTP error. This may then lead to a load attempt. Now we have the
    %situation where there is a save of only several seconds old, but the the SaveAttempt flag is
    %false. The time chosen here must be short enough to account for this situation.
    %Barring such extreme circumstances, page ages below a minute are suspect.
    
    if numel(line)<14%Something is wrong
        %Trigger missing date response. This shouldn't happen, so offer a gracefull exit.
        if m_date_r==0     %ignore
            date_correct=true;
            return
        elseif m_date_r==1 %warning
            warning('HJW:WBM:MissingDateWarning',...
                'No date found in file, unable to check date, assuming it is correct.')
            date_correct=true;
            return
        elseif m_date_r==2 %error
            error('HJW:WBM:MissingDateError',...
                ['Could not find date. This can mean there is an ',...
                'error in the save. Try saving manually.'])
        end
    end
    
    %convert the date found to a format that the ML6.5 datenum supports
    line={line(1:4),line(5:6),line(7:8),...  %date
        line(9:10),line(11:12),line(13:14)}; %time
    line=str2double(line);
    timediff=(currentTime-datenum(line))*24*60*60;
    if timediff<10%seconds
        date_correct=false;
    elseif timediff<60%seconds
        warning('HJW:WBM:LivePageStored',...
            ['The live page might have been saved instead of a capture.',char(10),...
            'Check on the WBM if a capture exists.']) %#ok<CHARTEN>
    end
end
end
function outfilename=check_filename(filename,outfilename)
%It can sometimes happen that the outfilename provided by urlwrite is incorrect. Therefore, we need
%to check if either the outfilename file exists, or the same file, but inside the current
%directory. It is unclear when this would happen, but it might be that this only happens when the
%filename provided only contains a name, and not a full or relative path.
outfilename2=[pwd filesep filename];
if ~strcmp(outfilename,outfilename2)
    if ~exist(outfilename,'file') && ...
            exist(outfilename2,'file')
        outfilename=outfilename2;
    end
end
end
function atomTime=getUTC(debug_test)
%Returns the UTC time. The value is in Matlab datenum format.
%
%example syntax:
% disp(datestr(getUTC))
%
% There are two methods implemented in this function:
% - An implementation that requires a C mex function.
%   This method requires write access to the current folder and a working C compiler.
%   (you may want to compile the mex function to the same folder you store this m-file)
% - An implementation using https://www.utctime.net/utc-timestamp. The NIST has a server that
%   returns the time, but it currently blocks API access.
%   This method requires internet access.
% 
%  _________________________________________________________________
% | Compatibility | Windows 10  | Ubuntu 20.04 LTS | MacOS Catalina |
% |---------------|-------------|------------------|----------------|
% | ML R2020a     |  works      |  not tested      |  not tested    |
% | ML R2015a     |  works      |  not tested      |  not tested    |
% | ML R2011a     |  partial #1 |  not tested      |  not tested    |
% | ML 6.5 (R13)  |  partial #1 |  not tested      |  not tested    |
% | Octave 5.2.0  |  works      |  works           |  not tested    |
% | Octave 4.4.1  |  works      |  not tested      |  works         |
% """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
% note #1: web method doesn't work
%
% Version: 1.0
% Date:    2020-05-20
% Author:  H.J. Wisselink
% Licence: CC by-nc-sa 4.0 ( creativecommons.org/licenses/by-nc-sa/4.0 )
% Email=  'h_j_wisselink*alumnus_utwente_nl';
% Real_email = regexprep(Email,{'*','_'},{'@','.'})

if nargin==0
    %normal flow: first try the C method, then the web
    UTC_epoch_seconds=getUTC_c;
    if isempty(UTC_epoch_seconds)
        UTC_epoch_seconds=getUTC_web;
        if isempty(UTC_epoch_seconds)
            error('HJW:getUTC:TimeReadFailed',...
                ['Both methods of retrieving the UTC timestamp failed.\nEnsure you ',...
                'have write access to the current folder and check your internet connection.'])
        end
    end
else
    %debug/test, will not throw an error on fail
    if debug_test==1
        UTC_epoch_seconds=getUTC_c;
    else
        UTC_epoch_seconds=getUTC_web;
    end
end
UTC_offset=UTC_epoch_seconds/(24*60*60);
atomTime=UTC_offset+datenum(1970,1,1);
end
function UTC_epoch_seconds=getUTC_c
%Use a C implementation, which requires write permission in the current directory.
%Should return an empty array instead of an error if it fails.

persistent utc_time_c
if isempty(utc_time_c)
    %prepare to write this to a file and compile
    utc_time_c={'#include "mex.h"'
        '#include "time.h"'
        ''
        '/* Abraham Cohn,  3/17/2005 */'
        '/* Philips Medical Systems */'
        ''
        'void mexFunction(int nlhs, mxArray *plhs[], int nrhs,'
        '                 const mxArray *prhs[])'
        '{'
        '  time_t utc;'
        '  '
        '  if (nlhs > 1) {'
        '    mexErrMsgTxt("Too many output arguments");'
        '  }'
        '  '
        '  /* Here is a nice ref: www.cplusplus.com/ref/ctime/time.html */'
        '  time(&utc);'
        '  /* mexPrintf("UTC time in local zone: %s",ctime(&utc)); */'
        '  /* mexPrintf("UTC time in GMT: %s",asctime(gmtime(&utc))); */'
        '  '
        '  /* Create matrix for the return argument. */'
        '  plhs[0] = mxCreateDoubleScalar((double)utc);'
        '   '
        '}'};
    %the original had mxCreateScalarDouble
end

try
    UTC_epoch_seconds=utc_time;
catch
    %build missing C file
    if exist(['utc_time.' mexext],'file')
        ME=lasterror; %#ok<LERR>
        rethrow(ME);
    end
    if ~exist('utc_time.c','file')
        fid=fopen('utc_time.c','w');
        for line=1:numel(utc_time_c)
            fprintf(fid,'%s\n',utc_time_c{line});
        end
        fclose(fid);
    end
    mex('utc_time.c');
    delete('utc_time.c')%cleanup
    if exist('utc_time.o','file'),delete('utc_time.o'),end%cleanup on Octave
    if exist(['utc_time.' mexext],'file')
        UTC_epoch_seconds=utc_time;
    else
        %the compiling of the mex function failed
        UTC_epoch_seconds=[];
    end
end
end
function UTC_epoch_seconds=getUTC_web
%read the timestamp from a web server
%this fails for ML6.5 for some reason

%skip this function if there is no internet connection (3 timeouts will take a lot of time)
if ~isnetavl,UTC_epoch_seconds=[];return,end
for tries=1:3
    try
        if exist('webread','file')
            data=webread('http://www.utctime.net/utc-timestamp');
        else
            data=urlread('http://www.utctime.net/utc-timestamp'); %#ok<URLRD>
        end
        break
    catch
    end
end
try
    data(data==' ')='';
    pat='vartimestamp=';
    ind1=strfind(data,pat)+numel(pat);
    ind2=strfind(data,';')-1;
    ind2(ind2<ind1)=[];
    UTC_epoch_seconds=str2double(data(ind1:ind2(1)));
catch
    UTC_epoch_seconds=[];
end
end
function tf=ifversion(test,Rxxxxab,Oct_flag,Oct_test,Oct_ver)
%Determine if the current version satisfies a version restriction
%
% To keep the function fast, no input checking is done. This function returns a NaN if a release
% name is used that is not in the dictionary.
%
% Syntax:
% tf=ifversion(test,Rxxxxab)
% tf=ifversion(test,Rxxxxab,'Octave',test_for_Octave,v_Octave)
%
% Output:
% tf       - If the current version satisfies the test this returns true.
%            This works similar to verLessThan.
%
% Inputs:
% Rxxxxab - Char array containing a release description (e.g. 'R13', 'R14SP2' or 'R2019a') or the
%           numeric version.
% test    - Char array containing a logical test. The interpretation of this is equivalent to
%           eval([current test Rxxxxab]). For examples, see below.
%
% Examples:
% ifversion('>=','R2009a') returns true when run on R2009a or later
% ifversion('<','R2016a') returns true when run on R2015b or older
% ifversion('==','R2018a') returns true only when run on R2018a
% ifversion('==',9.8) returns true only when run on R2020a
% ifversion('<',0,'Octave','>',0) returns true only on Octave
%
% The conversion is based on a manual list and therefore needs to be updated manually, so it might
% not be complete. Although it should be possible to load the list from Wikipedia, this is not
% implemented.
%
%  _________________________________________________________________
% | Compatibility | Windows 10  | Ubuntu 20.04 LTS | MacOS Catalina |
% |---------------|-------------|------------------|----------------|
% | ML R2020a     |  works      |  not tested      |  not tested    |
% | ML R2015b     |  works      |  not tested      |  not tested    |
% | ML R2011a     |  works      |  not tested      |  not tested    |
% | ML 6.5 (R13)  |  works      |  not tested      |  not tested    |
% | Octave 5.2.0  |  works      |  works           |  not tested    |
% | Octave 4.4.1  |  works      |  not tested      |  works         |
% """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
%
% Version: 1.0.2
% Date:    2020-05-20
% Author:  H.J. Wisselink
% Licence: CC by-nc-sa 4.0 ( creativecommons.org/licenses/by-nc-sa/4.0 )
% Email=  'h_j_wisselink*alumnus_utwente_nl';
% Real_email = regexprep(Email,{'*','_'},{'@','.'})

%The decimal of the version numbers are padded with a 0 to make sure v7.10 is larger than v7.9.
%This does mean that any numeric version input needs to be adapted. multiply by 100 and round to
%remove the potential for float rounding errors.
%Store in persistent for fast recall (don't use getpref, as that is slower than generating the
%variables and makes updating this function harder).
persistent  v_num v_dict octave
if isempty(v_num)
    %test if Octave is used instead of Matlab
    octave=exist('OCTAVE_VERSION', 'builtin');
    
    %get current version number
    v_num=version;
    ii=strfind(v_num,'.');
    if numel(ii)~=1,v_num(ii(2):end)='';ii=ii(1);end
    v_num=[str2double(v_num(1:(ii-1))) str2double(v_num((ii+1):end))];
    v_num=v_num(1)+v_num(2)/100;
    v_num=round(100*v_num);%remove float rounding errors
    
    %get dictionary to use for ismember
    v_dict={...
        'R13' 605;'R13SP1' 605;'R13SP2' 605;'R14' 700;'R14SP1' 700;'R14SP2' 700;'R14SP3' 701;...
        'R2006a' 702;'R2006b' 703;'R2007a' 704;'R2007b' 705;'R2008a' 706;'R2008b' 707;...
        'R2009a' 708;'R2009b' 709;'R2010a' 710;'R2010b' 711;'R2011a' 712;'R2011b' 713;...
        'R2012a' 714;'R2012b' 800;'R2013a' 801;'R2013b' 802;'R2014a' 803;'R2014b' 804;...
        'R2015a' 805;'R2015b' 806;'R2016a' 900;'R2016b' 901;'R2017a' 902;'R2017b' 903;...
        'R2018a' 904;'R2018b' 905;'R2019a' 906;'R2019b' 907;'R2020a' 908};
end

if octave
    if nargin==2
        warning('HJW:ifversion:NoOctaveTest',...
            ['No version test for Octave was provided.',char(10),...
            'This function might return an unexpected outcome.']) %#ok<CHARTEN>
        %Use the same test as for Matlab, which will probably fail.
        L=ismember(v_dict(:,1),Rxxxxab);
        if sum(L)~=1
            warning('HJW:ifversion:NotInDict',...
                'The requested version is not in the hard-coded list.')
            tf=NaN;return
        else
            v=v_dict{L,2};
        end
    elseif nargin==4
        %undocumented shorthand syntax: skip the 'Octave' argument
        [test,v]=deal(Oct_flag,Oct_test);
        %convert 4.1 to 401
        v=0.1*v+0.9*fix(v);v=round(100*v);
    else
        [test,v]=deal(Oct_test,Oct_ver);
        %convert 4.1 to 401
        v=0.1*v+0.9*fix(v);v=round(100*v);
    end
else
    %convert R notation to numeric and convert 9.1 to 901
    if isnumeric(Rxxxxab)
        v=0.1*Rxxxxab+0.9*fix(Rxxxxab);v=round(100*v);
    else
        L=ismember(v_dict(:,1),Rxxxxab);
        if sum(L)~=1
            warning('HJW:ifversion:NotInDict',...
                'The requested version is not in the hard-coded list.')
            tf=NaN;return
        else
            v=v_dict{L,2};
        end
    end
end
switch test
    case '=='
        tf= v_num == v;
    case '<'
        tf= v_num <  v;
    case '<='
        tf= v_num <= v;
    case '>'
        tf= v_num >  v;
    case '>='
        tf= v_num >= v;
end
end
function [connected,timing]=isnetavl
% Ping to one of Google's DNSes.
% Optional second output is the ping time (0 if not connected).
%
% Includes a fallback to HTML if usage of ping is not allowed. This increases the measured ping.
%
%  _________________________________________________________________
% | Compatibility | Windows 10  | Ubuntu 20.04 LTS | MacOS Catalina |
% |---------------|-------------|------------------|----------------|
% | ML R2020a     |  works      |  not tested      |  not tested    |
% | ML R2015b     |  works      |  not tested      |  not tested    |
% | ML R2011a     |  works      |  not tested      |  not tested    |
% | ML 6.5 (R13)  |  works      |  not tested      |  not tested    |
% | Octave 5.2.0  |  works      |  works           |  not tested    |
% | Octave 4.4.1  |  works      |  not tested      |  works         |
% """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
%
% Version: 1.2.2
% Date:    2020-06-28
% Author:  H.J. Wisselink
% Licence: CC by-nc-sa 4.0 ( http://creativecommons.org/licenses/by-nc-sa/4.0 )
% Email=  'h_j_wisselink*alumnus_utwente_nl';
% Real_email = regexprep(Email,{'*','_'},{'@','.'})

tf=isnetavl__ICMP_is_blocked;
if isempty(tf)
    %Unable to determine if ping is allowed, the connection must be down
    connected=0;
    timing=0;
else
    if tf
        %ping not allowed
        %(the timing is not reliable)
        [connected,timing]=isnetavl___ping_via_html;
    else
        %ping allowed
        [connected,timing]=isnetavl___ping_via_system;
    end
end
end
function [connected,timing]=isnetavl___ping_via_html
%Ping is blocked by some organizations. As an alternative, the google.com page can be loaded as a
%normal HTML, which should work as well, although it is slower. This also means the ping timing is
%no longer reliable.
try
    then=now;
    if exist('webread','file')
        str=webread('http://google.com'); %#ok<NASGU>
    else
        str=urlread('http://google.com'); %#ok<NASGU,URLRD>
    end
    connected=1;
    timing=(now-then)*24*3600*1000;
catch
    connected=0;
    timing=0;
end
end
function [connected,timing]=isnetavl___ping_via_system
if ispc
    try
        %                                   8.8.4.4 will also work
        [ignore_output,b]=system('ping -n 1 8.8.8.8');%#ok<ASGLU> ~
        stats=b(strfind(b,' = ')+3);
        stats=stats(1:3);%[sent received lost]
        if ~strcmp(stats,'110')
            error('trigger error')
        else
            %This branch will error for 'destination host unreachable'
            connected=1;
            %This assumes there is only one place with '=[digits]ms' in the response, but this code
            %is not language-specific.
            [ind1,ind2]=regexp(b,' [0-9]+ms');
            timing=b((ind1(1)+1):(ind2(1)-2));
            timing=str2double(timing);
        end
    catch
        connected=0;
        timing=0;
    end
elseif isunix
    try
        %                                   8.8.4.4 will also work
        [ignore_output,b]=system('ping -c 1 8.8.8.8');%#ok<ASGLU> ~
        ind=regexp(b,', [01] ');
        if b(ind+2)~='1'
            %This branch includes 'destination host unreachable' errors
            error('trigger error')
        else
            connected=1;
            %This assumes the first place with '=[digits] ms' in the response contains the ping
            %timing. This code is not language-specific.
            [ind1,ind2]=regexp(b,'=[0-9.]+ ms');
            timing=b((ind1(1)+1):(ind2(1)-2));
            timing=str2double(timing);
        end
    catch
        connected=0;
        timing=0;
    end
else
    error('How did you even get Matlab to work?')
end
end
function [tf,connected,timing]=isnetavl__ICMP_is_blocked
%Check if ICMP 0/8/11 is blocked
%
%tf is empty if both methods fail

persistent output
if ~isempty(output)
    tf=output;return
end

%First check if ping works
[connected,timing]=isnetavl___ping_via_system;
if connected
    %Ping worked and there is an internet connection
    output=false;
    tf=false;
    return
end

%There are two options: no internet connection, or ping is blocked
[connected,timing]=isnetavl___ping_via_html;
if connected
    %There is an internet connection, therefore ping must be blocked
    output=true;
    tf=true;
    return
end

%Both methods failed, internet is down. Leave the value of tf (and the persistent variable) set to
%empty so it is tried next time.
tf=[];
end
function data=readfile(filename)
%Read a UTF8 or ANSI (US-ASCII) file
%
% Syntax:
%    data=readfile(filename)
%    filename: char array with either relative or absolute path, or a URL
%    data: n-by-1 cell (1 cell per line in the file, even empty lines)
%
% This function is aimed at providing a reliable method of reading a file. The backbone of this
% function is the fileread function. Further processing is done to attempt to detect if the file is
% UTF8 or not, apply the transcoding and returning the file as an n-by-1 cell array for files with
% n lines.
%
% The test for being UTF8 can fail. For files with chars in the 128:255 range, the test will often
% determine the encoding correctly, but it might fail. Online files are much more limited than
% offline files. To avoid this the files are downloaded to tempdir() and deleted after reading. 
%
% In Octave there is poor to no support for chars above 255. This has to do with the way Octave
% runs: it stores chars in a single byte. This limits what Octave can do regardless of OS. There
% are plans to extent the support, but this appears to be very far down the priority list, since it
% requires a lot of explicit rewriting. Even the current support for 128-255 chars seems to be 'by
% accident'. (Note that this paragraph was true in early 2020, so a big update to Octave may have
% added support by now. Although, don't hold your breath.)
%
%  _______________________________________________________________________
% | Compatibility | Windows 10  | Ubuntu 20.04 LTS | MacOS 10.15 Catalina |
% |---------------|-------------|------------------|----------------------|
% | ML R2020a     |  works      |  not tested      |  not tested          |
% | ML R2018a     |  works      |  partial #3      |  not tested          |
% | ML R2015a     |  works      |  partial #3      |  not tested          |
% | ML R2011a     |  works      |  partial #3      |  not tested          |
% | ML 6.5 (R13)  |  partial #2 |  not tested      |  not tested          |
% | Octave 5.2.0  |  partial #1 |  partial #1      |  not tested          |
% | Octave 4.4.1  |  partial #1 |  not tested      |  partial #1          |
% """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
% note #1: no support for char>255 (which are likely converted to 0)
% note #2: - no support for char>255 ANSI (unpredictable output)
%          - online (without download): could fail for files that aren't ANSI<256
% note #3: ANSI>127 chars are converted to 65533
%
% Version: 2.0.1
% Date:    2020-07-03
% Author:  H.J. Wisselink
% Licence: CC by-nc-sa 4.0 ( creativecommons.org/licenses/by-nc-sa/4.0 )
% Email=  'h_j_wisselink*alumnus_utwente_nl';
% Real_email = regexprep(Email,{'*','_'},{'@','.'})

% Tested with 3 files with the following chars:
% list_of_chars_file1=[...
%     0032:0035 0037 0039:0042 0044:0059 0061 0063 0065:0091 0093 0096:0122 0160 0171 0173 0183 ...
%     0187:0189 0191:0193 0196 0200:0203 0205 0207 0209 0211 0212 0218 0224:0226 0228 0230:0235 ...
%     0237:0239 0241:0244 0246 0249:0253 8211 8212 8216:8218 8220:8222 8226 8230];
% list_of_chars_file2=[32:126 160:255 32 32 32];
% list_of_chars_file3=[...
%     0032:0126 0161:0163 0165 0167:0172 0174:0187 0191:0214 0216:0275 0278:0289 0292 0293 0295 ...
%     0298 0299 0304 0305 0308 0309 0313 0314 0317 0318 0321:0324 0327 0328 0336:0341 0344:0357 ...
%     0362:0369 0376:0382 0913:0929 0931:0974 0977 0984:0989 0991:0993 8211 8212 8216:8222 8224 ...
%     8225 8226 8230 8240 8249 8250 8260 8353 8356 8358 8361 8363 8364 8370 8482];

persistent CPwin2UTF8 origin target legacy isOctave runtimename
if isempty(CPwin2UTF8)
    CPwin2UTF8=[338 140;339 156;352 138;353 154;376 159;381 142;382 158;402 131;710 136;732 152;...
        8211 150;8212 151;8216 145;8217 146;8218 130;8220 147;8221 148;8222 132;8224 134;...
        8225 135;8226 149;8230 133;8240 137;8249 139;8250 155;8364 128;8482 153];
    
    isOctave=exist('OCTAVE_VERSION', 'builtin');
    if isOctave
        runtimename='Octave';
    else
        runtimename='Matlab';
        %convert to char here to prevent range errors in Octave
        origin=char(CPwin2UTF8(:,1));
        target=char(CPwin2UTF8(:,2));
    end
    %The regexp split option was introduced in R2007b.
    legacy.split = ifversion('<','R2007b','Octave','<',4);
    %Test if webread() is available
    legacy.UseURLread=isempty(which('webwrite'));
    %Change this line when Octave does support https
    legacy.allows_https=ifversion('>',0,'Octave','<',0);
end
if ... %enumerate all possible incorrect inputs
        nargin~=1 ...                                              %must have 1 input
        || ~( isa(filename,'char') || isa(filename,'string') ) ... %must be either char or string
        || ( isa(filename,'string') && numel(filename)~=1 ) ...    %if string, must be scalar
        || ( isa(filename,'char')   && numel(filename)==0 )        %if char, must be non-empty
    error('HJW:readfile:IncorrectInput',...
        'The file name must be a non-empty char or a scalar string.')
end
if isa(filename,'string'),filename=char(filename);end
if numel(filename)>=8 && strcmp(filename(1:7),'http://') || strcmp(filename(1:8),'https://')
    isURL=true;
    if ~legacy.allows_https && strcmp(filename(1:8),'https://')
        warning('HJW:readfile:httpsNotSupported',...
            ['This implementation of urlread probably doesn''t allow https requests.',char(10),...
            'The next lines of code will probably result in an error.']) %#ok<CHARTEN>
    end
    str=readfile_URL_to_str(filename,legacy.UseURLread);
    if isa(str,'cell') %file was read from temporary downloaded version
        data=str;return
    end
else
    isURL=false;
end
if ~isOctave
    if ~isURL
        try
            str=fileread(filename);
        catch
            error('HJW:readfile:ReadFail',['%s could not read the file %s.\n',...
                'The file doesn''t exist or is not readable.'],...
                runtimename,filename)
        end
    end
    if ispc
        str_original=str;%make a backup
        %Convert from the Windows-1252 codepage (the default on a Windows machine) to UTF8
        try
            [a,b]=ismember(str,origin);
            str(a)=target(b(a));
        catch
            %in case of an ismember memory error on ML6.5
            for n=1:numel(origin)
                str=strrep(str,origin(n),target(n));
            end
        end
        try
            if exist('native2unicode','builtin')
                %Probably introduced in R14 (v7.0)
                ThrowErrorIfNotUTF8file(str)
                str=native2unicode(uint8(str),'UTF8');
                str=char(str);
            else
                str=UTF8_to_str(str);
            end
        catch
            %ML6.5 doesn't support the "catch ME" syntax
            ME=lasterror;%#ok<LERR>
            if strcmp(ME.identifier,'HJW:UTF8_to_str:notUTF8')
                %Apparently it is not a UTF8 file, as the converter failed, so undo the
                %Windows-1252 codepage re-mapping.
                str=str_original;
            else
                rethrow(ME)
            end
        end
    end
    if numel(str)>=1 && double(str(1))==65279
        %remove UTF BOM (U+FEFF) from text
        str(1)='';
    end
    str(str==13)='';
    if legacy.split
        s1=strfind(str,char(10));s2=s1;%#ok<CHARTEN>
        data=cell(numel(s1)+1,1);
        start_index=[s1 numel(str)+1];
        stop_index=[0 s2];
        for n=1:numel(start_index)
            data{n}=str((stop_index(n)+1):(start_index(n)-1));
        end
    else
        data=regexp(str,char(10),'split')'; %#ok<CHARTEN>
    end
else
    if ~isURL
        data = cell(0);
        fid = fopen (filename, 'r');
        if fid<0
            error('HJW:readfile:ReadFail',['%s could not read the file %s.\n',...
                'The file doesn''t exist or is not readable.'],...
                runtimename,filename)
        end
        i=0;
        while i==0 || ischar(data{i})
            i=i+1;
            data{i,1} = fgetl (fid);
        end
        fclose (fid);
        data = data(1:end-1);  % No EOL
    else
        %online file was already read to str, now convert str to cell array
        if legacy.split
            s1=strfind(str,char(10));s2=s1;%#ok<CHARTEN>
            data=cell(numel(s1)+1,1);
            start_index=[s1 numel(str)+1];
            stop_index=[0 s2];
            for n=1:numel(start_index)
                data{n,1}=str((stop_index(n)+1):(start_index(n)-1));
            end
        else
            data=regexp(str,char(10),'split')'; %#ok<CHARTEN>
        end
    end
    try
        data_original=data;
        for n=1:numel(data)
            %Use a global internally to keep track of chars>255 and reset that state for n==1.
            [data{n},pref]=UTF8_to_str(data{n},1,n==1);
        end
        if pref.state
            warning(pref.ME.identifier,pref.ME.message)
            %an error could be thrown like this:
            % error(pref.ME)
        end
    catch ME
        if strcmp(ME.identifier,'HJW:UTF8_to_str:notUTF8')
            %Apparently it is not a UTF8 file, as the converter failed, so undo the Windows-1252
            %codepage re-mapping.
            data=data_original;
        else
            rethrow(ME)
        end
    end
end
end
function str=readfile_URL_to_str(url,UseURLread)
%Read the contents of a file to a char array.
%
%Attempt to download to the temp folder, read the file, then delete it.
%If that fails, read to a char array with urlread/webread.
try
    %Generate a random file name in the temp folder
    fn=tmpname('readfile_from_URL_tmp_','.txt');
    try
        RevertToUrlread=false;%in case the saving+reading fails
        
        %Try to download
        if UseURLread,fn=urlwrite(url,fn);else,fn=websave(fn,url);end %#ok<URLWR>
        
        %Try to read
        str=readfile(fn);
    catch
        RevertToUrlread=true;
    end
    
    %Delete the temp file
    try if exist(fn,'file'),delete(fn);end,catch,end
    
    if RevertToUrlread,error('revert to urlread'),end
catch
    %Read to a char array and let these functions throw an error in case of HTML errors and/or
    %missing connectivity.
    if UseURLread,str=urlread(url);else,str=webread(url);end %#ok<URLRD>
end
end
function str=stringtrim(str)
%Extend strtrim to remove double spaces as well.
if exist('strtrim','builtin')
    str=strtrim(str);
else
    %ML6.5
    if numel(str)==0,return,end
    L=isspace(str);
    if L(end)
        %last is whitespace, trim end
        idx=find(~L);
        if isempty(idx)
            %only whitespace
            str='';return
        end
        str((idx(end)+1):end)='';
    end
    if isempty(str),return,end
    if L(1)
        %first is whitespace, trim start
        idx=find(~L);
        str(1:(idx(1)-1))='';
    end
end
removed_double_spaces=inf;
while removed_double_spaces~=0
    length1=length(str);
    str=strrep(str,'  ',' ');
    length2=length(str);
    removed_double_spaces=length1-length2;
end
end
function [passed,item]=test_if_scalar_logical(item)
%test if the input is a scalar logical or convertable to it
%(use isLogical to trigger an input error, use val as the parsed input)
%
% Allowed values:
%- true or false
%- 1 or 0
%- 'on' or 'off'
persistent states
if isempty(states)
    states={true,false;...
        1,0;...
        'on','off'};
    try
        states(end+1,:)=eval('{"on","off"}');
    catch
    end
end
passed=true;
try
    for n=1:size(states,1)
        for m=1:2
            if isequal(item,states{n,m})
                item=states{1,m};return
            end
        end
    end
    if isa(item,'matlab.lang.OnOffSwitchState')
        item=logical(item);return
    end
catch
end
passed=false;
end
function ThrowErrorIfNotUTF8file(str)
%Test if the char input is likely to be UTF8
%
%This uses the same tests as the UTF8_to_str function.
%Octave has poor support for chars >255, but that is ignored in this function.

if any(str>255)
    error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
end
str=char(str);

%Matlab doesn't support 4-byte chars in the same way as 1-3 byte chars. So we ignore them and start
%with the 3-byte chars (starting with 1110xxxx).
val_byte3=bin2dec('11100000');
byte3=str>=val_byte3;
if any(byte3)
    byte3=find(byte3)';
    try
        byte3=str([byte3 (byte3+1) (byte3+2)]);
    catch
        if numel(str)<(max(byte3)+2)
            error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
        else
            rethrow(lasterror) %#ok<LERR> no "catch ME" syntax in ML6.5
        end
    end
    byte3=unique(byte3,'rows');
    S2=mat2cell(char(byte3),ones(size(byte3,1),1),3);
    for n=1:numel(S2)
        bin=dec2bin(double(S2{n}))';
        %To view the binary data, you can use this: bin=bin(:)';
        %Remove binary header:
        %1110xxxx10xxxxxx10xxxxxx
        %    xxxx  xxxxxx  xxxxxx
        if ~strcmp('11101010',bin([1 2 3 4 8+1 8+2 16+1 16+2]))
            %Check if the byte headers match the UTF8 standard
            error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
        end
    end
end
%Next, the 2-byte chars (starting with 110xxxxx)
val_byte2=bin2dec('11000000');
byte2=str>=val_byte2 & str<val_byte3;%Exclude the already checked chars
if any(byte2)
    byte2=find(byte2)';
    try
        byte2=str([byte2 (byte2+1)]);
    catch
        if numel(str)<(max(byte2)+1)
            error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
        else
            rethrow(lasterror) %#ok<LERR> no "catch ME" syntax in ML6.5
        end
    end
    byte2=unique(byte2,'rows');
    S2=mat2cell(byte2,ones(size(byte2,1),1),2);
    for n=1:numel(S2)
        bin=dec2bin(double(S2{n}))';
        %To view the binary data, you can use this: bin=bin(:)';
        %Remove binary header:
        %110xxxxx10xxxxxx
        %   xxxxx  xxxxxx
        if ~strcmp('11010',bin([1 2 3 8+1 8+2]))
            %Check if the byte headers match the UTF8 standard
            error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
        end
    end
end
end
function str=tmpname(StartFilenameWith,ext)
%inject a string in the file name part returned by the tempname function
if nargin<1,StartFilenameWith='';end
if ~isempty(StartFilenameWith),StartFilenameWith=[StartFilenameWith '_'];end
if nargin<2,ext='';else,if ~strcmp(ext(1),'.'),ext=['.' ext];end,end
str=tempname;
[p,f]=fileparts(str);
str=fullfile(p,[StartFilenameWith f ext]);
end
function [unicode,flag]=UTF8_to_str(UTF8,behavior__char_geq256,ResetOutputFlag)
%Convert UTF8 to actual char values
%
%This function replaces the syntax str=native2unicode(uint8(UTF8),'UTF8');
%This function throws an error if the input is not possibly UTF8.
%
%To deal with the limited char support in Octave, you can set a preference for what should happen,
%(use the UTF8_to_str___behavior__char_geq256 preference in the HJW group). You can set it to 5
%levels:
%0 (ignore), 1 (reported in global), 2 (reported in setpref), 3 (throw warning), 4 (throw error)
%
%With the level set to 1, you can use the global variable HJW___UTF8_to_str___error_was_triggered
%to see if there is a char>255. If that was the case, the state field will be set to true. This
%variable also contains an ME struct.
%With the level set to 2 you can retrieve a similar variable with
%getpref('HJW','UTF8_to_str___error_was_triggered'). These will not overwrite eachother.
%
%This struct is also returned as the second output variable.

% %test case:
% c=[char(hex2dec('0024')) char(hex2dec('00A2')) char(hex2dec('20AC'))];
% c=[c c+1 c];
% UTF8=unicode2native(c,'UTF8');
% native=UTF8_to_str(UTF8);
% disp(c)
% disp(native)

%Set the default behavior for chars>255 (only relevant on Octave)
default_behavior__char_geq256=1;
%    0: ignore
%    1: report in global
%    2: report in pref
%    3: throw warning
%    4: throw error

if any(UTF8>255)
    error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
end
UTF8=char(UTF8);

persistent isOctave pref
global HJW___UTF8_to_str___error_was_triggered%globals generally are a bad idea, so use a long name
if isempty(isOctave)
    %initialize persistent variable (pref will be initialized later)
    isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
end
if isOctave
    if nargin<2
        behavior__char_geq256=getpref('HJW',...%toolbox name or author initials as group ID
            ['UTF8_to_str___',...%function group
            'behavior__char_geq256'],...%preference name
            default_behavior__char_geq256);
    end
    if nargin<3
        ResetOutputFlag=true;
    end
    if behavior__char_geq256==1
        %Overwrite persistent variable with the contents of the global. This ensures changes made
        %to this variable outside this function are not overwriten.
        pref=HJW___UTF8_to_str___error_was_triggered;
    end
    
    ID='HJW:UTF8_to_str:charnosupport';
    msg='Chars greater than 255 are not supported on Octave.';
    if ResetOutputFlag || isempty(pref)
        pref=struct(...
            'state',false,...
            'ME',struct('message',msg,'identifier',ID),...
            'default',default_behavior__char_geq256);
        if behavior__char_geq256==1
            HJW___UTF8_to_str___error_was_triggered=pref;
        elseif behavior__char_geq256==2
            %Don't bother overwriting this if it is not going to be used. Calling prefs takes a
            %relatively long time, so it should be avoided when not necessary.
            setpref('HJW',...%toolbox name or author initials as group ID
                ['UTF8_to_str___',...%function group
                'error_was_triggered'],...%preference name
                pref);
        end
    end
end

%Matlab doesn't support 4-byte chars in the same way as 1-3 byte chars. So we ignore them and start
%with the 3-byte chars (starting with 1110xxxx). The reason for this difference is that a 3-byte
%char will fit in a uint16, which is how Matlab stores chars internally.
val=bin2dec('11100000');
byte3=UTF8>=val;
if any(byte3)
    byte3=find(byte3)';
    try
        byte3=UTF8([byte3 (byte3+1) (byte3+2)]);
    catch
        if numel(UTF8)<(max(byte3)+2)
            error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
        else
            rethrow(lasterror) %#ok<LERR> no "catch ME" syntax in ML6.5
        end
    end
    byte3=unique(byte3,'rows');
    S2=mat2cell(char(byte3),ones(size(byte3,1),1),3);
    for n=1:numel(S2)
        bin=dec2bin(double(S2{n}))';
        %To view the binary data, you can use this: bin=bin(:)';
        %Remove binary header:
        %1110xxxx10xxxxxx10xxxxxx
        %    xxxx  xxxxxx  xxxxxx
        if ~strcmp('11101010',bin([1 2 3 4 8+1 8+2 16+1 16+2]))
            %Check if the byte headers match the UTF8 standard
            error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
        end
        bin([1 2 3 4 8+1 8+2 16+1 16+2])='';
        if ~isOctave
            S3=char(bin2dec(bin));
        else
            val=bin2dec(bin');%Octave needs an extra transpose
            if behavior__char_geq256>0 && val>255
                %See explanation above for the reason behind this code.
                pref.state=true;
                if behavior__char_geq256==1
                    HJW___UTF8_to_str___error_was_triggered.state=true;
                elseif behavior__char_geq256==2 && ~(pref.state) %(no need to set if already true)
                    setpref('HJW',...%toolbox name or author initials as group ID
                        ['UTF8_to_str___',...%function group
                        'error_was_triggered'],...%preference name
                        pref)
                elseif behavior__char_geq256==3
                    warning(ID,msg)
                else
                    error(ID,msg)
                end
            end
            %Prevent range error warnings. Any invalid char value has already been handled above.
            w=warning('off','all');
            S3=char(val);
            warning(w)
        end
        %Perform replacement
        UTF8=strrep(UTF8,S2{n},S3);
    end
end
%Next, the 2-byte chars (starting with 110xxxxx)
val=bin2dec('11000000');
byte2=UTF8>=val & UTF8<256;%Exclude the already converted chars
if any(byte2)
    byte2=find(byte2)';
    try
        byte2=UTF8([byte2 (byte2+1)]);
    catch
        if numel(UTF8)<(max(byte2)+1)
            error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
        else
            rethrow(lasterror) %#ok<LERR> no "catch ME" syntax in ML6.5
        end
    end
    byte2=unique(byte2,'rows');
    S2=mat2cell(byte2,ones(size(byte2,1),1),2);
    for n=1:numel(S2)
        bin=dec2bin(double(S2{n}))';
        %To view the binary data, you can use this: bin=bin(:)';
        %Remove binary header:
        %110xxxxx10xxxxxx
        %   xxxxx  xxxxxx
        if ~strcmp('11010',bin([1 2 3 8+1 8+2]))
            %Check if the byte headers match the UTF8 standard
            error('HJW:UTF8_to_str:notUTF8','Input is not UTF8')
        end
        bin([1 2 3 8+1 8+2])='';
        if ~isOctave
            S3=char(bin2dec(bin));
        else
            val=bin2dec(bin');%Octave needs an extra transpose
            if behavior__char_geq256>0 && val>255
                pref.state=true;
                if behavior__char_geq256==1
                    HJW___UTF8_to_str___error_was_triggered.state=true;
                elseif behavior__char_geq256==2 && ~(pref.state) %(no need to set if already true)
                    setpref('HJW',...%toolbox name or author initials as group ID
                        ['UTF8_to_str___',...%function group
                        'error_was_triggered'],...%preference name
                        pref)
                elseif behavior__char_geq256==3
                    warning(ID,msg)
                else
                    error(ID,msg)
                end
            end
            %Prevent range error warnings. Any invalid char value has already been handled above.
            w=warning('off','all');
            S3=char(val);
            warning(w)
        end
        %Perform replacement
        UTF8=strrep(UTF8,S2{n},S3);
    end
end
unicode=UTF8;
flag=pref;
end
function atomTime=WBM_getUTC_local
%prefer web instead of c
atomTime=getUTC(2);
if isempty(atomTime)
    atomTime=getUTC(1);
    if isempty(atomTime)
        atomTime=0;%will trigger an error
    end
end
end
function [success,options,ME]=WBM_parse_inputs(filename,url,varargin)
%Parse the inputs of the WBM function
% It returns a success flag, the parsed options, and an ME struct.
% As input, the options should either be entered as a struct or as Name,Value pairs. Missing fields
% are filled from the default.

%pre-assign outputs
success=false;
options=struct;
ME=struct('identifier','','message','');

%test the required inputs
if ~ischar(filename) || numel(filename)==0
    ME.message='The first input (filename) is not char and/or empty.';
    ME.identifier='HJW:WBM:incorrect_input_filename';
    return
end
if ~ischar(url) || numel(url)==0
    ME.message='The second input (url) is not char and/or empty.';
    ME.identifier='HJW:WBM:incorrect_input_url';
    return
end

persistent default IsFirstRun
default__m_date_r__changed=false;
if isempty(default)
    %set defaults for options
    default.date_part='2';%load a random date (generally the last)
    default.tries=[5 4 4];%[loads saves timeouts] allowed
    default.response={...
        'tx',404,'load';...%a 404 may also occur after a successful save
        'txtx',[404 404],'save';...
        'tx',403,'save';...
        't2t2',[403 403],'exit';...%the page likely doesn't support the WBM
        'tx',429,'pause_retry'...%server overloaded, wait a while and retry
        };
    default.ignore=4080;
    default.verbose=3;
    default.m_date_r=1;%warning
    default.flag='*';
    default.UseLocalTime=false;
    %websave was introduced in R2014b (v8.4) and isn't built into Octave 4.2.1. As an undocumented
    %feature, this can be forced to true, which causes urlwrite to be used, even if websave is
    %available. A check is in place to prevent the reverse.
    default.UseURLwrite=isempty(which('websave'));%(allows user-implementation in subfunction)
    default.err429=struct('CountsAsTry',false,...
        'TimeToWait',15,'PrintAtVerbosityLevel',3);
    default.print_to=struct('use_fprintf',true,'fid',1,'object',[]);
    
    %The contents of this struct will have been set in the main function, so they can be loaded
    %from the pref without needing to check for an empty variable.
    IsFirstRun=getpref('HJW',...%toolbox name or author initials as group ID
        ['WBM___',...%function group
        'IsFirstRun'],...%preference name
        []);
end
%The required inputs are checked, so now we need to return the default options if there are no
%further inputs.
if nargin==2
    options=default;
    success=true;
    return
end

%test the optional inputs
struct_input=nargin==3 && isa(varargin{1},'struct');
NameValue_input=mod(nargin,2)==0 && ...
    all(cellfun('isclass',varargin(1:2:end),'char'));
if ~( struct_input || NameValue_input )
    ME.message=['The third input (options) is expected to be either a ',...
        'struct,',char(10),'or consist of Name,Value pairs.']; %#ok<CHARTEN>
    ME.identifier='HJW:WBM:incorrect_input_options';
    return
end
if NameValue_input
    %convert the Name,Value to a struct
    for n=1:2:numel(varargin)
        try
            options.(varargin{n})=varargin{n+1};
        catch
            ME.message='Parsing of Name,Value pairs failed.';
            ME.identifier='HJW:WBM:incorrect_input_NameValue';
            return
        end
    end
else
    options=varargin{1};
end
fn=fieldnames(options);
for k=1:numel(fn)
    curr_option=fn{k};
    item=options.(curr_option);
    ME.identifier=['HJW:WBM:incorrect_input_opt_' lower(curr_option)];
    switch curr_option
        case 'date_part'
            if ~ischar(item) || numel(item)==0 || numel(item)>14 || any(item<48 & item>57)
                ME.message='The value of options.date_part is empty or not a valid numeric char.';
                return
            end
        case 'tries'
            if ~isnumeric(item) || numel(item)~=3 || any(isnan(item))
                ME.message=['The value of options.tries has an incorrect format.',char(10),...
                    'The value should be a numeric vector with 3 integer elements.'];%#ok<CHARTEN>
                return
            end
        case 'response'
            if WBM_parse_inputs__validate_response_format(item)
                ME.message='The value of options.response has an incorrect format.';
                return
            end
        case 'ignore'
            if ~isnumeric(item) || numel(item)==0 || any(isnan(item))
                ME.message=['The value of options.ignore has an incorrect format.',char(10),...
                    'The value should be a numeric vector with HTML error codes.'];%#ok<CHARTEN>
                return
            end
        case 'verbose'
            if ~isnumeric(item) || numel(item)~=1 || double(item)~=round(double(item))
                %The integer test could cause unexpected behavior due to float rounding, but in
                %fact an error is preferred here.
                ME.message='The value of options.verbose is not an integer scalar.';
                return
            end
        case 'm_date_r'
            if ~ischar(item) || numel(item)==0
                ME.message='Options.m_date_r should be ''ignore'', ''warning'', or ''error''.';
                return
            end
            default__m_date_r__changed=true;
            switch lower(item)
                case 'ignore'
                    item=0;
                case 'warning'
                    item=1;
                case 'error'
                    item=2;
                otherwise
                    ME.message='Options.m_date_r should be ''ignore'', ''warning'', or ''error''.';
                    return
            end
            options.m_date_r=item;
        case 'flag'
            if ischar(item) && numel(item)~=0 && ~ismember({item},{'*','id','js','cs','im'})
                ME.message='Invalid flag. Must be a char with either *, id, js, cs, or im.';
                return
            end
        case 'UseURLwrite'
            [passed,item]=test_if_scalar_logical(item);
            if ~passed
                ME.message='UseURLwrite should be either true or false';
                return
            end
            %force the use of urlwrite if websave is not available
            options.UseURLwrite=item || default.UseURLwrite;
        case 'err429'
            if ~isa(item,'struct')
                ME.message='The err429 parameter should be a struct.';
                return
            end
            %Loop through the fields in the input and overwrite defaults.
            options.err429=default.err429;fn_=fieldnames(item);
            for n=1:numel(fn_)
                tmp=item.(fn_{n});
                switch lower(fn_{n})
                    case 'countsastry'%'CountsAsTry'
                        [passed,tmp]=test_if_scalar_logical(tmp);
                        if ~passed
                            ME.message=['Invalid field CountsAsTry in the err429 parameter: ',...
                                'should be a logical scalar.'];
                            return
                        end
                        options.err429.CountsAsTry=tmp;
                    case 'timetowait'%'TimeToWait'
                        if ~isnumeric(tmp) || numel(tmp)~=1
                            ME.message=['Invalid field TimeToWait in the err429 parameter: ',...
                                'should be a numeric scalar.'];
                            return
                        end
                        %Under some circumstances this value is divided, so it has to be converted
                        %to a float type.
                        options.err429.TimeToWait=double(tmp);
                    case 'printatverbositylevel'%'PrintAtVerbosityLevel'
                        if ~isnumeric(tmp) || numel(tmp)~=1 || ...
                                double(tmp)~=round(double(tmp))
                            ME.message=['Invalid field PrintAtVerbosityLevel in the err429 ',...
                                'parameter: should be a scalar double integer.'];
                            return
                        end
                        options.err429.PrintAtVerbosityLevel=tmp;
                    otherwise
                        warning('HJW:WBM:NameValue_not_found',...
                            'Name,Value pair not recognized during parsing of err429 parameter: %s',fn_{n});
                end
            end
            case 'print_to'
            if ~isa(item,'struct')
                ME.message='The print_to parameter should be a struct.';
                return
            end
            %Loop through the fields in the input and overwrite defaults.
            options.print_to=default.print_to;fn_=fieldnames(item);
            for n=1:numel(fn_)
                tmp=item.(fn_{n});
                switch lower(fn_{n})
                    case 'use_fprintf'
                        [passed,tmp]=test_if_scalar_logical(tmp);
                        if ~passed
                            ME.message=['Invalid field use_fprintf in the print_to parameter: ',...
                                'should be a logical scalar.'];
                            return
                        end
                        options.print_to.use_fprintf=tmp;
                    case 'fid'
                        try position=ftell(tmp);catch,position=-1;end
                        if tmp~=1 && position==-1
                            ME.message=['Invalid field fid in the print_to parameter: ',...
                                'should be a valid file identifier or 1.'];
                            return
                        end
                        options.print_to.fid=tmp;
                    case 'object'
                        try
                            txt=get(tmp,'String'); %#ok<NASGU> see if this triggers an error
                            options.print_to.object=tmp;
                        catch
                            ME.message=['Invalid field object in the print_to parameter: ',...
                                'should be object with String property'];
                            return
                        end
                end
            end
        otherwise
            ME.message=...
                sprintf('Name,Value pair not recognized: %s',curr_option);
            ME.identifier='HJW:WBM:incorrect_input_NameValue';
            return
    end
end

%fill any missing fields
fn=fieldnames(default);
for k=1:numel(fn)
    if ~isfield(options,fn(k))
        options.(fn{k})=default.(fn{k});
    end
end

%If the requested date doesn't match the current date, saves are not allowed, even if tries would
%suggest they are, so the code below checks this and sets tries(2) to 0 if needed.
%Because the server is in UTC (which might differ from the time returned by the now function), the
%local time can't be used for this check.
try
    currentUTC=WBM_getUTC_local;%should work, tested on first run of main function
catch
    errordlg(IsFirstRun.errordlg_text{:})
    ME=IsFirstRun.ME;
    return
end
if options.UseLocalTime
    %The date_part is in the local time. The problem with this is that the date_part can now no
    %longer be uniquely matched to the output returned by the WBM (as 2000-01-01 in local time may
    %e.g. match 2000-01-01 4:00 to 2000-01-02 3:59). This will either require rounding in this
    %function (by removing the last digit), or expanding the check_date function to incorporate the
    %time zone offset.
    %For now an error is thrown.
    ME.message='Using the local time to match against the date_part is not yet supported.';
    ME.identifier='HJW:WBM:NotImplemented';
    return
else
    %The date_part is in UTC, so the getUTC output can be used.
end
today=datestr(currentUTC,'yyyymmddTHHMMSS');
%ML6.5 needs a specific format from a short list, the closest to the needed
%format (yyyymmddHHMMSS) is ISO 8601 (yyyymmddTHHMMSS).
today(9)='';%remove the T
if ~strcmp(today(1:length(options.date_part)),options.date_part)
    %No saves allowed, because datepart doesn't match today.
    options.tries(2)=0;
end

%If the m_date_r is set to error and the flag is set to something other than '*' the check_date
%function will return an error, regardless of the date stamp of the file.
%If that is the case, throw an error here.
if options.m_date_r==2 && ~strcmp(options.flag,'*')
    ME.message=['m_date_r set to ''error'' and the flag set to something other than ''*'' will',...
        ' by definition',char(10),'cause an error, as the downloaded pages will not contain',...
        ' any dates.',char(10),'See the help text for a work-around for images.']; %#ok<CHARTEN>
    ME.identifier='HJW:WBM:IncompatibleInputs';
    return
end
if ~default__m_date_r__changed && ~strcmp(options.flag,'*')
    %If the default is not changed, but the flag is set to something else than '*', then the
    %m_date_r should be set to 0 (ignore).
    options.m_date_r=0;
end
success=true;ME=[];
end
function is_invalid=WBM_parse_inputs__validate_response_format(response)
%check if the content of the response input is in the correct format
%see doc('WBM') for a description of the correct format
is_invalid=false;
if ~iscell(response) || isempty(response) || size(response,2)~=3
    is_invalid=true;return
end
for row=1:size(response,1)
    %check col 1: t1, t2, tx or combination
    item=response{row,1};
    item_count=numel(item(2:2:end));
    if ~ischar(item) || numel(item)==0 || ~all(ismember(item(2:2:end),'12x'))
        is_invalid=true;return
    end
    %check col 2: html codes
    item=response{row,2};
    if ~isa(item,'double') || numel(item)~=item_count
        %the validity of a html code is not checked
        %a timeout caught in Matlab is encoded with 4080 (due to its similarity with HTML status
        %code 408)
        is_invalid=true;return
    end
    %check col 3: load, save, exit or pause_retry
    item=response{row,3};
    if ~ischar(item) || ~ismember({item},{'load','save','exit','pause_retry'})
        is_invalid=true;return
    end
end
end