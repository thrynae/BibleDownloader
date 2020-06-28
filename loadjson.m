%This function is based on the FEX submission JSONlab by Qianqian Fanq
%https://www.mathworks.com/matlabcentral/fileexchange/
%  33381-jsonlab--a-toolbox-to-encode-decode-json-files
%The loadjson function and its dependencies were collated here and made
%compatible with ML6.5, which only required one edit. For some reason
%detecting a string input doesn't work on ML6.5, so the first logic was
%removed.

function data = loadjson(fname,varargin)
%
% data=loadjson(fname,opt)
%    or
% data=loadjson(fname,'param1',value1,'param2',value2,...)
%
% parse a JSON (JavaScript Object Notation) file or string
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% created on 2011/09/09, including previous works from 
%
%         Nedialko Krouchev: http://www.mathworks.com/matlabcentral/fileexchange/25713
%            created on 2009/11/02
%         François Glineur: http://www.mathworks.com/matlabcentral/fileexchange/23393
%            created on  2009/03/22
%         Joel Feenstra:
%         http://www.mathworks.com/matlabcentral/fileexchange/20565
%            created on 2008/07/03
%
% $Id$
%
% input:
%      fname: input file name, if fname contains "{}" or "[]", fname
%             will be interpreted as a JSON string
%      opt: a struct to store parsing options, opt can be replaced by 
%           a list of ('param',value) pairs - the param string is equivallent
%           to a field in opt. opt can have the following 
%           fields (first in [.|.] is the default)
%
%           opt.SimplifyCell [0|1]: if set to 1, loadjson will call cell2mat
%                         for each element of the JSON data, and group 
%                         arrays based on the cell2mat rules.
%           opt.FastArrayParser [1|0 or integer]: if set to 1, use a
%                         speed-optimized array parser when loading an 
%                         array object. The fast array parser may 
%                         collapse block arrays into a single large
%                         array similar to rules defined in cell2mat; 0 to 
%                         use a legacy parser; if set to a larger-than-1
%                         value, this option will specify the minimum
%                         dimension to enable the fast array parser. For
%                         example, if the input is a 3D array, setting
%                         FastArrayParser to 1 will return a 3D array;
%                         setting to 2 will return a cell array of 2D
%                         arrays; setting to 3 will return to a 2D cell
%                         array of 1D vectors; setting to 4 will return a
%                         3D cell array.
%           opt.ShowProgress [0|1]: if set to 1, loadjson displays a progress bar.
%
% output:
%      dat: a cell array, where {...} blocks are converted into cell arrays,
%           and [...] are converted to arrays
%
% examples:
%      dat=loadjson('{"obj":{"string":"value","array":[1,2,3]}}')
%      dat=loadjson(['examples' filesep 'example1.json'])
%      dat=loadjson(['examples' filesep 'example1.json'],'SimplifyCell',1)
%
% license:
%     BSD License, see LICENSE_BSD.txt files for details 
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%
global LOADJSON_pos LOADJSON_index_esc LOADJSON_isoct LOADJSON_arraytoken

string=fname;
% if(regexp(fname,'^\s*(?:\[.*\])|(?:\{.*\})\s*$','once'))
%    string=fname;
% elseif(exist(fname,'file'))
%    try
%        string = fileread(fname);
%    catch
%        try
%            string = urlread(['file://',fname]);
%        catch
%            string = urlread(['file://',fullfile(pwd,fname)]);
%        end
%    end
% else
%    error('input file does not exist');
% end

LOADJSON_pos = 1; len = length(string); inStr = string;
LOADJSON_isoct=exist('OCTAVE_VERSION','builtin');
LOADJSON_arraytoken=find(inStr=='[' | inStr==']' | inStr=='"');
jstr=regexprep(inStr,'\\\\','  ');
escquote=regexp(jstr,'\\"');
LOADJSON_arraytoken=sort([LOADJSON_arraytoken escquote]);

