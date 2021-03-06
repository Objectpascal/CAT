%% Method browseVars

function [vardata,varname] = browseVars(classfilter)

% browseVars
%
% This function allows to browse for variables in the workspace and
% additionally explore structures saved there.
%
% The basic usage is:
% [vardata,varname] = browseVars(classfilter)
%
% This will open a small gui that allows you to import the data stored in 
% the variable you selected into the new variable vardata. varname is the
% name of the imported variable stored as a string.
%
% The variable classfilter is either a string or a cell array of strings,
% allowing you to define the types of variables you would like to filter.
% To make a simple example:
% 
% whos
%  Name         Size            Bytes  Class              Attributes
% 
%  fun          1x1                32  function_handle                                                 
%  x            1x1                 8  double                       
% 
% y = browseVars('double') -> will only list variable x
% SEE ALSO
% CAT, CATTube

% Copyright 2015-2016 David Ochsenbein
% Copyright 2012-2014 David Ochsenbein, Martin Iggland
% 
% This file is part of CAT.
% 
% CAT is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
% 
% CAT is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.


if nargin == 0 || isempty(classfilter)
    classfilter = {};
else
    % Check if classfilter is char or cell - convert to cell
    if ischar(classfilter)
        classfilter = {classfilter 'struct'};
    else
        classfilter = [classfilter 'struct'];
    end % if
end % if else

% Create a new window for the list
glb.fighandle = figure(...
    'MenuBar','none',...
    'Name','Import a variable',...
    'NumberTitle','off',...
    'Position',[200 200 400 400],...
    'CloseRequestFcn', @browseVars_closereq,...
    'Resize','off');

% Create a list box
glb.lbox = uicontrol(glb.fighandle,...
    'Style','listbox',...
    'String','',...
    'Max',1,...
    'Min',0,...
    'Units','pixels',...
    'Callback',@(hObject,Event)varDetails(hObject,Event),...
    'Position',[10 10 260 380]);

% Update its contents
refreshList();

% Create import button
glb.import = uicontrol(glb.fighandle,...
    'Style','pushbutton',...
    'String','Import',...
    'Units','pixels',...
    'Callback',@(hObject,Event)setVar(hObject,Event),...
    'Position',[280 360 110 30]);

% Create text box for variable details
glb.text = uicontrol(glb.fighandle,...
    'Style','text',...
    'String','',...
    'Units','pixels',...
    'BackgroundColor',get(glb.fighandle,'Color'),...
    'Position',[280 320 110 30]);

if ~isempty(glb.Vvis(1).name)
    varDetails([],[]);
end

% Create refresh button
glb.refresh = uicontrol(glb.fighandle,...
    'Style','pushbutton',...
    'String','Refresh',...
    'Units','pixels',...
    'Callback',@(hObject,Event)refreshList(hObject,Event),...
    'Position',[280 260 110 30]);

