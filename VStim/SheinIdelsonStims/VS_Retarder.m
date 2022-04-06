classdef VS_Retarder < VStim
    properties (SetAccess=public)
        signalAmplitudes = 1.8;  %the voltages applied on the retarder
        zeroWave = 6.2; %baseline voltage for zero retardance
        loadValue = 50;
        randomize = true;
        Back2Background=true; %display images between orientations
        screenTriggerDuration=0.1; %sec
    end
    properties (Constant)
        signalAmplitudeTxt="the volatge levels set in the AWG (since they vary between retarder setups, you can't pre-define them)";
        randomizeTxt='Randomize stimuli';
        remarks={'Categories in Retarder stimuli are:','orientations, interTrialDelay'};
    end
    properties (SetAccess=protected)
        delays
        orientations
    end
    properties (Hidden, SetAccess=protected)

    end
    methods
        function obj=run(obj)
            %calculate time vector for flashes
            nDelays=numel(obj.interTrialDelay);
            nOrientations=numel(obj.signalAmplitudes);
            obj.nTotTrials=obj.trialsPerCategory*nOrientations*nDelays;
            
            obj.delays=nan(1,obj.nTotTrials);
            obj.orientations=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nDelays
                for j=1:nOrientations
                    obj.delays( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.interTrialDelay(i);
                    obj.orientations( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.signalAmplitudes(j);
                    c=c+1;
                end
            end

            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.orientations=obj.orientations(randomPermutation);
                obj.delays=obj.delays(randomPermutation);
%                 if obj.equalize
%                     addPercent=10; %Add addPercent% more changes which will have larger intensity gap
%                     addN=floor(length(obj.orientations)*addPercent/100);
%                     addEveryN=floor(length(obj.orientations)/addN);
%                     nFromEnds=max(floor(nOrientations/10),1); %jump from the lowest 10% to the highest 10%. minimum is 1;
%                     lowLums=obj.flashLuminosity(1:nFromEnds);
%                     highLums=obj.flashLuminosity((end-(nFromEnds-1)):end);
%                     originalLum=obj.orientations;
%                     originalDelay=obj.delays;
%                     equalizedLum=obj.orientations(1:addEveryN);
%                     equalizedDelays=obj.delays(1:addEveryN);
%                     totalAdded=0;
%                     for i=1:2:addN
%                             equalizedLum=[equalizedLum lowLums(randi([1 nFromEnds])) highLums(randi([1 nFromEnds])) ...
%                                 obj.orientations((i*addEveryN+1):((i+1)*addEveryN)) highLums(randi([1 nFromEnds])) lowLums(randi([1 nFromEnds])) ...
%                                 obj.orientations(((i+1)*addEveryN+1):min((i+2)*addEveryN,length(obj.orientations)))];
%                             totalAdded=totalAdded+2;
%                             equalizedDelays=[equalizedDelays obj.interTrialDelay(1) obj.interTrialDelay(1)  ...
%                                 obj.delays((i*addEveryN+1):((i+1)*addEveryN)) obj.interTrialDelay(1) obj.interTrialDelay(1) ...
%                                 obj.delays(((i+1)*addEveryN+1):min((i+2)*addEveryN,length(obj.delays)))];
%                     end
%                     %make sure we don't lose orientations becuase of
%                     %rounding
%                     if ((i+2)*addEveryN)<length(obj.orientations)
%                         equalizedLum=[equalizedLum obj.orientations(((i+2)*addEveryN+1):end)];
%                         equalizedDelays=[equalizedDelays obj.delays(((i+2)*addEveryN+1):end)];
%                     end
%                     obj.nTotTrials=obj.nTotTrials+(addN+1)*2;
%                 end
            end
            obj.orientations=[obj.orientations obj.orientations(1)]; %adding last luminocity value which will never be shown
            
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %Open communication with AWG and set initial parameters
            dg1000z=visa('ni','USB0::0x1AB1::0x0642::DG1ZA220900474::INSTR'); %create VISA object for control of AWG
            fopen(dg1000z); %Open the VISA object created
            fprintf(dg1000z, ':SOURce1:APPLy:SQUare 2000,6.2' );%set the waveform
            fprintf(dg1000z, [':OUTP1:LOAD HighZ']); %set the impedance at the output
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            fprintf(dg1000z, ':OUTP1 ON');
            WaitSecs(obj.preSessionDelay); %pre session wait time
            if ~obj.Back2Background  && obj.interTrialDelay~=0
               disp('Warning! Back2Background is false, while interTrialDelay>0! This means actual stim length is not stimDuration! Continue?')
                pause
            end
                
            for i=1:obj.nTotTrials
                
                obj.sendTTL(2,true);
                fprintf(dg1000z, [':SOURce1:APPLy:SQUare 2000,' num2str(obj.orientations(i))] ); %apply half-wave retardance
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                disp(['Applied voltage: ' num2str(obj.orientations(i))]);
                WaitSecs(obj.stimDuration);
                if obj.Back2Background %Display background between orientations
                    obj.sendTTL(2,false);
                    fprintf(dg1000z, [':SOURce1:APPLy:SQUare 2000,' num2str(obj.zeroWave)] ); %apply half-wave retardance (rotate light 90 deg)
                    WaitSecs(obj.delays(i));
                else %just move on to the next orienation but first turn off trigger
                    obj.sendTTL(2,false);
                    WaitSecs(obj.delays(i));
                end
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    obj.sendTTL(1,false);
                    fprintf(dg1000z, ':OUTP1 OFF');
                    fclose(dg1000z); %Close the VISA object 
                    return;
                end               
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session start trigger (also triggers the recording start)
            fprintf(dg1000z, ':OUTP1 OFF'); %Turn off output
            fclose(dg1000z); %Close the VISA object 
            
            obj.orientations=obj.orientations(1:end-1); %removing last dummy luminocity value from array
            disp('Session ended');
        end
        
        %class constractor
        function obj=VS_Retarder(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF