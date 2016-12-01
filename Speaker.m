classdef Speaker < hgsetget
    % ---------------------------------------------------------------------
    % Speaker
    % Han Lab
    % 7/11/2011
    % Mark Bucklin
    % ---------------------------------------------------------------------
    %
    % This class creates an analog output using the sound-card to control
    % speakers.
    % 
    % See Also TOUCHDISPLAY BEHAVIORBOX NIDAQINTERFACE
    
    
    
    
    
    properties
        sampleRate
        default
    end
    properties (SetAccess='protected')
        analogOutput
        channel
        isready
        isplaying
    end
    
    
    
    
    events
    end
    
    
    
    
    methods % Initialization
        function obj = Speaker(varargin)
            % Assign input arguments to object properties
            if nargin > 1
                for k = 1:2:length(varargin)
                    obj.(varargin{k}) = varargin{k+1};
                end
            end
            % Define Defaults
            obj.default = struct(...
                'sampleRate',44100);
            obj.isready = false;
            obj.isplaying = false;
        end
        function setup(obj)
            global NUMSPEAKERS
            if isempty(NUMSPEAKERS)
                NUMSPEAKERS = 0;
            end
            % Fill in Defaults
            props = fields(obj.default);
            for n=1:length(props)
                thisprop = sprintf('%s',props{n});
                if isempty(obj.(thisprop))
                    obj.(thisprop) = obj.default.(thisprop);
                end
            end
            % Construct Analog Output
            obj.analogOutput = analogoutput('winsound');
            aoinfo = daqhwinfo(obj.analogOutput);
            channum = aoinfo.ChannelIDs(NUMSPEAKERS+1);
            obj.channel = addchannel(obj.analogOutput,channum);
            set(obj.analogOutput,...
                'SampleRate',obj.sampleRate,...
                'TriggerType','Manual',...
                'StopFcn',@(src,evnt)speakerStopFcn(obj,src,evnt))
            obj.sampleRate = get(obj.analogOutput,'SampleRate'); 
            NUMSPEAKERS = NUMSPEAKERS +1;
            obj.isready = true;
        end
    end
    methods % User Functions
        function playTone(obj,freq,duration,volume)
            % Plays a tone at the specified frequency for the specified
            % duration and at the specified volume (0-1)
           if ~obj.isready
               setup(obj)
           end
           len = obj.sampleRate * duration;
           data = volume*sin(linspace(0,2*pi*freq,len))';
           while obj.isplaying
               pause(.001)
           end
           putdata(obj.analogOutput,data)
           start(obj.analogOutput);
           obj.isplaying = true;           
           trigger(obj.analogOutput);
        end
        function speakerStopFcn(obj,src,evnt)
           obj.isplaying = false; 
        end
    end
    methods % Cleanup
        function delete(obj)
            global NUMSPEAKERS
            delete(obj.analogOutput)
            NUMSPEAKERS = NUMSPEAKERS - 1;
        end
    end
    
end
