uiwait

    function refreshList(~,~)
        if isfield(glb,'V')
            glb = rmfield(glb,'V');
        end
        glb.V = getVarList;
        updateVarList();
        
    end

    function [V,Vvis] = getVarList(~,~,unHideSwitch)
        
        if nargin<3
            unHideSwitch = [];
        end
        
        % Get variable list
        varList = evalin('base','who');
        varList = varList(~strcmp('varList',varList) & ~strcmp('activeList',varList));
        varList = [varList repmat({''},size(varList)) num2cell([1:length(varList)]') repmat({0},size(varList))];
        activeList = varList;
        id = length(varList(:,1));
        % if there are structures, whose fields may contain the necessary
        % data, we should be aware of this... therefore let's first explore
        % all structures in the workspace and create a list of all
        % variables, also those 'hidden' in structures
        while ~isempty(activeList)
            if isa(evalin('base',[activeList{1,2},activeList{1,1}]),'struct')
                for i = 1:length(evalin('base',[activeList{1,2},activeList{1,1}]))
                    if length(evalin('base',[activeList{1,2},activeList{1,1}]))>1
                        li = length(evalin('base',[activeList{1,2},activeList{1,1}]));
                        indstr = ['(',num2str(i),')'];
                    else
                        li = 1;
                        indstr = '';
                    end
                    fields = fieldnames(evalin('base',[activeList{1,2},activeList{1,1},indstr]));
                    varList = [varList; fields repmat({[activeList{1,2},activeList{1,1},indstr,'.']},[length(fields) 1]) num2cell(id+(1:length(fields))') repmat({activeList{1,3}+(i-1)*1/li},[length(fields) 1])];
                    activeList = [activeList; fields repmat({[activeList{1,2},activeList{1,1},indstr,'.']},[length(fields) 1]) num2cell(id+(1:length(fields))') repmat({activeList{1,3}+(i-1)*1/li},[length(fields) 1])];
                    id = id+length(fields);
                end
            end
            activeList(1,:) = [];

        end
        
        
        % If filters defined, keep only those class types listed
        if ~isempty(classfilter)
            Vname = cell(0);Vidparent = zeros(0,2);
            for i = 1:length(classfilter)
                for j = 1:length(varList(:,1))
                   if isa(evalin('base',[varList{j,2},varList{j,1}]),classfilter{i})
                       Vname = [Vname;[varList{j,2},varList{j,1}]];
                       Vidparent = [Vidparent; varList{j,3} varList{j,4}];
                   end
                end
            end % for
        else
            Vname = cell(0);Vidparent = zeros(0,2);
            for j = 1:length(varList(:,1))
                Vname = [Vname;[varList{j,2},varList{j,1}]];
                Vidparent = [Vidparent; varList{j,3} varList{j,4}];
            end
        end % if
        V = struct('name',[],'class',[],'size',[],'depth',[],'id',[],'parent',[],'hiddenFlag',[]); % structure containing all allowed variables and additional information about them
        if ~isempty(Vname)
            % Reorder items according to our own rules
            parents = Vidparent(Vidparent(:,end) == 0,1);
            Inew = parents(:)';
            while ~isempty(parents)
                children = Vidparent(parents(1)==floor(Vidparent(:,2)),:);
                children = sortrows(children,2);
                children = children(:,1);
                I = find(Inew==parents(1));
                Iloc = Inew(1:I);
                Inew(1:I) = [];
                Iloc = [Iloc children(:)' Inew];
                Inew = Iloc;
                parents = [parents(:)' children(:)'];
                parents(1) = [];
            end
            for i = 1:length(Inew)
                Vname2{i} = Vname{Vidparent(:,1) == Inew(i)};
                Vidparent2(i,:) = Vidparent(Vidparent(:,1) == Inew(i),:);
            end
            Vname = Vname2(:);
            Vidparent = Vidparent2;

            for i = 1:length(Vname)
               V(i).name = Vname{i};
               if ~isfield(glb,'V') && any(Vidparent(:,2)==Vidparent(i,1)) || (isfield(glb,'V') && isempty(glb.V(1).name))
                  V(i).name = [V(i).name,'+']; 
               elseif isfield(glb,'V')
                   V(i).name = glb.V(i).name;
               end
               V(i).class = class(evalin('base',Vname{i}));
               V(i).size = size(evalin('base',Vname{i}));
               V(i).depth = length(strfind(Vname{i},'.'));
               V(i).id = Vidparent(i,1);
               V(i).parent = Vidparent(i,2);


               if ~isfield(glb,'V') && V(i).depth==0 || (isfield(glb,'V') && isempty(glb.V(1).name))
                   V(i).hiddenFlag = 0;
               elseif ~isfield(glb,'V') && V(i).depth>0
                   V(i).hiddenFlag = 1;
               else
                   V(i).hiddenFlag = glb.V(i).hiddenFlag;
               end
            end

            Vvis =  V([V.hiddenFlag] == 0); % structure containing all currently visible variables
            
            % change status of their hiddenFlag if double clicked
            for i = 1:length(Vvis)
               if any(unHideSwitch==i)
                   if ~isempty(strfind(V([V.id]==Vvis(i).id).name,'+'))
                        V([V.id]==Vvis(i).id).name = strrep(V([V.id]==Vvis(i).id).name,'+','-');
                   else
                        V([V.id]==Vvis(i).id).name = strrep(V([V.id]==Vvis(i).id).name,'-','+');
                   end

                   for jj = 1:length(V)
                       if floor(V(jj).parent) == Vvis(i).id
                        V(jj).hiddenFlag = ~glb.V(jj).hiddenFlag;
                       end
                   end
               end
            end

            for i = 1:length(V)
               if V(i).parent ~=0 && V([V.id]==floor(V(i).parent)).hiddenFlag == 1
                   V(i).hiddenFlag = 1;
                   V(i).name = strrep(V(i).name,'-','+');
               end
            end

            for i = 1:length(V)
               if V(i).parent ~=0 && (V([V.id] == floor(V(i).parent)).hiddenFlag ==1 || V(i).hiddenFlag == 1)
                   V(i).name = strrep(V(i).name,'-','+');
               end
            end

            Vvis =  V([V.hiddenFlag] == 0); % update visible list
            if isempty(strrep([V.class],'struct',''))
                Vvis = struct('name',[],'class',[],'size',[],'depth',[],'id',[],'parent',[],'hiddenFlag',[]);
                
            end
            
        else
            V = struct('name',[],'class',[],'size',[],'depth',[],'id',[],'parent',[],'hiddenFlag',[]);
            Vvis = struct('name',[],'class',[],'size',[],'depth',[],'id',[],'parent',[],'hiddenFlag',[]);
        end
    end % function getVarList

    function updateVarList(~,~,unHideSwitch)
        
        if nargin<3
           unHideSwitch = []; 
        end
        
        [glb.V,glb.Vvis] = getVarList([],[],unHideSwitch);
        
        
        varnames = [{glb.Vvis.name}']; %#ok<NBRAK>
        j = 1;
        finalvarnames = cell(0);
        for i =1:length(varnames)
           if ~glb.Vvis(i).hiddenFlag
            finalvarnames{j} = [repmat('  ',[1 glb.Vvis(i).depth]),varnames{i}];
            j = j+1;
           end
        end
        
        set(glb.lbox,'String',finalvarnames);
        
    end % function updateVarList

    function varDetails(hObject,~)
        
        if isfield(glb,'Vvis') && ~isempty(glb.Vvis(1).name)
            % Find selected variable
            if ~isempty(hObject)
                varnum = get(hObject,'Value');
            else
                varnum = 1;
            end

            % Make string for description of this variable
            % Output something like:
            % a
            % 2x3 double

            vname = sprintf('%s\n',glb.Vvis(varnum).name);
            if length(glb.Vvis(varnum).size) == 2
                vsize = sprintf('%ix%i',glb.Vvis(varnum).size);
            else %multidimensional
                vsize = sprintf('%ix%ix...',glb.Vvis(varnum).size(1:2));
            end % if else

            vtext = sprintf('%s %s %s',vname,vsize,glb.Vvis(varnum).class);

            % Print variable details
            set(glb.text,'String',vtext);

            %Check if the currently chosen variable is a structure... we cant
            %import structures
            varNaked = strrep(glb.Vvis(varnum).name,'+','');
            varNaked = strrep(varNaked,'-','');

            if isstruct(evalin('base',varNaked))
                set(glb.import,'enable','off');
            else
                set(glb.import,'enable','on');
            end

            if (strcmp(get(glb.fighandle, 'SelectionType'), 'open')) % if double click
                updateVarList([],[],get(glb.lbox,'value'));
            end
        end
        
    end % function

    function setVar(hObject,~)
        
        % Get the chosen variable number
        varnum = get(glb.lbox,'Value');
        
        % Assign the corresponding CAT variable to the chosen variable
        % Get variable data
        if varnum <= length(glb.Vvis)
            vardata = evalin('base',[glb.Vvis(varnum).name]);
            varname = glb.Vvis(varnum).name;
            
            % Close the variable list window
            close(get(hObject,'Parent'))
            
            
        end % if
        
    end % function

    function browseVars_closereq(~,~) % browseVars_closereq
       
       % if window is closed and no variable is imported, default return is
       % empty
       if ~exist('varname','var')
           vardata = [];
           varname = [];
       end
       
       delete(glb.fighandle) 
       
    end

end % function