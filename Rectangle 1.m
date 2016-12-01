classdef Rectangle < hgsetget
    % --------------------------------------------------------------------
    % Rectangle
    % Han Lab
    % 7/11/2011
    % Mark Bucklin
    % ---------------------------------------------------------------------
    %
    % This class represents a rectangle drawn on the monitor within the
    % behavior-box. An object of this class can be loaded onto the next
    % display and will send an event when it is poked via the touchscreen
    % 
    %
    % See Also TOUCHDISPLAY
    
    
    
    
    
    properties
        
        xPosition
        yPosition
        width
        height
        color
        name
        touchInterfaceObj
        calibrationListener
        touchInterfaceListener
        onscreen
        inbuffer
        calibrationFileDir
        calibrationFileName
        default
        inbuffersize
   
    end
    properties (SetAccess='protected')
       calibrationStruct
       rectOnAxes
       isready
       
    end
    
    
    
    
    events
        InBuffer
        StimPoke
        WrongPoke
        FalsePoke
    end
    
    
    
    
    methods % Initialization
        function obj = Rectangle(varargin)
            % Assign input arguments to object properties
            if nargin > 1
                for k = 1:2:length(varargin)
                    obj.(varargin{k}) = varargin{k+1};
                end
            end
            % Assign Unique Number
            global NUMRECTANGLES;
            if isempty(NUMRECTANGLES)
                NUMRECTANGLES = 1;
            else
                NUMRECTANGLES = NUMRECTANGLES+1;
            end            
            % Define Defaults
            obj.default = struct(...
                'xPosition', 0,...
                'yPosition', 0,...
                'width', 70,...
                'height', 70,...
                'color',[.7 .7 .7],...
                'name',strcat('rectangle',num2str(NUMRECTANGLES)),...
                'calibrationFileDir',...                
                fullfile('C:','MATLAB','BehaviorBox','settings',filesep));
            obj.isready = false;
            obj.inbuffer = false;
        end
        function setup(obj)
            try
                % Fill in Defaults
                props = fields(obj.default);
                for n=1:length(props)
                    thisprop = sprintf('%s',props{n});
                    if isempty(obj.(thisprop))
                        obj.(thisprop) = obj.default.(thisprop);
                    end
                end
                % Read from a calibration file
                obj.calibrationFileName = sprintf(...
                    'CalibrationFile_%s.mat',obj.name);
                fpath = fullfile(obj.calibrationFileDir,...
                    obj.calibrationFileName);
                if ~exist(fpath,'file') %remind user to calibrate using the GUI buttons
                    beep;
                    warndlg(sprintf('%s needs to be calibrated',obj.name));                    
                else
                    obj.calibrationStruct = load(fpath);
                end
                obj.touchInterfaceListener = addlistener(...
                    obj.touchInterfaceObj, 'TouchStart',...
                    @(src,evnt)touchStartFcn(obj,src,evnt));                              
            catch me
                disp(me.message)
                beep
                keyboard
            end
            obj.isready = true;
            obj.onscreen = false;
        end
        function add2Axis(obj,hAxis)
            if isempty(obj.calibrationStruct) ... %if it hasn't been calibrated yet
                    || isempty(obj.calibrationStruct.xRange)
                warning('Rectangle:add2Axis:NotCalibrated',...
                    '%s needs to be calibrated before adding to the axis',obj.name);
                return
            end
            cornerpos = [obj.calibrationStruct.xRange(1) obj.calibrationStruct.yRange(1)];
            widheight = [obj.calibrationStruct.xRange(2) obj.calibrationStruct.yRange(2)]...
                - cornerpos;
            obj.rectOnAxes = rectangle('parent',hAxis,...
                'Position',[cornerpos widheight],...
                'LineWidth',2);
        end
        function calibratePosition(obj)
            if ~isempty(obj.touchInterfaceListener)
                obj.touchInterfaceListener.Enabled = false;
            end
            obj.calibrationStruct = struct(...
                'center',[],...
                'xRange',[],...
                'yRange',[]);
            if isempty(obj.calibrationListener)
                obj.calibrationListener = addlistener(...
                    obj.touchInterfaceObj, 'TouchData',...
                    @(src,evnt)touchCalibrationFcn(obj,src,evnt));
            else
                obj.calibrationListener.Enabled = true;
            end
            obj.add2Buffer();
            cgflip(0,0,0);
            obj.onscreen = false;
            h = msgbox('Trace the stimulus, press OK when finished');
            set(h,'DeleteFcn',@(src,evnt)endCalibration(obj,src,evnt));            
        end
        function touchCalibrationFcn(obj,src,evnt)
            pos = evnt.position;
            x = pos(1);
            y = pos(2);
            if isempty(obj.calibrationStruct.xRange)
                 xr = [x; x];
                 yr = [y; y];
            else
                xr = obj.calibrationStruct.xRange;
                yr = obj.calibrationStruct.yRange;
                xr(1) = min([xr;x]);
                xr(2) = max([xr;x]);
                yr(1) = min([yr;y]);
                yr(2) = max([yr;y]);
            end
            obj.calibrationStruct.xRange = xr(:);
            obj.calibrationStruct.yRange = yr(:);
            obj.calibrationStruct.center = [mean(xr(:)) mean(yr(:))];
        end
        function endCalibration(obj,src,evnt)
            % Save Calibration Structure
            if ~exist(obj.calibrationFileDir,'dir')
                mkdir(obj.calibrationFileDir);
            end
            calstruct = obj.calibrationStruct;
            fprintf('saving calibration file\n')
            save(fullfile(obj.calibrationFileDir,obj.calibrationFileName),...
                '-struct','calstruct','-v6');
            fprintf('calibration file saved\n%s\n',...
                fullfile(obj.calibrationFileDir,obj.calibrationFileName))
            % Clear Screen and Set Listeners Back to Normal
            cgflip(0,0,0);
            obj.calibrationListener.Enabled = false;
            obj.touchInterfaceListener.Enabled = true;
            if ~isempty(obj.rectOnAxes)
                hAxis = get(obj.rectOnAxes,'Parent');
                delete(obj.rectOnAxes)
                obj.add2Axis(hAxis)
            end
        end
        
    end
    methods % Display Functions
        function add2Buffer(obj)
            % Call this function to put the stimulus on the screen
            cgpencol(obj.color);
            cgrect(obj.xPosition, obj.yPosition, obj.width, obj.height);
            %notify(obj,'InBuffer');
            obj.inbuffer = true;
        end        
       
        function touchStartFcn(obj,src,evnt)
            if isempty(obj.calibrationStruct) ... %if it hasn't been calibrated yet
                    || isempty(obj.calibrationStruct.xRange)
                return
            end
            
            pos = evnt.position;
            x = pos(1);
            y = pos(2);
            %pos = evnt.position;% Xue modified to give more singals through buffer
            %x = pos(1);
            %y = pos(2);
            %pos = evnt.position;
            %x = pos(1);
            %y = pos(2);
            %pos = evnt.position;
            %x = pos(1);
            %y = pos(2);
            %pos = evnt.position;
            %x = pos(1);
            %y = pos(2);
           
            if any(x == obj.calibrationStruct.xRange(1):obj.calibrationStruct.xRange(2))...
                    && any(y == obj.calibrationStruct.yRange(1):obj.calibrationStruct.yRange(2))
                if obj.onscreen
                    fprintf('%s',datestr(now,'HH:MM:SS:FFF'))
                                        notify(obj,'StimPoke')
                                       
                                     
                    % change rectangle display color
                    if ~isempty(obj.rectOnAxes)
                        set(obj.rectOnAxes,'EdgeColor',[0 1 0])
                    end
                    fprintf('\tPoke: %s\n',obj.name)%%%JZ %DEBUGGING
                else
                    fprintf('%s',datestr(now,'HH:MM:SS:FFF'))
                    notify(obj,'FalsePoke')
                    if ~isempty(obj.rectOnAxes)
                        set(obj.rectOnAxes,'EdgeColor',[1 0 0])
                    end
                    fprintf('\tFalsePoke: %s\n',obj.name)%%%JZ %DEBUGGING
%                     flushinput(serial('COM1'));%%%JZ  
%                     flushinput(serial('COM3'));%%%JZ
%                     flushinput(serial('COM4'));%%%JZ
%                     SSS = get (obj, 'inbuffersize'); %%%JZ
%                     %fprintf (sss);%%%JZ
                end
            end
        end
    end
    methods % Cleanup
        function delete(obj)
            global NUMRECTANGLES
            NUMRECTANGLES = NUMRECTANGLES-1;
        end
    end
    
end
















