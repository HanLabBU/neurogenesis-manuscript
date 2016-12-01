classdef TouchDisplay < hgsetget
    % ---------------------------------------------------------------------
    % TouchDisplay
    % Han Lab
    % 7/11/2011
    % Mark Bucklin & Chun Hin Tang
    % ---------------------------------------------------------------------
    %
    % This class represents the touchscreen monitor used to present stimuli
    % to mice in the behavior box. It uses Cogent, a MATLAB graphics
    % toolbox available at http://www.vislab.ucl.ac.uk/cogent.php
    %
    % See Also TOUCHINTERFACE RECTANGLE
    
    
    
    
    
    properties
        resolution % e.g. [1920 1080]
        numStimuli
        rectSpacing
        rectWidth
        rectHeight
        monitorNumber
        default
        RecordName% record RS232 communication
    end
    properties (SetAccess = protected)
        stimuli
        touchInterfaceObj
        touchInterfaceListener
        controlGUI
        lineData
        lineObj
        isready
    end
    
    
    
    
    events
        StimulusOn
        StimulusOff
        ScreenPoke
    end
    
    
    
    
    methods % Initialization
        function obj = TouchDisplay(varargin)
            % Assign input arguments to object properties
            if nargin > 1
                for k = 1:2:length(varargin)
                    obj.(varargin{k}) = varargin{k+1};
                end
            end
            % Define Defaults
            s = get(0,'ScreenSize');
            obj.default = struct(...
                'resolution', [640 480],...
                'numStimuli', 7,...
                'rectSpacing', 85,...
                'rectWidth', 70,...
                'rectHeight', 70,...
                'monitorNumber',2);
            obj.stimuli = Rectangle.empty(1,0);
            obj.touchInterfaceObj = TouchInterface;
            obj.touchInterfaceListener = event.listener.empty(1,0);
            obj.isready = false;
        end
        function setup(obj)
            % Fill in Defaults
            props = fields(obj.default);
            for n=1:length(props)
                thisprop = sprintf('%s',props{n});
                if isempty(obj.(thisprop))
                    obj.(thisprop) = obj.default.(thisprop);
                end
            end
            
            % Initialize Cogent
            cgloadlib;
            cgopen(640,480,0,0,obj.monitorNumber);
            cgpencol(1,1,1); % (default square color)
            % Rectangle Making
            y = 70 - obj.resolution(2)/2; %height of rectangles 150 for higher, and 44 is for lower
            between_space = obj.rectSpacing-obj.rectWidth;
            for n = 1:obj.numStimuli
                x = between_space*(n-1) ... %strange thing happening
                    + obj.rectWidth/2 ...
                    + obj.rectWidth*(n-1) ...
                    - obj.resolution(1)/2 ...
                    + 8 ;% 19 for higher, 8 for lower
                obj.stimuli(n) = Rectangle(...
                    'xPosition',x,...
                    'yPosition',y,...
                    'width',obj.rectWidth,...
                    'height',obj.rectHeight,...
                    'touchInterfaceObj',obj.touchInterfaceObj);
                setup(obj.stimuli(n));
            end
            % Setup Touchscreen Interface
            setup(obj.touchInterfaceObj);
            obj.touchInterfaceListener(1) = addlistener(...
                obj.touchInterfaceObj, 'TouchStart',...
                @(src,evnt)touchStartFcn(obj,src,evnt));
            obj.touchInterfaceListener(2) = addlistener(...
                obj.touchInterfaceObj, 'TouchData',...
                @(src,evnt)touchDataFcn(obj,src,evnt));
            obj.touchInterfaceListener(3) = addlistener(...
                obj.touchInterfaceObj, 'TouchStop',...
                @(src,evnt)touchStopFcn(obj,src,evnt));
            % Create GUI for Calibration and Control
            obj.controlGUI = TouchDisplayGUI(...
                'touchDisplayObj',obj);
            ax = obj.controlGUI.stimControl.stimAxis;
            for n = 1:obj.numStimuli
                add2Axis(obj.stimuli(n),ax);%method in Rectangle class
            end
            obj.isready = true;
        end
    end
    methods % Display Functions
        function prepareNextStimulus(obj,varargin)
            % Use this method to specify which rectangles will be shown on
            % the screen specified by number from left to right, e.g. the
            % following statement would display the rectangles at the
            % outside of the screen and the center rectangle:
            % obj.prepareRectangleStimulus([1 4 7])            
            if ~obj.isready
                obj.setup();
            end
            % Error and Argument Checking
            if nargin<=1
                warning('BehaviorBox:TouchDisplay:showRectangles',...
                    'No rectangles were specified; all will be shown');
                rectnums = 1:obj.numStimuli;
            else
                rectnums = varargin{1};
            end
            if max(rectnums)>obj.numStimuli
                error('BehaviorBox:TouchDisplay:showRectangles',...
                    'rectangles specified don''t exist');
            end
            set(obj.stimuli,'inbuffer',false); %reset all stimuli
            for n = rectnums
                add2Buffer(obj.stimuli(n)); %active state set to true from within rectangle class
            end
        end
        function varargout = showStimulus(obj)
            % Call this function to put the stimulus on the screen once it
            % has been defined/specified with 'prepareRectangleStimulus'
            % method
            t = cgflip(0,0,0);
            %notify(obj,'StimulusOn');
            activestimuli = findobj(obj.stimuli,'inbuffer',true);
            set(activestimuli,'onscreen','false');
            if nargout>0
                varargout = t;
            end
        end
        function varargout = hideStimulus(obj)
            t = cgflip(0,0,0);
            cgflip(0,0,0) %called twice to make sure screen is blank
            set(obj.stimuli,'onscreen',false);
            %notify(obj,'StimulusOff');
            if nargout>0
                varargout = t;
            end
        end
    end
    methods % Touch Response Functions
        function touchStartFcn(obj,src,evnt)
            pos = evnt.position;
            %             fprintf('%s\tX:%d\tY:%d\n',...
            %                 evnt.EventName, pos(1),pos(2));
            obj.lineData = [pos(1) pos(2)];
            if ~isempty(obj.lineObj)
                delete(obj.lineObj)
            end
            obj.lineObj = line('parent',obj.controlGUI.stimControl.stimAxis,...
                'XData',[obj.lineData(:,1);obj.lineData(:,1)+1],...
                'YData',[obj.lineData(:,2);obj.lineData(:,2)+1],...
                'LineWidth',2,...
                'EraseMode','xor',...
                'LineStyle',':');
        end
        function touchDataFcn(obj,src,evnt)
            obj.lineData(end+1,:) = evnt.position(:)';
            set(obj.lineObj,...
                'XData',obj.lineData(:,1),...
                'YData',obj.lineData(:,2))
            %serialObj.RecordName = 'serialData.txt';%%JZ record the RS232 communication
            %record(serialObj)%%JZ record the RS232 communication
           
          
        end
        function touchStopFcn(obj,src,evnt)
            % Change rectangle display back to black
            if ~isempty(obj.stimuli(1).rectOnAxes)
                set([obj.stimuli(:).rectOnAxes],'EdgeColor',[0 0 0])
            end            
        end
    end
    methods % Set/Get
    end
    methods % Cleanup
        function delete(obj)
           cgshut
           delete(obj.controlGUI);
           delete(obj.touchInterfaceObj);
        end
    end
    
end
