% String delimiters and escape chars identified to improve speed:
esc = find(inStr=='"' | inStr=='\' ); % comparable to: regexp(inStr, '["\\]');
LOADJSON_index_esc = 1;

opt=varargin2struct(varargin{:});

if(jsonopt('ShowProgress',0,opt)==1)
    opt.progressbar_=waitbar(0,'loading ...');
end
jsoncount=1;
while LOADJSON_pos <= len
    switch(next_char(inStr))
        case '{'
            data{jsoncount} = parse_object(inStr, esc, opt);%#ok
        case '['
            data{jsoncount} = parse_array(inStr, esc, opt);%#ok
        otherwise
            error_pos('Outer level structure must be an object or an array',inStr);
    end
    jsoncount=jsoncount+1;
end % while

jsoncount=length(data);
if(jsoncount==1 && iscell(data))
    data=data{1};
end

if(isfield(opt,'progressbar_'))
    close(opt.progressbar_);
end

%%-------------------------------------------------------------------------
function object = parse_object(inStr, esc, varargin)
    parse_char(inStr, '{');
    object = [];
    if next_char(inStr) ~= '}'
        while 1
            str = parseStr(inStr, esc, varargin{:});
            if isempty(str)
                error_pos('Name of value at position %d cannot be empty',inStr);
            end
            parse_char(inStr, ':');
            val = parse_value(inStr, esc, varargin{:});
            object.(valid_field(str))=val;
            if next_char(inStr) == '}'
                break;
            end
            parse_char(inStr, ',');
        end
    end
    parse_char(inStr, '}');
    if(isstruct(object))
        object=struct2jdata(object);
    end

%%-------------------------------------------------------------------------

function object = parse_array(inStr, esc, varargin) % JSON array is written in row-major order
    global LOADJSON_pos LOADJSON_isoct
    parse_char(inStr, '[');
    object = cell(0, 1);
    dim2=[];
    arraydepth=jsonopt('JSONLAB_ArrayDepth_',1,varargin{:});
    pbar=-1;
    if(isfield(varargin{1},'progressbar_'))
        pbar=varargin{1}.progressbar_;
    end

    if next_char(inStr) ~= ']'
	if(jsonopt('FastArrayParser',1,varargin{:})>=1 && arraydepth>=jsonopt('FastArrayParser',1,varargin{:}))
            [endpos, e1l, e1r]=matching_bracket(inStr,LOADJSON_pos);
            arraystr=['[' inStr(LOADJSON_pos:endpos)];
            arraystr=regexprep(arraystr,'"_NaN_"','NaN');
            arraystr=regexprep(arraystr,'"([-+]*)_Inf_"','$1Inf');
            arraystr(arraystr==sprintf('\n'))=[];%#ok
            arraystr(arraystr==sprintf('\r'))=[];
            %arraystr=regexprep(arraystr,'\s*,',','); % this is slow,sometimes needed
            if(~isempty(e1l) && ~isempty(e1r)) % the array is in 2D or higher D
        	astr=inStr((e1l+1):(e1r-1));
        	astr=regexprep(astr,'"_NaN_"','NaN');
        	astr=regexprep(astr,'"([-+]*)_Inf_"','$1Inf');
        	astr(astr==sprintf('\n'))=[];%#ok
        	astr(astr==sprintf('\r'))=[];
        	astr(astr==' ')='';
        	if(isempty(find(astr=='[')))%#ok % array is 2D
                    dim2=length(sscanf(astr,'%f,',[1 inf]));
        	end
            else % array is 1D
        	astr=arraystr(2:end-1);
        	astr(astr==' ')='';
        	[obj, count, errmsg, nextidx]=sscanf(astr,'%f,',[1,inf]);%#ok
        	if(nextidx>=length(astr)-1)
                    object=obj;
                    LOADJSON_pos=endpos;
                    parse_char(inStr, ']');
                    return;
        	end
            end

            try
              if(~isempty(dim2))
        	astr=arraystr;
        	astr(astr=='[')='';
        	astr(astr==']')='';
                astr=regexprep(astr,'\s*$','');
        	astr(astr==' ')='';
        	[obj, count, errmsg, nextidx]=sscanf(astr,'%f,',inf);%#ok
        	if(nextidx>=length(astr)-1)
                    object=reshape(obj,dim2,numel(obj)/dim2)';
                    LOADJSON_pos=endpos;
                    parse_char(inStr, ']');
                    if(pbar>0)
                        waitbar(LOADJSON_pos/length(inStr),pbar,'loading ...');
                    end
                    return;
        	end
              end
              arraystr=regexprep(arraystr,'\]\s*,','];');
            catch
            end
	else
            arraystr='[';
	end
        try
           arraystr=regexprep(arraystr,'^\s*\[','{','once');
           arraystr=regexprep(arraystr,'\]\s*$','}','once');
           if(LOADJSON_isoct && regexp(arraystr,'"','once'))
                error('Octave eval can produce empty cells for JSON-like input');
           end
           object=eval(arraystr);
           LOADJSON_pos=endpos;
        catch
         while 1
            newopt=varargin2struct(varargin{:},'JSONLAB_ArrayDepth_',arraydepth+1);
            val = parse_value(inStr, esc, newopt);
            object{end+1} = val;%#ok
            if next_char(inStr) == ']'
                break;
            end
            parse_char(inStr, ',');
         end
        end
    end
    if(jsonopt('SimplifyCell',0,varargin{:})==1)
      try
        oldobj=object;
        object=cell2mat(object')';
        if(iscell(oldobj) && isstruct(object) && numel(object)>1 && jsonopt('SimplifyCellArray',1,varargin{:})==0)
            object=oldobj;
        elseif(size(object,1)>1 && ismatrix(object))
            object=object';
        end
      catch
      end
    end
    parse_char(inStr, ']');
    
    if(pbar>0)
        waitbar(LOADJSON_pos/length(inStr),pbar,'loading ...');
    end
%%-------------------------------------------------------------------------

function parse_char(inStr, c)
    global LOADJSON_pos
    LOADJSON_pos=skip_whitespace(LOADJSON_pos, inStr);
    if LOADJSON_pos > length(inStr) || inStr(LOADJSON_pos) ~= c
        error_pos(sprintf('Expected %c at position %%d', c),inStr);
    else
        LOADJSON_pos = LOADJSON_pos + 1;
        LOADJSON_pos=skip_whitespace(LOADJSON_pos, inStr);
    end

%%-------------------------------------------------------------------------

function c = next_char(inStr)
    global LOADJSON_pos
    LOADJSON_pos=skip_whitespace(LOADJSON_pos, inStr);
    if LOADJSON_pos > length(inStr)
        c = [];
    else
        c = inStr(LOADJSON_pos);
    end

%%-------------------------------------------------------------------------

function newpos=skip_whitespace(pos, inStr)
    newpos=pos;
    while newpos <= length(inStr) && isspace(inStr(newpos))
        newpos = newpos + 1;
    end

%%-------------------------------------------------------------------------
function str = parseStr(inStr, esc, varargin)
    global LOADJSON_pos LOADJSON_index_esc
 % len, ns = length(inStr), keyboard
    if inStr(LOADJSON_pos) ~= '"'
        error_pos('String starting with " expected at position %d',inStr);
    else
        LOADJSON_pos = LOADJSON_pos + 1;
    end
    str = '';
    while LOADJSON_pos <= length(inStr)
        while LOADJSON_index_esc <= length(esc) && esc(LOADJSON_index_esc) < LOADJSON_pos
            LOADJSON_index_esc = LOADJSON_index_esc + 1;
        end
        if LOADJSON_index_esc > length(esc)
            str = [str inStr(LOADJSON_pos:end)];%#ok
            LOADJSON_pos = length(inStr) + 1;
            break;
        else
            str = [str inStr(LOADJSON_pos:esc(LOADJSON_index_esc)-1)];%#ok
            LOADJSON_pos = esc(LOADJSON_index_esc);
        end
        nstr = length(str);
        switch inStr(LOADJSON_pos)
            case '"'
                LOADJSON_pos = LOADJSON_pos + 1;
                if(~isempty(str))
                    if(strcmp(str,'_Inf_'))
                        str=Inf;
                    elseif(strcmp(str,'-_Inf_'))
                        str=-Inf;
                    elseif(strcmp(str,'_NaN_'))
                        str=NaN;
                    end
                end
                return;
            case '\'
                if LOADJSON_pos+1 > length(inStr)
                    error_pos('End of file reached right after escape character',inStr);
                end
                LOADJSON_pos = LOADJSON_pos + 1;
                switch inStr(LOADJSON_pos)
                    case {'"' '\' '/'}
                        str(nstr+1) = inStr(LOADJSON_pos);
                        LOADJSON_pos = LOADJSON_pos + 1;
                    case {'b' 'f' 'n' 'r' 't'}
                        str(nstr+1) = sprintf(['\' inStr(LOADJSON_pos)]);
                        LOADJSON_pos = LOADJSON_pos + 1;
                    case 'u'
                        if LOADJSON_pos+4 > length(inStr)
                            error_pos('End of file reached in escaped unicode character',inStr);
                        end
                        str(nstr+(1:6)) = inStr(LOADJSON_pos-1:LOADJSON_pos+4);
                        LOADJSON_pos = LOADJSON_pos + 5;
                end
            otherwise % should never happen
                str(nstr+1) = inStr(LOADJSON_pos);
                keyboard;
                LOADJSON_pos = LOADJSON_pos + 1;
        end
    end
    error_pos('End of file while expecting end of inStr',inStr);

%%-------------------------------------------------------------------------

function num = parse_number(inStr, varargin)
    global LOADJSON_pos LOADJSON_isoct
    currstr=inStr(LOADJSON_pos:min(LOADJSON_pos+30,end));
    if(LOADJSON_isoct~=0)
        numstr=regexp(currstr,'^\s*-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+\-]?\d+)?','end');
        [num] = sscanf(currstr, '%f', 1);
        delta=numstr+1;
    else
        [num, one, err, delta] = sscanf(currstr, '%f', 1);%#ok
        if ~isempty(err)
            error_pos('Error reading number at position %d',inStr);
        end
    end
    LOADJSON_pos = LOADJSON_pos + delta-1;

%%-------------------------------------------------------------------------

function val = parse_value(inStr, esc, varargin)
    global LOADJSON_pos
    len=length(inStr);
    if(isfield(varargin{1},'progressbar_'))
        waitbar(LOADJSON_pos/len,varargin{1}.progressbar_,'loading ...');
    end
    
    switch(inStr(LOADJSON_pos))
        case '"'
            val = parseStr(inStr, esc, varargin{:});
            return;
        case '['
            val = parse_array(inStr, esc, varargin{:});
            return;
        case '{'
            val = parse_object(inStr, esc, varargin{:});
            return;
        case {'-','0','1','2','3','4','5','6','7','8','9'}
            val = parse_number(inStr, varargin{:});
            return;
        case 't'
            if LOADJSON_pos+3 <= len && strcmpi(inStr(LOADJSON_pos:LOADJSON_pos+3), 'true')
                val = true;
                LOADJSON_pos = LOADJSON_pos + 4;
                return;
            end
        case 'f'
            if LOADJSON_pos+4 <= len && strcmpi(inStr(LOADJSON_pos:LOADJSON_pos+4), 'false')
                val = false;
                LOADJSON_pos = LOADJSON_pos + 5;
                return;
            end
        case 'n'
            if LOADJSON_pos+3 <= len && strcmpi(inStr(LOADJSON_pos:LOADJSON_pos+3), 'null')
                val = [];
                LOADJSON_pos = LOADJSON_pos + 4;
                return;
            end
    end
    error_pos('Value expected at position %d',inStr);
%%-------------------------------------------------------------------------

function error_pos(msg, inStr)
    global LOADJSON_pos LOADJSON_len
    poShow = max(min([LOADJSON_pos-15 LOADJSON_pos-1 LOADJSON_pos LOADJSON_pos+20],LOADJSON_len),1);
    if poShow(3) == poShow(2)
        poShow(3:4) = poShow(2)+[0 -1];  % display nothing after
    end
    msg = [sprintf(msg, LOADJSON_pos) ': ' ...
    inStr(poShow(1):poShow(2)) '<error>' inStr(poShow(3):poShow(4)) ];
    error( ['JSONparser:invalidFormat: ' msg] );

%%-------------------------------------------------------------------------

function str = valid_field(str)
global LOADJSON_isoct
% From MATLAB doc: field names must begin with a letter, which may be
% followed by any combination of letters, digits, and underscores.
% Invalid characters will be converted to underscores, and the prefix
% "x0x[Hex code]_" will be added if the first character is not a letter.
    pos=regexp(str,'^[^A-Za-z]','once');
    if(~isempty(pos))
        if(~LOADJSON_isoct && str(1)+0 > 255)
            str=regexprep(str,'^([^A-Za-z])','x0x${sprintf(''%X'',unicode2native($1))}_','once');
        else
            str=sprintf('x0x%X_%s',char(str(1)),str(2:end));
        end
    end
    if(isempty(regexp(str,'[^0-9A-Za-z_]', 'once' )))
        return;
    end
    if(~LOADJSON_isoct)
        str=regexprep(str,'([^0-9A-Za-z_])','_0x${sprintf(''%X'',unicode2native($1))}_');
    else
        pos=regexp(str,'[^0-9A-Za-z_]');
        if(isempty(pos))
            return;
        end
        str0=str;
        pos0=[0 pos(:)' length(str)];
        str='';
        for i=1:length(pos)
            str=[str str0(pos0(i)+1:pos(i)-1) sprintf('_0x%X_',str0(pos(i)))];%#ok
        end
        if(pos(end)~=length(str))
            str=[str str0(pos0(end-1)+1:pos0(end))];
        end
    end
    %str(~isletter(str) & ~('0' <= str & str <= '9')) = '_';

%%-------------------------------------------------------------------------
function endpos = matching_quote(str,pos)
len=length(str);
while(pos<len)
    if(str(pos)=='"')
        if(~(pos>1 && str(pos-1)=='\'))
            endpos=pos;
            return;
        end        
    end
    pos=pos+1;
end
error('unmatched quotation mark');
%%-------------------------------------------------------------------------
function [endpos, e1l, e1r, maxlevel] = matching_bracket(str,pos)
global LOADJSON_arraytoken
level=1;
maxlevel=level;
endpos=0;
bpos=LOADJSON_arraytoken(LOADJSON_arraytoken>=pos);
tokens=str(bpos);
len=length(tokens);
pos=1;
e1l=[];
e1r=[];
while(pos<=len)
    c=tokens(pos);
    if(c==']')
        level=level-1;
        if(isempty(e1r))
            e1r=bpos(pos);
        end
        if(level==0)
            endpos=bpos(pos);
            return
        end
    end
    if(c=='[')
        if(isempty(e1l))
            e1l=bpos(pos);
        end
        level=level+1;
        maxlevel=max(maxlevel,level);
    end
    if(c=='"')
        pos=matching_quote(tokens,pos+1);
    end
    pos=pos+1;
end
if(endpos==0) 
    error('unmatched "]"');
end
function val=jsonopt(key,default,varargin)
%
% val=jsonopt(key,default,optstruct)
%
% setting options based on a struct. The struct can be produced
% by varargin2struct from a list of 'param','value' pairs
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
%
% $Id: loadjson.m 371 2012-06-20 12:43:06Z fangq $
%
% input:
%      key: a string with which one look up a value from a struct
%      default: if the key does not exist, return default
%      optstruct: a struct where each sub-field is a key 
%
% output:
%      val: if key exists, val=optstruct.key; otherwise val=default
%
% license:
%     BSD License, see LICENSE_BSD.txt files for details
%
% -- this function is part of jsonlab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
% 

val=default;
if(nargin<=2)
    return;
end
opt=varargin{1};
if(isstruct(opt))
    if(isfield(opt,key))
       val=getfield(opt,key);%#ok
    elseif(isfield(opt,lower(key)))
       val=getfield(opt,lower(key));%#ok
    end
end
function s=mergestruct(s1,s2)
%
% s=mergestruct(s1,s2)
%
% merge two struct objects into one
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% date: 2012/12/22
%
% input:
%      s1,s2: a struct object, s1 and s2 can not be arrays
%
% output:
%      s: the merged struct object. fields in s1 and s2 will be combined in s.
%
% license:
%     BSD License, see LICENSE_BSD.txt files for details 
%
% -- this function is part of jsonlab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

if(~isstruct(s1) || ~isstruct(s2))
    error('input parameters contain non-struct');
end
if(length(s1)>1 || length(s2)>1)
    error('can not merge struct arrays');
end
fn=fieldnames(s2);
s=s1;
for i=1:length(fn)              
    s=setfield(s,fn{i},getfield(s2,fn{i}));%#ok
end

function newdata=struct2jdata(data,varargin)
%
% newdata=struct2jdata(data,opt,...)
%
% convert a JData object (in the form of a struct array) into an array
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      data: a struct array. If data contains JData keywords in the first
%            level children, these fields are parsed and regrouped into a
%            data object (arrays, trees, graphs etc) based on JData 
%            specification. The JData keywords are
%               "_ArrayType_", "_ArraySize_", "_ArrayData_"
%               "_ArrayIsSparse_", "_ArrayIsComplex_"
%      opt: (optional) a list of 'Param',value pairs for additional options 
%           The supported options include
%               'Recursive', if set to 1, will apply the conversion to 
%                            every child; 0 to disable
%
% output:
%      newdata: the covnerted data if the input data does contain a JData 
%               structure; otherwise, the same as the input.
%
% examples:
%      obj=struct('_ArrayType_','double','_ArraySize_',[2 3],
%                 '_ArrayIsSparse_',1 ,'_ArrayData_',null);
%      ubjdata=struct2jdata(obj);
%
% license:
%     BSD License, see LICENSE_BSD.txt files for details 
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

fn=fieldnames(data);
newdata=data;
len=length(data);
if(jsonopt('Recursive',0,varargin{:})==1)
  for i=1:length(fn) % depth-first
    for j=1:len
        if(isstruct(getfield(data(j),fn{i})))%#ok
            newdata(j)=setfield(newdata(j),fn{i},jstruct2array(getfield(data(j),fn{i})));%#ok
        end
    end
  end
end
if(~isempty(strmatch('x0x5F_ArrayType_',fn)) && ~isempty(strmatch('x0x5F_ArrayData_',fn)))%#ok
  newdata=cell(len,1);
  for j=1:len
    ndata=cast(data(j).x0x5F_ArrayData_,data(j).x0x5F_ArrayType_);
    iscpx=0;
    if(~isempty(strmatch('x0x5F_ArrayIsComplex_',fn)))%#ok
        if(data(j).x0x5F_ArrayIsComplex_)
           iscpx=1;
        end
    end
    if(~isempty(strmatch('x0x5F_ArrayIsSparse_',fn)))%#ok
        if(data(j).x0x5F_ArrayIsSparse_)
            if(~isempty(strmatch('x0x5F_ArraySize_',fn)))%#ok
                dim=double(data(j).x0x5F_ArraySize_);
                if(iscpx && size(ndata,2)==4-any(dim==1))
                    ndata(:,end-1)=complex(ndata(:,end-1),ndata(:,end));
                end
                if isempty(ndata)
                    % All-zeros sparse
                    ndata=sparse(dim(1),prod(dim(2:end)));
                elseif dim(1)==1
                    % Sparse row vector
                    ndata=sparse(1,ndata(:,1),ndata(:,2),dim(1),prod(dim(2:end)));
                elseif dim(2)==1
                    % Sparse column vector
                    ndata=sparse(ndata(:,1),1,ndata(:,2),dim(1),prod(dim(2:end)));
                else
                    % Generic sparse array.
                    ndata=sparse(ndata(:,1),ndata(:,2),ndata(:,3),dim(1),prod(dim(2:end)));
                end
            else
                if(iscpx && size(ndata,2)==4)
                    ndata(:,3)=complex(ndata(:,3),ndata(:,4));
                end
                ndata=sparse(ndata(:,1),ndata(:,2),ndata(:,3));
            end
        end
    elseif(~isempty(strmatch('x0x5F_ArraySize_',fn)))%#ok
        if(iscpx && size(ndata,2)==2)
             ndata=complex(ndata(:,1),ndata(:,2));
        end
        ndata=reshape(ndata(:),data(j).x0x5F_ArraySize_);
    end
    newdata{j}=ndata;
  end
  if(len==1)
      newdata=newdata{1};
  end
end
function opt=varargin2struct(varargin)
%
% opt=varargin2struct('param1',value1,'param2',value2,...)
%   or
% opt=varargin2struct(...,optstruct,...)
%
% convert a series of input parameters into a structure
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% date: 2012/12/22
%
% input:
%      'param', value: the input parameters should be pairs of a string and a value
%       optstruct: if a parameter is a struct, the fields will be merged to the output struct
%
% output:
%      opt: a struct where opt.param1=value1, opt.param2=value2 ...
%
% license:
%     BSD License, see LICENSE_BSD.txt files for details 
%
% -- this function is part of jsonlab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

len=length(varargin);
opt=struct;
if(len==0)
    return;
end
i=1;
while(i<=len)
    if(isstruct(varargin{i}))
        opt=mergestruct(opt,varargin{i});
    elseif(ischar(varargin{i}) && i<len)
        opt=setfield(opt,lower(varargin{i}),varargin{i+1});%#ok
        i=i+1;
    else
        error('input must be in the form of ...,''name'',value,... pairs or structs');
    end
    i=i+1;
end

