classdef VS_lumCheck_mediumBatch < VStim
    properties (SetAccess=public)
        flashLuminosity = [239:255]; %(L_high-L_low)/L_low
        randomize = true;
        equalize = false; %Make distribution of intenisty diffs more uniform by adding large diffs. Currently all added diffs will have inter trial delay of obj.interTrialDelay(1)
        Back2Background=true; %display images between luminosities
        screenTriggerDuration=0.1; %sec
    end
    properties (Constant)
        flashLuminosityTxt='The luminocity value for the flash, if array->show all given contrasts';
        randomizeTxt='Randomize stimuli';
        equalizeTxt='Make distribution of intensity differences more uniform';
        remarks={'Categories in Flash stimuli are:','luminosity, interTrialDelay'};
    end
    properties (SetAccess=protected)
        delays
        luminosities
    end
    properties (Hidden, SetAccess=protected)
        on_Flip
        on_Stim
        on_FlipEnd
        on_Miss
        off_Flip
        off_Stim
        off_FlipEnd
        off_Miss
    end
    methods
        function obj=run(obj)
            %calculate time vector for flashes
            nDelays=numel(obj.interTrialDelay);
            nLuminosities=numel(obj.flashLuminosity);
            obj.nTotTrials=obj.trialsPerCategory*nLuminosities*nDelays;
            
            obj.delays=nan(1,obj.nTotTrials);
            obj.luminosities=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nDelays
                for j=1:nLuminosities
                    obj.delays( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.interTrialDelay(i);
                    obj.luminosities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.flashLuminosity(j);
                    c=c+1;
                end
            end

            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.luminosities=obj.luminosities(randomPermutation);
                obj.delays=obj.delays(randomPermutation);
                if obj.equalize
                    addPercent=10; %Add addPercent% more changes which will have larger intensity gap
                    addN=floor(length(obj.luminosities)*addPercent/100);
                    addEveryN=floor(length(obj.luminosities)/addN);
                    nFromEnds=max(floor(nLuminosities/10),1); %jump from the lowest 10% to the highest 10%. minimum is 1;
                    lowLums=obj.flashLuminosity(1:nFromEnds);
                    highLums=obj.flashLuminosity((end-(nFromEnds-1)):end);
                    originalLum=obj.luminosities;
                    originalDelay=obj.delays;
                    equalizedLum=obj.luminosities(1:addEveryN);
                    equalizedDelays=obj.delays(1:addEveryN);
                    totalAdded=0;
                    for i=1:2:addN
                            equalizedLum=[equalizedLum lowLums(randi([1 nFromEnds])) highLums(randi([1 nFromEnds])) ...
                                obj.luminosities((i*addEveryN+1):((i+1)*addEveryN)) highLums(randi([1 nFromEnds])) lowLums(randi([1 nFromEnds])) ...
                                obj.luminosities(((i+1)*addEveryN+1):min((i+2)*addEveryN,length(obj.luminosities)))];
                            totalAdded=totalAdded+2;
                            equalizedDelays=[equalizedDelays obj.interTrialDelay(1) obj.interTrialDelay(1)  ...
                                obj.delays((i*addEveryN+1):((i+1)*addEveryN)) obj.interTrialDelay(1) obj.interTrialDelay(1) ...
                                obj.delays(((i+1)*addEveryN+1):min((i+2)*addEveryN,length(obj.delays)))];
                    end
                    %make sure we don't lose luminosities becuase of
                    %rounding
                    if ((i+2)*addEveryN)<length(obj.luminosities)
                        equalizedLum=[equalizedLum obj.luminosities(((i+2)*addEveryN+1):end)];
                        equalizedDelays=[equalizedDelays obj.delays(((i+2)*addEveryN+1):end)];
                    end
                    obj.nTotTrials=obj.nTotTrials+(addN+1)*2;
                end
            end
            obj.luminosities=[obj.luminosities obj.luminosities(1)]; %adding last luminocity value which will never be shown
            
            %Pre allocate memory for variables
            obj.on_Flip=nan(1,obj.nTotTrials);
            obj.on_Stim=nan(1,obj.nTotTrials);
            obj.on_FlipEnd=nan(1,obj.nTotTrials);
            obj.on_Miss=nan(1,obj.nTotTrials);
            obj.off_Flip=nan(1,obj.nTotTrials);
            obj.off_Stim=nan(1,obj.nTotTrials);
            obj.off_FlipEnd=nan(1,obj.nTotTrials);
            obj.off_Miss=nan(1,obj.nTotTrials);
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;

            % Update image buffer for the first time
            obj.syncMarkerOn = false; %reset sync marker
            Screen('FillOval',obj.PTB_win,obj.luminosities(1),obj.visualFieldRect);
            obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                        
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            if ~obj.Back2Background  && obj.interTrialDelay~=0
               disp('Warning! Back2Background is false, while interTrialDelay>0! This means actual stim length is not stimDuration! Continue?')
                pause
            end
                
            for i=1:obj.nTotTrials
                
                [obj.on_Flip(i),obj.on_Stim(i),obj.on_FlipEnd(i),obj.on_Miss(i)]=Screen('Flip',obj.PTB_win);
                obj.sendTTL(2,true);
                if obj.Back2Background %Display background between luminosities
                    % Update display
                    Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance,obj.visualFieldRect);
                    obj.applyBackgound; %set background mask and finalize drawing (drawing finished)
                    [obj.off_Flip(i),obj.off_Stim(i),obj.off_FlipEnd(i),obj.off_Miss(i)]=Screen('Flip',obj.PTB_win,obj.on_Flip(i)+obj.actualStimDuration-0.5*obj.ifi);
                    obj.sendTTL(2,false);
                else %just move on to the next luminosity but first turn of trigger
                    WaitSecs(obj.screenTriggerDuration);
                    obj.sendTTL(2,false);
                    WaitSecs(obj.stimDuration - obj.screenTriggerDuration);
                end
                % Update image buffer
                Screen('FillOval',obj.PTB_win,obj.luminosities(i+1),obj.visualFieldRect);
                obj.applyBackgound; %set background mask and finalize drawing (drawing finished)
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    obj.sendTTL(1,false);
                    return;
                end
                
                WaitSecs(obj.delays(i)-(GetSecs-obj.off_Flip(i)));
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session start trigger (also triggers the recording start)
            
            obj.luminosities=obj.luminosities(1:end-1); %removing last dummy luminocity value from array
            disp('Session ended');
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            plotStats=1;
            if nargin==2 & plotStats
                intervals=-1e-1:2e-4:1e-1;
                intCenter=(intervals(1:end-1)+intervals(2:end))/2;
                stimDurationShifts=(obj.off_Flip-obj.on_Flip)-obj.actualStimDuration;
                n1=histc(stimDurationShifts,intervals);
                
                flipDurationShiftsOn=obj.on_FlipEnd-obj.on_Flip;
                flipDurationShiftsOff=obj.off_FlipEnd-obj.off_Flip;
                n2=histc([flipDurationShiftsOn' flipDurationShiftsOff'],intervals,1);
                
                flipToStimOn=(obj.on_Stim-obj.on_Flip);
                flipToStimOff=(obj.off_Stim-obj.off_Flip);
                n3=histc([flipToStimOn' flipToStimOff'],intervals,1);
                
                n4=histc([obj.on_Miss' obj.on_Miss'],intervals,1);
                
                figure(hFigure);
                subplot(2,2,1);
                bar(1e3*intCenter,n1(1:end-1),'Edgecolor','none');
                xlim(1e3*intervals([find(n1>0,1,'first')-3 find(n1>0,1,'last')+4]));
                ylabel('\Delta(Stim duration)');
                xlabel('Time [ms]');
                line([0 0],ylim,'color','k','LineStyle','--');
                
                subplot(2,2,2);
                bar(1e3*intCenter,n2(1:end-1,:),'Edgecolor','none');
                xlim([-0.5 1e3*intervals(find(sum(n2,2)>0,1,'last')+4)]);
                ylabel('Flip duration');
                xlabel('Time [ms]');
                legend('On','Off');
                line([0 0],ylim,'color','k','LineStyle','--');
                
                subplot(2,2,3);
                bar(1e3*intCenter,n3(1:end-1,:),'Edgecolor','none');
                xlim(1e3*intervals([find(sum(n3,2)>0,1,'first')-3 find(sum(n3,2)>0,1,'last')+4]));
                ylabel('Flip 2 Stim');
                xlabel('Time [ms]');
                legend('On','Off');
                line([0 0],ylim,'color','k','LineStyle','--');
                
                subplot(2,2,4);
                bar(1e3*intCenter,n4(1:end-1,:),'Edgecolor','none');
                xlim(1e3*intervals([find(sum(n4,2)>0,1,'first')-3 find(sum(n4,2)>0,1,'last')+4]));
                ylabel('Miss stats');
                xlabel('Time [ms]');
                legend('On','Off');
                line([0 0],ylim,'color','k','LineStyle','--');
            end
        end
        %class constractor
        function obj=VS_lumCheck_mediumBatch(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.interTrialDelay = 10;
            obj.stimDuration = 10;
            obj.trialsPerCategory= 60;
            obj.visualFieldBackgroundLuminance = 247;
        end
    end
end %EOF