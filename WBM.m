function outfilename=WBM(filename,url_part,options)
% This functions acts as an API for the Wayback Machine (web.archive.org).
%
% With this function you can download captures to the internet archive that
% matches a date pattern. If the current time matches the pattern and there
% is no valid capture, a capture will be generated.
%
% This code enables you to use a specific web page in your processing,
% without the need to check if the page has changed its structure or is not
% available at all.
%
% syntax:
% outfilename=WBM(filename,url_part)
% outfilename=WBM( __,options)
%
% outfilename: Full path of the output file, the variable is empty if the
%              download failed.
% filename   : The target filename in any format that websave (or urlwrite)
%              accepts. If this file already exists, it will be overwritten
%              in most cases.
% url_part   : This url will be searched for on the WBM. The url might be
%              changed (e.g. ':80' is often added).
% options    : A struct containing the fields date_part, tries, response,
%              ignore, verbose and m_date_r.
%
% date_part : A string with the date of the capture. It must be in the
%             yyyymmddHHMMSS format, but doesn't have to be complete.
%             [default='2';]
% tries     : A 1x3 vector. The first value is the total number of times an
%             attempt to load the page is made, the second value is the
%             number of save attempts and the last value is the number of
%             timeouts allowed. [default=[5 4 4];]
% verbose   : A scalar denoting the verbosity. Level 1 includes only
%             warnings about the internet connection being down. Level 2
%             includes errors  NOT matching the usual pattern as well and
%             level 3 includes all other errors that get rethrown as disp
%             or warning. Level 0 will hide all errors that are caught.
%             [default=3;]
%             Octave uses a wrapper for curl, so error catching is bit more
%             difficult. This will result in more errors being rethrown as
%             warnings under Octave than Matlab.
% m_date_r  : A string describing the response to the date missing in the
%             downloaded web page. Usually, either the top bar will be
%             present (which contains links), or the page itself will
%             contain links, so this situation may indicate a problem with
%             the save to the WBM. Allowed values are 'ignore', 'warning'
%             and 'error'. Be aware that non-page content (such as images)
%             will set off this response. [default='warning';]
% For the response and ignore fields, see the code itself.
%
% Compatibility:
% Matlab: should work on all releases (tested on R2017b, R2012b and R6.5)
% Octave: tested on 4.2.1
% OS:     written on Windows 10 (64bit), Octave tested on a virtual (32bit)
%         Ubuntu 16.04 LTS, should work for Mac
%
% Version: 1.3.1
% Date:    2018-04-23
% Author:  H.J. Wisselink
% Email=  'h_j_wisselink*alumnus_utwente_nl';
% Real_email = regexprep(Email,{'*','_'},{'@','.'})
%
% subfunction (isnetavl) adapted from:
% https://www.mathworks.com/matlabcentral/fileexchange/
% 50498-internet-connection-status
% and published separately on the FEX:
% http://www.mathworks.com/matlabcentral/fileexchange/64956-isnetavl
% Logo adapted from:
% https://commons.wikimedia.org/wiki/File:Blank_globe.svg

%narginchk(2,3)
if ~(nargin==2 || nargin==3)
    error('Incorrect number of input argument.')
end
if ~(nargout==0 || nargout==1)
    error('Incorrect number of output argument.')
end
if ~exist('options','var'),options=struct;end
try
    ST = dbstack('-completenames');
catch
    ST=dbstack;
end
FuncName=ST(1).name;%auto-generate the function name in case of a name change
try
    try %use this try/catch block to have a neater error format
        validateattributes(filename,{'char'},{'nonempty'},...
            FuncName,'filename')
        validateattributes(url_part,{'char'},{'nonempty'},...
            FuncName,'url_part')
        validateattributes(options,{'struct'},{'nonempty'},...
            FuncName,'setting')
    catch ME
        throw(ME)
    end
catch
    %the syntax 'catch ME' will trigger an error in ML6.5
    %this block contains checks that are compatible with ML6.5
    if ~ischar(filename) || numel(filename)==0
        error('The first input (filename) is not char and/or empty.')
    end
    if ~ischar(url_part) || numel(url_part)==0
        error('The second input (url) is not char and/or empty.')
    end
    if ~isstruct(options)
        error('The third input (options) is not a struct.')
    end
end

%websave was introduced in R2014b (v8.4) and isn't built into Octave 4.2.1.
%Once this function is built into Octave, this logic can be expanded to
%consider the exact Octave release that uses websave.
PlatformVersion=version;PlatformVersion=str2double(PlatformVersion(1:3));
isOld= PlatformVersion<8.4;
isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;

