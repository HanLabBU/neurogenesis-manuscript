classdef BehaviorBox4 < hgsetget
    % ---------------------------------------------------------------------
    % BehaviorBox
    % Han Lab
    % 7/11/2011
    % Mark Bucklin
    % ---------------------------------------------------------------------
    %
    % This class defines experimental parameters (timing, stimulus, etc.)
    % and runs the experiment
    % on 9/14/11 JZ changed to show 3 random samples
    %
    % See Also TOUCHINTERFACE RECTANGLE TOUCHDISPLAY NIDAQINTERFACE
    
    
    
    
    
    properties
        stimOnTime
        interTrialInterval
        pauseTime
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
        punishmentTimer
        pauseTimer
        trialPhase % 'stopped' 'wait4poke' 'stimulus' 'reward' 'punish' 'intertrial'
        currentStim % scalar vector with the stimulus numbers being presented
        currentStimNumber
        mouseResponse
        isready
        stage
        mouseID
        ExperimentID
    end
    
    properties (Hidden)        
        shouldContinue % true if the next trial should start at the end of the ITI (rather than wait for poke)
    end
    
    
    events
        TrialStart
        StimOn
        StimOff
        Reward % Correct
        Punish % Incorrect
        NoResponse % Abort/No-Attempt
        Wait4Poke
    end
    
    
    
    
    methods % Initialization
        function obj = BehaviorBox4(varargin)
            % Assign input arguments to object properties
            if nargin > 1
                for k = 1:2:length(varargin)
                    obj.(varargin{k}) = varargin{k+1};
                end
            end
            % Define Defaults
            obj.default = struct(...
                'stimOnTime',60,...% 60 sec so the stimuli will replaced every minute. but it is not necessary.JZ
                'interTrialInterval',10,...
                'pauseTime',0.5,...
                'rewardTime',.2,...
                'punishTime',5,...%% changed from 3 to 10 to avoid system crash JZ 9/15/11
                'stimSet',{{1;2;3;4;5;6;7}},...
                'correctResponse',{{1;2;3;4;5;6;7}},...% not required in 3 stimuli 9/14/11
                'stimOrder','random',...
                'toneFrequency',1100,...
                'toneDuration',.5,...
                'toneVolume',.5);
            obj.isready = false;
            obj.shouldContinue = false;
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

            % Construct a Data Summary Object
            obj.stage = 'Stage4';
            % Ready
            obj.isready = true;    
            obj.rewardPump('on') % works in reverse. so ON == OFF
            obj.houseLight('on') % works in reverse. so ON == OFF
        end
    end
    methods % User Control Functions
        function start(obj)

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
            obj.punishmentTimer = timer(...
                'StartFcn',@(src,evnt)startPunishFcn(obj,src,evnt),...
                'StartDelay',obj.punishTime,...
                'TimerFcn',@(src,evnt)endPunishFcn(obj,src,evnt),...
                'TasksToExecute',1);
            obj.pauseTimer = timer(...
                'StartFcn',@(src,evnt)startPauseFcn(obj,src,evnt),...
                'StartDelay',obj.pauseTime,...
                'TimerFcn',@(src,evnt)endPauseFcn(obj,src,evnt),...
                'TasksToExecute',1);
            fprintf('\n\n')
            obj.ExperimentID = input('Please enter ExperimentID:','s');
            obj.mouseID = input('Please enter mouse ID#:','s');
            obj.rewardPump('on') % works in reverse. so ON == OFF
            nstim = size(obj.stimSet,1);
            switch obj.stimOrder
                case 'sequential'
                    if obj.currentStimNumber == nstim
                        obj.currentStimNumber = 1;
                    else
                        obj.currentStimNumber = obj.currentStimNumber+1;
                    end
                case 'random'
                    obj.currentStimNumber = randsample(7,3)';%%% to get 3 random numbers out of 7 & put into 1 by k vectorJZ 9-14-11 %obj.currentStimNumber = ceil(nstim*rand);
            end
            obj.currentStim = obj.currentStimNumber; %% to get 3 random numbers JZ9/14/11 %obj.currentStim = obj.stimSet{obj.currentStimNumber};
            obj.touchDisplayObj.prepareNextStimulus(obj.currentStim);
            obj.trialPhase = 'wait4poke';
            fprintf('\n\n\n\nStage 4    %s    Mouse#: %s\n',...
                datestr(now,'mm/dd/yyyy'),obj.mouseID)
            fprintf('%s',datestr(now,'HH:MM:SS'))
            notify(obj,'TrialStart');
            obj.rewardLight('on')
            obj.houseLight('on') % works in reverse. so ON == OFF
             obj.dataSummaryObj = DataSummary(obj,obj.stage,obj.mouseID,obj.ExperimentID);
            start(obj.stimulusTimer);
        end
        function stop(obj)
            obj.trialPhase = 'stopped';
            obj.rewardLight('off')
            obj.houseLight('on') % works in reverse. so ON == OFF
            obj.rewardPump('on') % works in reverse. so ON == OFF
            delete(obj.stimulusTimer);            
            delete(obj.interTrialTimer);
            delete(obj.punishmentTimer);
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
                obj.playSound(500,0.25);% JZ 9-13-11 indicating the success poke %obj.playSound(3200,0.75,1.5)
            end
            obj.houseLight('off') % works in reverse. so ON == OFF
            start(obj.punishmentTimer);
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
            if nargin>2
                duration = varargin{2};
            else
                duration = obj.toneDuration;
            end
            if nargin>3
                volume = varargin{3};
            else
                volume = obj.toneVolume;
            end
            if obj.isready
                obj.speakerObj.playTone(...
                    frequency,...
                    duration,...
                    volume);
            end
        end
    end
    methods % Event Response Functions
        function nosePokeFcn(obj,src,evnt)
            if strcmp(evnt.EventName,'NosePokeOff')
                    switch obj.trialPhase
                        case 'wait4poke' % trial initiated
                            obj.rewardLight('off');
                            obj.shouldContinue = true;
                            start(obj.stimulusTimer);
                        case 'stimulus'                            
                        case 'reward'
                            obj.shouldContinue = true;
                        case 'punish'
                            obj.shouldContinue = true;
                        case 'intertrial' % poking before cue to initiate
                            % Restart InterTrial Timer
                            %stop(obj.interTrialTimer);
                            %start(obj.interTrialTimer);
                            obj.shouldContinue = true;
                    end
            end
        end
        function screenPokeFcn(obj,src,evnt)
            if obj.isready
            end
        end
        function stimPokeFcn(obj,src,evnt)
            % src = Rectangle object that was poked
            %CTC = 0; %%CorrectTouchCount  JZ 9/16/11
            if strcmp('stimulus',obj.trialPhase)
                stop(obj.stimulusTimer);
                obj.mouseResponse = eval(src.name(end)); % e.g. name = 'rectangle5' -> mouseResponse = 5
                fprintf('\b %d \n',obj.mouseResponse)
               % CTC = CTC +1;  %%CorrectTouchCount  JZ 9/16/11
               % correctTouch(CTC,1)= datestr(now,'HH:MM:SS:FFF');%%CorrectTouchCount  JZ 9/16/11
               %savefile = 'correctTouch.mat';%%CorrectTouchCount  JZ 9/16/11
               %save(savefile,correctTouch);%%CorrectTouchCount  JZ 9/16/11
            end
        end
        function falsePokeFcn(obj,src,evnt)
            if obj.isready
                if strcmp('stimulus',obj.trialPhase)
                    obj.mouseResponse = eval(src.name(end)); % e.g. name = 'rectangle5' -> mouseResponse = 5
                    fprintf('\b %d \n',obj.mouseResponse)
                    stop(obj.stimulusTimer);
                    obj.givePunishment;
                    %stop(obj.stimulusTimer);
                end
            end
        end
    end
    methods % Time-Point Functions
        function startStimFcn(obj,src,evnt)
            obj.touchDisplayObj.showStimulus()
            obj.rewardLight('off');
            fprintf('%s',datestr(now,'HH:MM:SS'))
            notify(obj,'StimOn');
            obj.trialPhase = 'stimulus';
        end
        function endStimFcn(obj,src,evnt)
            % This function is called if the stimulus presentation period
            % is reached without a response from the mouse
            obj.mouseResponse = [];
            fprintf('%s',datestr(now,'HH:MM:SS'))
            notify(obj,'NoResponse')
        end
        function stopStimFcn(obj,src,evnt)
            % This function is called when the stimulusTimer is stopped,
            % either because it has reached the time limit (after
            % endStimFcn) or because stop(obj.stimulusTimer) was called
            obj.touchDisplayObj.hideStimulus()
            %fprintf('%s',datestr(now,'HH:MM:SS'))
            %notify(obj,'StimOff');
            if ~isempty(obj.mouseResponse)
                % Mouse Responded
                switch obj.mouseResponse  %% match with one of 3 stimuli JZ 9/14/11% obj.mouseResponse == obj.correctResponse{obj.currentStimNumber}
                    % Reward Mouse in either of 3 condition
                    case obj.currentStimNumber(1,1)
                         start(obj.pauseTimer);
                    case obj.currentStimNumber(1,2)
                         start(obj.pauseTimer);
                    case obj.currentStimNumber(1,3)
                         start(obj.pauseTimer);
                    otherwise
                    % Punish Mouse
                    fprintf('%s',datestr(now,'HH:MM:SS'))
                    notify(obj,'Punish');
                    obj.trialPhase = 'punish';
                    obj.shouldContinue = true;
                end
            else
                % Mouse didn't respond
                stop(obj.stimulusTimer);
                obj.touchDisplayObj.prepareNextStimulus(obj.currentStim); % e.g. currentStim = [3 5]
                obj.rewardLight('off')
                start(obj.stimulusTimer);
                obj.shouldContinue = true;
            end

        end
        function startInterTrialFcn(obj,src,evnt)
            obj.trialPhase = 'intertrial';

        end
        function endInterTrialFcn(obj,src,evnt)
            % Prepare the Next Stimulus
            nstim = size(obj.stimSet,1);
            switch obj.stimOrder
                case 'sequential'
                    if obj.currentStimNumber == nstim
                        obj.currentStimNumber = 1;
                    else
                        obj.currentStimNumber = obj.currentStimNumber+1;
                    end
                case 'random'
                    obj.currentStimNumber = randsample(7,3)';%%% to get 3 random numbers out of 7 & put into 1 by k vectorJZ 9-14-11 %obj.currentStimNumber = ceil(nstim*rand);
            end
            obj.currentStim = obj.currentStimNumber; %% to get 3 random numbers JZ9/14/11 % obj.stimSet{obj.currentStimNumber};
            obj.touchDisplayObj.prepareNextStimulus(obj.currentStim); % e.g. currentStim = [3 5]
            % Transition to Wait4Poke Phase
            if ~obj.shouldContinue
                obj.trialPhase = 'wait4poke';
                %obj.rewardLight('on')
            else % the nose-poke was poked during the ITI
                start(obj.stimulusTimer)
            end
            fprintf('%s',datestr(now,'HH:MM:SS'))
            notify(obj,'TrialStart')
        end
        
        function startPunishFcn(obj,src,evnt)
            obj.houseLight('off') % works in reverse. so ON == OFF
        end
        function endPunishFcn(obj,src,evnt)
            obj.houseLight('on') % works in reverse. so ON == OFF
            obj.touchDisplayObj.prepareNextStimulus(obj.currentStim); % e.g. currentStim = [3 5]
            start(obj.stimulusTimer);
        end
            
        function startPauseFcn(obj,src,evnt)
            obj.playSound(500,0.25);
            obj.trialPhase = 'pause';
        end
        function endPauseFcn(obj,src,evnt)
            obj.giveReward();
            fprintf('%s',datestr(now,'HH:MM:SS'))
            notify(obj,'Reward');
            obj.trialPhase = 'reward';
            obj.shouldContinue = false;
            start(obj.interTrialTimer)
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
            delete(obj.dataSummaryObj)
        end
    end
    
end



function deleteTimerFcn(src,evnt)
delete(src);
end
    

    
