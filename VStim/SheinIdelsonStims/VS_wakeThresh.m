classdef VS_wakeThresh < VStim
    properties (SetAccess=public)
        soundStim=true;
        puffStim=true;
        lightStim=true;
        
        interTrialVariability=0.1;
        randomize = true;
    end
    properties (Constant)
        CMloadAudioTxt='load audio files [.wav]';
         interTrialVariabilityTxt='Variability standard deviation in seconds - a value of 1 will sample delays from a distribution of ~1';
        remarks={'Categories in Flash stimuli are: Luminocity'};
    end
    properties (SetAccess=protected)
        audioFileName
        audioPathName
        soundWF
        soundFs
        soundSourceSeq
        interTrialSeq
    end
    properties (Hidden, SetAccess=protected)

    end
    methods
        function obj=run(obj)
            %calculate the coordinates for the rectangles that fit into the visual space
            nSoundSources=numel(obj.audioFileName);
            obj.nTotTrials=obj.trialsPerCategory*nSoundSources;
            
            if nSoundSources==0, error('No Sounds were loaded!'),end
            %calculate sequece of positions and times
            obj.soundSourceSeq=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nSoundSources
                obj.soundSourceSeq( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=i;
                c=c+1;
            end
            
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.soundSourceSeq=obj.soundSourceSeq(randomPermutation);
            end
            obj.interTrialSeq=randn(1,obj.nTotTrials)*obj.interTrialVariability+obj.interTrialDelay;
            if any(obj.interTrialSeq<0)
                warning('Negative inter trial delays!!!!! - zeroing negative terms');
                obj.interTrialSeq(obj.interTrialSeq<0)=0;
            end
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            save tmpVSFile obj; %temporarily save object in case of a system crash
            disp('Session starting');
            
            %initialte audio player
            for i=1:numel(obj.soundWF)
                player(i) = audioplayer(obj.soundWF{i},obj.soundFs(i));
                duration(i)=round(player(i).TotalSamples/player(i).SampleRate);
            end
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
                
                %pp(uint8(obj.trigChNames(2)),[true true],false,uint8(0),uint64(32784)); %stim onset trigger
                obj.sendTTL(2,true);
                player(obj.soundSourceSeq(i)).playblocking;
                WaitSecs(duration(obj.soundSourceSeq(i)));
                obj.sendTTL(2,false);
                
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.interTrialSeq(i));
            end
            
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger
            disp('Session ended');
        end
        
        function obj=CMloadAudio(obj,srcHandle,eventData,hPanel)
            [obj.audioFileName, obj.audioPathName] = uigetfile('*.*','Choose audio files','MultiSelect','On');
            if ~iscell(obj.audioFileName)
                tmp{1}=obj.audioFileName;
                obj.audioFileName=tmp;
            end
            for i=1:numel(obj.audioFileName)
                [obj.soundWF{i},obj.soundFs(i)] = audioread([obj.audioPathName obj.audioFileName{i}]);
            end
            disp([num2str(numel(obj.audioFileName)) ' sounds loaded successfully!']);
        end
        
        %{
        %Make a chirp and save it:
            t=(1:5e4)/1e4;%[100uS]-MHz
            f0=10; %[Hz]
            f1=10e3 %[Hz]
            t1=5;
            y = chirp(t,f0,t1,f1);
            pspectrum(y,t,"spectrogram")
            audiowrite('Chirp10_10000_5S.wav',y,1e4);
        %}

        function outStats=getLastStimStatistics(obj,hFigure)
        end
        
        %class constractor
        function obj=VS_wakeThresh(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=1;
        end
    end
end %EOF