%Response and ignore must the either be the complete text after
%"MATLAB:webservices:", or a HTML status code (will be converted to char).
%The Matlab timeout error is encoded with 4080 (analogous to HTTP 408).
%
%Ignored errors will only be ignored for the purposes of the response.
%If a response is not allowed by 'tries' left, the other response (save or
%load) is tried, until sum(tries(1:2))==0. If there is still no successful
%download, the output file will be deleted and the script will exit.

default.date_part='2';%load a random date (generally the last)
default.tries=[5 4 4];%loads saves timeouts allowed
%t1 - failed attempt to load
%t2 - failed attempt to save
%tx - either t1 or t2
default.response={...
    'tx',404,'load';...%a 404 may also occur after a successful save
    'txtx',[404 404],'save';...
    'tx',403,'save';...
    't2t2',[403 403],'exit'...%most likely the page doesn't support the WBM
    };
default.ignore=4080;
default.verbose=3;
default.m_date_r='warning';

if ~isfield(options,'tries')
    tries=default.tries;
else
    tries=options.tries;
end
if ~isfield(options,'date_part')
    date_part=default.date_part;
else
    date_part=options.date_part;
    today=datestr(now,'yyyymmddTHHMMSS');
    %ML6.5 needs a specific format from a short list, the closest to the
    %needed format (yyyymmddHHMMSS) is ISO 8601 (yyyymmddTHHMMSS).
    today(9)='';%remove the T again
    if ~strcmp(today(1:length(date_part)),date_part)
        %No saves allowed, because datepart doesn't match today.
        %This ignores a possible difference between the time provided by
        %'now' and the server time from the Wayback Machine.
        tries(2)=0;
    end
end
%SavesAllowed=logical(tries(2));
SavesAllowed=tries(2)~=0;%avoids a warning compared to the line above
if ~isfield(options,'response')
    response=default.response;
else
    response=options.response;
end
if ~isfield(options,'ignore')
    ignore=default.ignore;
else
    ignore=options.ignore(:);
end
if ~isfield(options,'verbose')
    verbose=default.verbose;
else
    verbose=options.verbose;
end
if ~isfield(options,'m_date_r')
    m_date_r=default.m_date_r;
else
    m_date_r=options.m_date_r;
end

