classdef BehaviorBox1 < hgsetget
    % ---------------------------------------------------------------------
    % BehaviorBox
    % Han Lab
    % 7/11/2011
    % Mark Bucklin
    % ---------------------------------------------------------------------
    %
    % This class defines experimental parameters (timing, stimulus, etc.)
    % and runs the experiment
    %
    % See Also TOUCHINTERFACE RECTANGLE TOUCHDISPLAY NIDAQINTERFACE
    
    
    
    
    
    properties
        stimOnTime
        interTrialInterval
        rewardTime
        punishTime
        stimSet % cell array of scalar vectors with stimulus numbers
        correctResponse
        stimOrder % 'random' or 'sequential'
        toneFrequency
        toneDuration
        toneVolume
        default
    end
    
    properties (SetAccess = protected)
        dataSummaryObj
        touchDisplayObj % TouchDisplay
        nidaqObj % NiDaqInterface
        speakerObj % Speaker
        nosePokeListener % Listens for nose-poke On/Off events from the reward chamber
        touchDisplayListener % Listens for any touch to the touch screen
        stimPokeListener % Listens for pokes to the stimulus (rectangle) while onscreen
        falsePokeListener % Listens for pokes to a stimulus while it is offscreen
        interTrialTimer
        stimulusTimer
        trialPhase % 'stopped' 'wait4poke' 'stimulus' 'reward' 'punish' 'intertrial'
        currentStim % scalar vector with the stimulus numbers being presented
        currentStimNumber
        mouseResponse
        isready
        mouseID
        ExperimentID
        stage
    end
    
    
    
    
    events
        TrialStart
        StimOn
        StimOff
        Reward % Correct
        Punish % Incorrect
        NoResponse % Abort/No-Attempt
        Wait4Poke
        Nosepoke
        Screen
       
    end
    
    
    
    
    methods % Initialization
        function obj = BehaviorBox1(varargin)
            % Assign input arguments to object properties
            if nargin > 1
                for k = 1:2:length(varargin)
                    obj.(varargin{k}) = varargin{k+1};
                end
            end
            % Define Defaults
            obj.default = struct(...
                'stimOnTime',.001,... % reward light will be on for 1 second
                'interTrialInterval',59.82,...
                'rewardTime',.34,... %JZ 3/5/2012 for SS4
                'punishTime',3,...
                'stimSet',{{[2 6]}},...
                'correctResponse',{{2}},...
                'stimOrder','sequential',...
                'toneFrequency',1100,...
                'toneDuration',.5,...
                'toneVolume',.5);
            obj.isready = false;
            obj.trialPhase = 'stopped';
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
            % Construct Touch-Display and Daq Interfaces
            obj.touchDisplayObj = TouchDisplay;
            setup(obj.touchDisplayObj);
            obj.nidaqObj = NiDaqInterface;
            setup(obj.nidaqObj)
            obj.speakerObj = Speaker;
            setup(obj.speakerObj);
            % Listen for Events            
            obj.nosePokeListener = event.listener.empty(2,0);
            obj.touchDisplayListener = event.listener.empty(1,0);
            obj.stimPokeListener = event.listener.empty(7,0);
            obj.falsePokeListener = event.listener.empty(7,0);
            obj.nosePokeListener(1) = addlistener(...
                obj.nidaqObj,...
                'NosePokeOn',...
                @(src,evnt)nosePokeFcn(obj,src,evnt));
            obj.nosePokeListener(2) = addlistener(...
                obj.nidaqObj,...
                'NosePokeOff',...
                @(src,evnt)nosePokeFcn(obj,src,evnt));
            obj.touchDisplayListener = addlistener(...
                obj.touchDisplayObj,...
                'ScreenPoke',...
                @(src,evnt)screenPokeFcn(obj,src,evnt));
            for n = 1:obj.touchDisplayObj.numStimuli
                obj.stimPokeListener(n) = addlistener(...
                    obj.touchDisplayObj.stimuli(n),...
                    'StimPoke',...
                    @(src,evnt)stimPokeFcn(obj,src,evnt));
                obj.falsePokeListener(n) = addlistener(...
                    obj.touchDisplayObj.stimuli(n),...
                    'FalsePoke',...
                    @(src,evnt)falsePokeFcn(obj,src,evnt));
            end
            % Construct Timer Objects
            obj.stimulusTimer = timer(...
                'StartFcn',@(src,evnt)startStimFcn(obj,src,evnt),...
                'StartDelay',obj.stimOnTime,...
                'TimerFcn',@(src,evnt)endStimFcn(obj,src,evnt),...
                'StopFcn',@(src,evnt)stopStimFcn(obj,src,evnt),...
                'TasksToExecute',1);
            obj.interTrialTimer = timer(...
                'StartFcn',@(src,evnt)startInterTrialFcn(obj,src,evnt),...
                'StartDelay',obj.interTrialInterval,...
                'TimerFcn',@(src,evnt)endInterTrialFcn(obj,src,evnt),...
                'TasksToExecute',1);
            % Ready
            obj.stage = 'Stage1';
            obj.isready = true;
            obj.rewardPump('on') % works in reverse. so ON == OFF
            obj.houseLight('on') % works in reverse. so ON == OFF
        end
    end
    methods % User Control Functions
        function start(obj)  
            fprintf('\n\n')
            obj.ExperimentID = input('Please enter ExperimentID:','s');
            obj.mouseID = input('Please enter mouse ID#:','s');
            obj.rewardPump('on') % works in reverse. so ON == OFF
            obj.currentStimNumber = 1;
            obj.currentStim = obj.stimSet{obj.currentStimNumber};
            obj.touchDisplayObj.prepareNextStimulus(obj.currentStim);
            obj.trialPhase = 'wait4poke';
            fprintf('\n\n\n\nStage 1    %s    Mouse#: %s\n',...
                datestr(now,'mm/dd/yyyy'),obj.mouseID)
            fprintf('%s',datestr(now,'HH:MM:SS'))
            notify(obj,'TrialStart');
            obj.rewardLight('on')
            obj.houseLight('on') % works in reverse. so ON == OFF
            obj.dataSummaryObj = DataSummary(obj,obj.stage,obj.mouseID,obj.ExperimentID);
            start(obj.stimulusTimer);
        end
        function stop(obj)            
            stop(obj.stimulusTimer);
            stop(obj.interTrialTimer);
            obj.trialPhase = 'stopped';
            obj.rewardLight('off')
            obj.houseLight('on') % works in reverse. so ON == OFF
            obj.rewardPump('on') % works in reverse. so ON == OFF
            obj.touchDisplayObj.hideStimulus();

        end
    end
    methods % Hardware Control Functions
        function houseLight(obj,varargin)
            if obj.isready
                if nargin<2
                    obj.nidaqObj.digitalSwitch('houselight');
                else
                    obj.nidaqObj.digitalSwitch('houselight',varargin{1});
                end
            end
        end
        function rewardLight(obj,varargin)
            if obj.isready
                if nargin<2
                    obj.nidaqObj.digitalSwitch('rewardlight');
                else
                    obj.nidaqObj.digitalSwitch('rewardlight',varargin{1});
                end
            end
        end
        function rewardPump(obj,varargin)
            if obj.isready
                if nargin<2
                    obj.nidaqObj.digitalSwitch('pump');
                else
                    obj.nidaqObj.digitalSwitch('pump',varargin{1});
                end
            end
        end
        function giveReward(obj,varargin)
            if obj.isready
                if nargin<2
                    t = obj.rewardTime;
                else
                    t = varargin{1};
                end
                obj.nidaqObj.reward(t);
                obj.playSound(1100);
            end
            obj.rewardPump('off') % works in reverse. so ON == OFF
        end
        function givePunishment(obj,varargin)
            if obj.isready
                if nargin<2
                    t = obj.punishTime;
                else
                    t = varargin{1};
                end
                obj.nidaqObj.punish(t);                
            end
        end
        function playSound(obj,varargin)
            % this function plays a sound at the frequency, duration, and
            % volume specified the in the BehaviorBox properties. The user
            % can alternatively pass a frequency in Hz to play
            if nargin>1
                frequency = varargin{1};
            else
                frequency = obj.toneFrequency;
            end
            if obj.isready
                obj.speakerObj.playTone(...
                    frequency,...
                    obj.toneDuration,...
                    obj.toneVolume);                
            end
        end
    end
    methods % Event Response Functions
        function nosePokeFcn(obj,src,evnt)
            if strcmp(evnt.EventName,'NosePokeOff')
                    switch obj.trialPhase
                        case 'wait4poke' % trial initiated
                        case 'stimulus'                            
                        case 'reward'
                        case 'punish'
                        case 'intertrial' % poking before cue to initiate
                            % Restart InterTrial Timer
                            %stop(obj.interTrialTimer);
                            %start(obj.interTrialTimer);
                    end
             notify (obj,'Nosepoke');%  JZ 10/16/11
            end
            
        end
        function screenPokeFcn(obj,src,evnt)
            if obj.isready
              
            end
        end
        function stimPokeFcn(obj,src,evnt)
            % src = Rectangle object that was poked
            if strcmp('stimulus',obj.trialPhase)
                obj.mouseResponse = eval(src.name(end)); % e.g. name = 'rectangle5' -> mouseResponse = 5
                stop(obj.stimulusTimer);
            end
        end
        function falsePokeFcn(obj,src,evnt)
            if obj.isready
                
            end
            notify (obj,'Screen'); % JZ 10/16/2011
        end
    end
    methods % Time-Point Functions
        function startStimFcn(obj,src,evnt)
            obj.rewardLight('off')
            obj.touchDisplayObj.hideStimulus()
            obj.giveReward();
            fprintf('%s',datestr(now,'HH:MM:SS'))
            notify(obj,'Reward');
            obj.trialPhase = 'reward';
        end
        function endStimFcn(obj,src,evnt)
            
        end
        function stopStimFcn(obj,src,evnt)
            % This function is called when the stimulusTimer is stopped,
            % either because it has reached the time limit (after
            % endStimFcn) or because stop(obj.stimulusTimer) was called
          
            start(obj.interTrialTimer)
            obj.rewardLight('off');
        end
        function startInterTrialFcn(obj,src,evnt)
            obj.trialPhase = 'intertrial';

        end
        function endInterTrialFcn(obj,src,evnt)
            % Transition to Wait4Poke Phase
            obj.trialPhase = 'wait4poke';
            fprintf('%s',datestr(now,'HH:MM:SS'))
            notify(obj,'TrialStart')
            start(obj.stimulusTimer);
        end
    end
    methods % Cleanup
        function delete(obj)
            clear global
            delete(obj.touchDisplayObj)
            delete(obj.nidaqObj)
            delete(obj.speakerObj)
            delete(obj.stimulusTimer)
            delete(obj.interTrialTimer)
        end
    end
    
end



function deleteTimerFcn(src,evnt)
delete(src);
end














