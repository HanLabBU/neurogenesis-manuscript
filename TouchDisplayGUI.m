classdef TouchDisplayGUI < hgsetget
    % ---------------------------------------------------------------------
    % TouchDisplayGUI
    % Han Lab
    % 7/11/2011
    % Mark Bucklin
    % ---------------------------------------------------------------------
    %
    % This class creates a simple GUI that enables the user to control
    % stimulus on/off state and calibration
    %
    % See Also TOUCHDISPLAY RECTANGLE POSITIONDATA
  
  
  
  
  
  
  properties
    numStimuli
    touchDisplayObj %parent object    
  end
  properties (SetAccess = protected)
    hFig %figure handle of main GUI figure
    default %structure of settings, hardcoded in method: defineDefaults
    pos %structure of default positions
    stimControl %structure of handles to uicontrol objects and panels
  end
  
  
  
  
  
  
  
  methods
    function obj = TouchDisplayGUI(varargin)
      if nargin > 1
        for k = 1:2:length(varargin)
          obj.(varargin{k}) = varargin{k+1};
        end
      end
      if isempty(obj.numStimuli)
          obj.numStimuli = obj.touchDisplayObj.numStimuli;
      end
      obj.definePositionStructure();
      obj.defineDefaults();
      obj.buildFigure();
      set(obj.hFig,'HandleVisibility','callback',...
          'CloseRequestFcn',@(src,evnt)closeWindowFcn(obj,src,evnt));
    end
    function definePositionStructure(obj)
      sz = get(0,'MonitorPositions');
      if size(sz,1) > 1
        obj.pos.dualmonitor = true;
        obj.pos.rightmonwidth = sz(1,3)-sz(1,1);
        obj.pos.rightmonheight = sz(1,4);
        obj.pos.rightmonpos = sz(1,1:2);
        obj.pos.leftmonwidth = sz(2,3);
        obj.pos.leftmonheight = sz(2,4);
      else
        obj.pos.dualmonitor = false;
        obj.pos.monwidth = sz(1,3);
        obj.pos.monheight = sz(1,4);
      end
      obj.pos.sliderlength = 190;
      obj.pos.sliderwidth = 25;
      obj.pos.standard = [10 10];
      obj.pos.bigbutton = [90 30];
      obj.pos.medbutton = [60 20];
      obj.pos.smallbutton = [40 15];
      obj.pos.shorttext = [40 20];
      obj.pos.medtext = [60 20];
      obj.pos.longtext = [90 20];
      obj.pos.xlongtext = [120 20];
      if obj.pos.dualmonitor
        obj.pos.mainfig = [100 100 640 400];
      else
        obj.pos.mainfig = [100 100 640 400];
      end
    end
    function defineDefaults(obj)
        obj.default.numStimuli = 7;
    end
    function buildFigure(obj)
        % This function handles the creation/construction of the figure and
        % all its buttons, sliders, text-boxes, etc., and stores all the
        % returned handles in the stimControl property (a struct)
        
        % Initialize Figure
        obj.hFig = figure;
        set(obj.hFig,...
            'units','pixels',...
            'tag','stimcontrolfigure',...
            'menubar','none',...
            'name','Stimulus Control',...
            'numbertitle','off',...
            'resize','off',...
            'position',obj.pos.mainfig);
        % Stimulus Control Panels
        figwidth = obj.pos.mainfig(3); %pixels
        figheight = obj.pos.mainfig(4);
        panwidth = (1-.1-.025*(obj.numStimuli-1))/obj.numStimuli; %fractional
        panheight = .2;
        for n = 1:obj.numStimuli
            obj.stimControl.stimPanel(n) = uipanel(obj.hFig,...
                'position',...
                [(.05+(panwidth+.025)*(n-1)) .05 panwidth panheight],...
                'Title',sprintf('Stimulus %d',n));
            obj.stimControl.stimOnOff(n) = uicontrol(...
                obj.stimControl.stimPanel(n),...
                'style','togglebutton',...
                'tag',sprintf('onoff%d',n),...
                'units','normalized',...
                'position',[.05 .05 .9 .4],...
                'string','Show');
            obj.stimControl.calibrate(n) = uicontrol(...
                obj.stimControl.stimPanel(n),...
                'style','pushbutton',...
                'tag',sprintf('calibrate%d',n),...
                'units','normalized',...
                'position',[.05 .55 .9 .4],...
                'string','Calibrate');
        end
        set(obj.stimControl.stimOnOff,...
            'callback',@(src,evnt)stimOnOffFcn(obj,src,evnt));
        set(obj.stimControl.calibrate,...
            'callback',@(src,evnt)calibrateFcn(obj,src,evnt));
        % Stimulus Display Axis
            obj.stimControl.stimAxis = axes(...
                'parent',obj.hFig,...
                'position',[.1 .1+panheight .8 .85-panheight],...
                'DrawMode','fast',...
                'XTick',[],...
                'YTick',[],...
                'XLimMode','manual',...
                'YLimMode','manual',...
                'XLim',[0 4096],...
                'YLim',[0 4096],...
                'YDir','reverse');
    end
  end
  methods (Hidden) % UICONTROL RESPONSE
    function stimOnOffFcn(obj,src,evnt)
        persistent stimstates
        if isempty(stimstates)
            stimstates = zeros(1,obj.numStimuli);
        end
        tmp = get(src,'tag');
        stimnum = eval(tmp(end)); %e.g. 'onoff3'
        switch get(src,'value')
            case 1 % Turn stimulus ON
                stimstates(stimnum) = true;
                obj.touchDisplayObj.prepareNextStimulus(find(stimstates)) %puts stimulus into buffer
                obj.touchDisplayObj.showStimulus(); %puts stimulus on screen
                set(src,'string','Hide');
            case 0 % Turn stimulus OFF
                stimstates(stimnum) = false;
                if any(stimstates)
                    obj.touchDisplayObj.prepareNextStimulus(find(stimstates)) %puts stimulus into buffer
                    obj.touchDisplayObj.showStimulus(); %puts stimulus on screen
                else
                    obj.touchDisplayObj.hideStimulus();
                end
                set(src,'string','Show')
        end
    end
    function calibrateFcn(obj,src,evnt)
        tmp = get(src,'tag');
        stimnum = eval(tmp(end)); %e.g. 'calibrate3'
        rectObj = obj.touchDisplayObj.stimuli(stimnum);
        rectObj.calibratePosition();
    end
  end
  methods % CLEANUP
      function closeWindowFcn(obj,src,evnt)
          % User-defined close request function
          % to display a question dialog box
          selection = questdlg('Close This Figure?',...
              'Close Request Function',...
              'Yes','No','Yes');
          switch selection,
              case 'Yes',
                  delete(gcf)
              case 'No'
                  return
          end
      end
      function delete(obj)
          delete(obj.hFig)
      end
  end
  
  
  
  
  
  
end