try
    try
        validateattributes(date_part,{'char'},{'vector','nonempty'},...
            FuncName,'options.date_part')
        validateattributes(tries,{'numeric'},{'vector','nonempty','numel',3},...
            FuncName,'options.tries')
        %the response list shouldn't be empty
        validateattributes(response,{'cell'},{'size',[NaN,3],'nonempty'},...
            FuncName,'options.response')
        validateattributes(ignore,{'numeric'},{'nonnan'},...
            FuncName,'options.ignore')
        validateattributes(verbose,{'numeric'},{'scalar','nonempty'},...
            FuncName,'options.verbose')
        validateattributes(m_date_r,{'char'},{'vector','nonempty'},...
            FuncName,'options.m_date_r')
        switch lower(m_date_r)
            case 'ignore'
                m_date_r=0;
            case 'warning'
                m_date_r=1;
            case 'error'
                m_date_r=2;
            otherwise
                error(['Options.m_date_r should be ''ignore'', ',...
                    '''warning'', or ''error''.'])
        end
    catch ME
        throw(ME)
    end
catch
    %the syntax 'catch ME' will trigger an error in ML6.5
    %this block contains checks that are compatible with ML6.5
    if ~ischar(date_part) || numel(date_part)==0
        error('The value of options.date_part is not char and/or empty.')
    end
    if ~isnumeric(tries) || numel(tries)~=3 || any(isnan(tries))
        error(['The value of options.tries has an incorrect format.',...
            char(5+5),...
            'The value should be a numeric vector with 3 integer elements.'])
    end
    if ~iscell(response) || isempty(response) || size(response,2)~=3
        error('The value of options.response has an incorrect format.')
    end
    if ~isnumeric(ignore) || numel(ignore)==0 || any(isnan(ignore))
        error(['The value of options.ignore has an incorrect format.',...
            char(5+5),...
            'The value should be a numeric vector with html error codes.'])
    end
    if ~isnumeric(verbose) || numel(verbose)~=1 || ...
            double(verbose)~=round(double(verbose))
        error('The value of options.verbose is not an integer scalar.')
    end
    if ~ischar(date_part) || numel(date_part)==0
        error(['Options.m_date_r should be ''ignore'', ',...
            '''warning'', or ''error''.'])
    end
    switch lower(m_date_r)
        case 'ignore'
            m_date_r=0;
        case 'warning'
            m_date_r=1;
        case 'error'
            m_date_r=2;
        otherwise
            error(['Options.m_date_r should be ''ignore'', ',...
                '''warning'', or ''error''.'])
    end
end
%Order responses based on pattern length to match
response_lengths=cellfun('length',response(:,2));
[response_lengths,order]=sort(response_lengths);
order=order(end:-1:1);%sort(__,'descend'); is not supported in ML6.5
response=response(order,:);

%The catch ME syntax was introduced in R2007b. In prior releases, the ME
%was a struct reachable with lasterror. To prevent an error later in this
%code, assign something to ME.
ME=struct;%#ok ML6.5
v=version;v=str2double(v(1:3));

prefer_type=1;%prefer loading
succes=false;%start loop
S.response_list_vector=[];%initialize response list
S.type_list=[];%initialize type list
%Using a struct to wrap the variable suppresses the m-lint warning.
connection_down_wait_factor=0;%initialize
while ~succes && ...          %no successful download yet?
        sum(tries(1:2))>0 ... %any save or load tries left?
        && tries(3)>=0        %timeout limit reached?
    if tries(prefer_type)<=0%no tries left for the preferred type
        %switch 1 to 2 and 2 to 1
        prefer_type=3-prefer_type;
    end
    type=prefer_type;
    try %try download, if successful, exit loop
        if type==1              %load
            tries(type)=tries(type)-1;
            if isOld
                outfilename=urlwrite(...
                    ['http://web.archive.org/web/' date_part '*_/' url_part],...
                    filename);
            else
                outfilename=websave(filename,...
                    ['https://web.archive.org/web/' date_part '*_/' url_part],...
                    weboptions('Timeout',10));
            end
        elseif type==2          %save
            tries(type)=tries(type)-1;
            if isOld
                outfilename=urlwrite(...
                    ['http://web.archive.org/save/' url_part],...
                    filename);
            else
                outfilename=websave(filename,...
                    ['https://web.archive.org/save/' url_part],...
                    weboptions('Timeout',10));
            end
        end
        succes=true;
        connection_down_wait_factor=0;
        if SavesAllowed && ~check_date(outfilename,date_part,m_date_r)
            %Incorrect date, so try saving.
            succes=false;prefer_type=2;
        end
    catch ME;%#ok ML6.5
        if v<7.5
            %The catch ME syntax was introduced in R2007b. In prior
            %releases, the ME was a struct reachable with lasterror.
            ME=lasterror;%#ok ML6.5
        end
        succes=false;
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
                if connection_down_wait_factor==7,connection_down_wait_factor=6;end
                pause(2^connection_down_wait_factor)
            end
            %Skip the rest of the error processing and retry without
            %reducing points.
            continue
        end
        connection_down_wait_factor=0;
        ME_id=ME.identifier;
        ME_id=strrep(ME_id,':urlwrite:',':webservices:');
        if strcmp(ME_id,'MATLAB:webservices:Timeout')
            code=4080;
            tries(3)=tries(3)-1;
        else
            %raw_code=textscan(ME_id,'MATLAB:webservices:HTTP%dStatusCodeError');
            raw_code=strrep(ME_id,'MATLAB:webservices:HTTP','');
            raw_code=strrep(raw_code,'StatusCodeError','');
            raw_code=str2double(raw_code);
            if isnan(raw_code)
                %textscan would have failed
                code=-1;
                if verbose>=2
                    if isOctave
                        disp(ME.message),drawnow
                    else
                        warning(ME.message)
                    end
                end
            else
                %Octave doesn't really returns a identifier for urlwrite,
                %nor do very old releases of Matlab.
                switch ME.message
                    case 'urlwrite: Couldn''t resolve host name'
                        code=404;
                    case ['urlwrite: Peer certificate cannot be ',...
                            'authenticated with given CA certificates']
                        %It's not really a 403, but the result in this
                        %context is similar.
                        code=403;
                    otherwise
                        code=raw_code;
                end
            end
        end
        if isempty(code)
            %Some other error occurred, set a code and rethrow as
            %warning. As Octave does not report an HTML error code,
            %this will happen every error. To reduce command window
            %clutter, use disp instead of rethrowing.
            code=-1;
            if verbose>=2
                if isOctave
                    disp(ME.message),drawnow
                else
                    warning(ME.message)
                end
            end
        end
        
        if verbose>=3
            fprintf('Error %d tries(%d,%d,%d) (download of %s)\n',...
                double(code),tries(1),tries(2),tries(3),filename);drawnow
        end
        if ~any(code==ignore)
            S.response_list_vector(end+1)=code;
            S.type_list(end+1)=type;
            for n_response_pattern=1:size(response,1)
                if length(S.response_list_vector)<...
                        response_lengths(n_response_pattern)
                    %Not enough failed attempts (yet) to match against the
                    %current pattern.
                    continue
                end
                last_part_of_response_list=S.response_list_vector(...
                    (end-response_lengths(n_response_pattern)+1):end);
                last_part_of_S.type_list=S.type_list(...
                    (end-response_lengths(n_response_pattern)+1):end);
                
                %Compare the last types to the type patterns.
                temp_type_pattern=response{n_response_pattern,1}(2:2:end);
                temp_type_pattern=strrep(temp_type_pattern,'x',num2str(type));
                type_fits=strcmp(temp_type_pattern,...
                    sprintf('%d',last_part_of_S.type_list));
                if isequal(...
                        response{n_response_pattern,2},...
                        last_part_of_response_list)...
                        && type_fits
                    %If the last part of the response list matches with the
                    %response pattern in the current element of 'response',
                    %set prefer_type to 1 for load, and to 2 for save.
                    switch response{n_response_pattern,3}
                        case 'load'
                            prefer_type=1;
                        case 'save'
                            prefer_type=2;
                        case 'exit'
                            %Cause a break in the while loop.
                            tries=[0 0 -1];
                    end
                    break
                end
            end
        end
    end
end

if ~succes || ...
        ( ~SavesAllowed && ~check_date(outfilename,date_part,m_date_r) )
    %If saving isn't allowed and the date doesn't match the date_part, or
    %no successful download was reached within the allowed tries, delete
    %the outputfile (as it will be either the incorrect date, or 0 bytes).
    delete(filename);
    outfilename=[];
end
if nargout==0
    clear('outfilename');
end
end
function date_correct=check_date(outfilename,date_part,m_date_r)
isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
v=version;v=str2double(v(1:3));

%Strategy 1:
%Rely on the html for the header to provide the date of the currently
%viewed capture.
StringToMatch='<input type="hidden" name="date" value="';
if ~isOctave
    if v>=7
        fid=fopen(outfilename,'rt','n','UTF-8');
        data=textscan(fid,'%s','Delimiter','\n');
        fclose(fid);
        data=data{1};
    else
        %encoding support and mode was introduced in ML7 (R14)
        %textscan was introduced probably introduced in ML7 as well
        %
        %The buffer size has to be increased to accommodate for longer
        %lines, although this should be enough for most web pages. The
        %elegant way to do this is in a loop with a try and catch, using
        %lasterror to figure out if the error is indeed caused by a buffer
        %overflow. A char array is 2 bytes per character, so the initial
        %maximum is 2500 characters per line.
        init_bufsize=5000;bufsize=init_bufsize;pattern='Buffer overflow';
        while true
            try
                data=textread(outfilename,'%s','delimiter','\n',...
                    'bufsize',bufsize);%#ok ML6.5
                break
            catch
                ME=lasterror;%#ok ML6.5
                if numel(ME.message)>length(pattern) && ...
                        strcmp(ME.message(1:length(pattern)),pattern)
                    bufsize=bufsize*10;
                else
                    retrow(ME)
                end
            end
        end
    end
else
    data = cell(0);
    fid = fopen (outfilename, 'r');
    i=0;
    while i==0 || ischar(data{i})
        data{++i} = fgetl (fid);
    end
    fclose (fid);
    data = data(1:end-1);  % No EOL
end
%ismember can result in a memory error in ML6.5
%pos=find(ismember(data,'<td class="u" colspan="2">'));
pos=0;
while pos<=numel(data) &&...
        (pos==0 || ~strcmp(data{pos},'<td class="u" colspan="2">'))
    pos=pos+1;
end
%if numel(pos)~=0 && numel(data)<=(pos+1)
if numel(data)>=(pos+1)
    line=data{pos+1};
    idx=strfind(line,StringToMatch);
    idx=idx+length(StringToMatch)-1;
    date_correct=strcmp(line(idx+(1:length(date_part))),date_part);
    return
end
%Strategy 2:
%Try a much less clean version: don't rely on the top bar, but look for
%links that indicate a link to the same date in the Wayback Machine.
%The most common occurring date will be compared with date_part.
if ~isOctave
    if v>=7
        fid=fopen(outfilename,'rt','n','UTF-8');
        data=textscan(fid,'%s','Delimiter','\n');
        fclose(fid);
        data=data{1};
    else
        %encoding support and mode was introduced in ML7 (R14)
        %textscan was introduced probably introduced in ML7 as well
        %
        %The buffer size has to be increased to accommodate for longer
        %lines, although this should be enough for most web pages. The
        %elegant way to do this is in a loop with a try and catch, using
        %lasterror to figure out if the error is indeed caused by a buffer
        %overflow. A char array is 2 bytes per character, so the initial
        %maximum is 2500 characters per line.
        init_bufsize=5000;bufsize=init_bufsize;pattern='Buffer overflow';
        while true
            try
                data=textread(outfilename,'%s','delimiter','\n',...
                    'bufsize',bufsize);%#ok ML6.5
                break
            catch
                ME=lasterror;%#ok ML6.5
                if numel(ME.message)>length(pattern) && ...
                        strcmp(ME.message(1:length(pattern)),pattern)
                    bufsize=bufsize*10;
                else
                    retrow(ME)
                end
            end
        end
    end
else
    data = cell(0);
    fid = fopen (outfilename, 'r');
    i=0;
    while i==0 || ischar(data{i})
        data{++i} = fgetl (fid);
    end
    fclose (fid);
    data = data(1:end-1);  % No EOL
end
data(:,2)={' '};data=data';data=data(:)';data=cell2mat(data);
%data is now a single long string
idx=strfind(data,'/web/');
if numel(idx)==0
    if m_date_r==0     %ignore
        date_correct=true;
        return
    elseif m_date_r==1 %warning
        warning(['No date found in file, unable to check date,',...
            ' assuming it is correct.'])
        date_correct=true;
        return
    elseif m_date_r==2 %error
        error(['Could not find date. This can mean there is an ',...
            'error in the save. Try saving manually.'])
    end
end
datelist=cell(size(idx));
if v>=7
    for n=1:length(idx)
        for m=1:14
            if ~isstrprop(data(idx(n)+4+m),'digit')
                break
            end
        end
        datelist{n}=data(idx(n)+4+(1:m));
    end
else
    %it is not entirely clear when the isstrprop function was introduced
    for n=1:length(idx)
        for m=1:14
            if ~any(double(data(idx(n)+4+m))==(48:57))
                break
            end
        end
        datelist{n}=data(idx(n)+4+(1:m));
    end
end
[a,ignore_output,c]=unique(datelist);%#ok ~
%In some future release, histc might not be supported anymore. In that case
%the following lines can be wrapped in some logic to reflect this.
%note: accumarray(c,1) and histc(c,1:max(c)) are equivalent in this context
[ignore_output,c2]=max(histc(c,1:max(c)));%#ok ~
%[ignore_output,c2]=max(accumarray(c,1));
line=a{c2};
date_correct=strcmp(line((1:length(date_part))),date_part);
end
function [connected,timing]=isnetavl
% Ping to one of Google's DNSes.
% Optional second output is the ping time.
%
% Windows code adapted from:
% https://www.mathworks.com/matlabcentral/fileexchange/
% 50498-internet-connection-status
%
% Logo adapted from:
% https://commons.wikimedia.org/wiki/File:Blank_globe.svg
%
% Compatibility:
% Matlab: should work on all releases (tested on R2017b, R2012b and R6.5)
% Octave: tested on 4.2.1
% OS:     written on Windows 10 (64bit), Octave tested on a virtual (32bit)
%         Ubuntu 16.04 LTS, might work on Mac
%
% Version: 1.1
% Date:    2018-01-10
% Author:  H.J. Wisselink
% Email=  'h_j_wisselink*alumnus_utwente_nl';
% Real_email = regexprep(Email,{'*','_'},{'@','.'})

if ispc
    %8.8.4.4 will also work
    [ignore_output,b]=system('ping -n 1 8.8.8.8');%#ok ~
    n=strfind(b,'Lost');
    n1=b(n+7);
    if(n1=='0')
        connected=1;
        if nargout==2
            n=strfind(b,'time=');m=strfind(b,'ms');m=m(m>n);m=m(1)-1;
            timing=str2double(b((n+5):m));
        end
    else
        connected=0;
        timing=0;
    end
elseif isunix
    %8.8.4.4 will also work
    [ignore_output,b]=system('ping -c 1 8.8.8.8');%#ok ~
    n=strfind(b,'received');
    n1=b(n-2);
    if(n1=='1')
        connected=1;
        if nargout==2
            n=strfind(b,'/');n=n([end-1 end]);
            timing=str2double(b(n(1):n(2)));
        end
    else
        connected=0;
        timing=0;
    end
else
    error('How did you even get Matlab to work?')
end
end