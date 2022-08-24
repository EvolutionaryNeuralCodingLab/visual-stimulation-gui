classdef VS_StaticDriftingGrating < VStim
    
    %First you set the properties that the user can change in the GUI and
    %the ones that cannot be changed.

    properties (SetAccess = public)
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        angles=6; %Number of different angles the grating is going to be oriented
        randomizeAngle = true;

        minFreq=.5; %Minimum velocity in cycles per second (Hz)
        maxFreq=1.5; %Maximum velocity in cycles per second (Hz)
        freqStep=.5; %Step in which the velocity changes
        randomizeTF = true;


        minSpatialFreq=0.5; % min spatial freq (cycles/cm)
        maxSpatialFreq=1.0; % max spatial freq (cycles/cm)
        spatialFreqStep=0.5;
        randomizeSF = true

        static_time = 2;

        contrast = 1;
    end


    properties (Hidden,Constant)
        defaultStimDuration=5; %stim duration in [sec] of each grating
        defaultVisualFieldBackgroundLuminance=0;
        defaultTrialsPerCategory=50; %number of gratings to present
        stimRadiousTxt='radious of stimulus';
        contrastTxt='% of dynamic range to use';
        anglesTxt='Number of tilt angles of the grating';
        minFreqTxt='min temp freq (Hz)';
        maxFreqTxt='max temp freq (Hz)';
        freqStepTxt='step stize for temp freq';
        minSpatialFreqTxt='min spatial freq (cycles/cm) screen size in cm is a paramter below';
        maxSpatialFreqTxt='max spatial freq (cycles/cm) screen size in cm is a paramter below';
        spatialFreqStepTxt='step stize for spatial freq';
        
        remarks={''};
        
    end
    properties (SetAccess=protected)
        angleSequence
        tfSequence
        sfSequence
        anglesToPresent
        cyclesPerSecond
        cyclesPerCm
        spatialFreq
        pixPerCm
    end

    properties (Hidden, SetAccess=protected)
        stimOnset
        flipOffsetTimeStamp
        flipMiss
        flipOnsetTimeStamp
        centerXs
        centerYs
    end

    methods
        function obj=run(obj)
            
            %Setup screens
            screenProps = Screen('Resolution',obj.PTB_win);
            screenWidth = Screen('DisplaySize', obj.PTB_win)/10; %Get screen width in cm
            obj.pixPerCm=screenProps.width/screenWidth;
            
            % Initial stimulus parameters for the grating patch:
            
            rotateMode = kPsychUseTextureMatrixForRotation; % Enables rotation of textures.
            
            % res is the total size of the patch in x- and y- direction, i.e., the
            % width and height of the mathematical support.
            res = [screenProps.width screenProps.height];
            amplitude=0.5*obj.contrast; %halve it to make it compatible with demo
           
            % Phase is the phase shift in degrees (0-360 etc.)applied to the sine grating:
            phase = 0;
            
            % Build a procedural sine grating texture for a grating with a support of
            % res(1) x res(2) pixels and a RGB color offset of 0.5 -- a 50%
            % gray. Change it's center to the user defined location
            [gratingtex] = CreateProceduralSineGrating(obj.PTB_win, res(1), res(2), [0.5 0.5 0.5 1.0]);        

            %load up the range of parameters that are going to be presented
            obj.anglesToPresent=0:round(360/obj.angles):360; %nice to have it divisible by 360
            obj.cyclesPerSecond=obj.minFreq:obj.freqStep:obj.maxFreq;
            obj.spatialFreq=(obj.minSpatialFreq:obj.spatialFreqStep:obj.maxSpatialFreq)/obj.pixPerCm;

            %get total number of trials
            nAngles=length(obj.anglesToPresent);
            nTFreq=length(obj.cyclesPerSecond);
            nSFreq=length(obj.spatialFreq);

            obj.nTotTrials=obj.trialsPerCategory*nAngles*nTFreq*nSFreq;

            %calculate sequece of positions and times
            obj.angleSequence=nan(1,obj.nTotTrials);
            obj.tfSequence=nan(1,obj.nTotTrials);
            obj.sfSequence=nan(1,obj.nTotTrials);
            c=1;
            
            for i=1:nAngles
                for j=1:nTFreq
                    for k=1:nSFreq
                        obj.angleSequence(((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.anglesToPresent(i))';
                        obj.tfSequence(((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.cyclesPerSecond(j);
                        obj.sfSequence(((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.spatialFreq(k))';
                        c=c+1;
                    end
                end
            end

            %randomize

            if obj.randomizeAngle
                randomPermutation=randperm(obj.nTotTrials);
                obj.angleSequence=obj.angleSequence(:,randomPermutation);
            end
            if obj.randomizeTF
                randomPermutation=randperm(obj.nTotTrials);
                obj.tfSequence=obj.tfSequence(randomPermutation);
            end
            if obj.randomizeSF
                randomPermutation=randperm(obj.nTotTrials);
                obj.sfSequence=obj.sfSequence(:,randomPermutation);
            end

            
            % Compute increment of phase shift per redraw:
            phaseincrement = (obj.tfSequence * 360) * obj.ifi;
            
            %make sure there are an even number of frames for led syncing
            maxFrames=ceil(obj.stimDuration/obj.ifi);
            trialDuration=maxFrames*obj.ifi;
            t=(obj.ifi:obj.ifi:trialDuration);
            numFrames = numel(t);



            if mod(numFrames,2) == 1
                numFrames=numFrames-1;
            end
            
            %Pre allocate memory for variables
            %  obj.stim_onset=nan(obj.trialsPerCategory,obj.numberOfFrames+1);
            obj.flipOnsetTimeStamp=nan(obj.trialsPerCategory,maxFrames); %when the flip happened
            obj.stimOnset=nan(obj.trialsPerCategory,maxFrames);          %estimate of stim onset
            obj.flipOffsetTimeStamp=nan(obj.trialsPerCategory,maxFrames);  %flip done
            obj.flipMiss=nan(obj.trialsPerCategory,maxFrames);
            
            %main loop - start the session
            WaitSecs(obj.preSessionDelay);
            obj.sendTTL(1,true);
            



            % Animation loop
            for i=1:obj.nTotTrials
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                obj.sendTTL(2,true);
                ttmp=t+GetSecs+obj.ifi;

                for frame= 1: numFrames
                    phase = phase + phaseincrement(i);
                    Screen('DrawTexture', obj.PTB_win, gratingtex, [], [], obj.angleSequence(i), [], [], [], [], rotateMode, [phase, obj.sfSequence(i), amplitude, 0]); %draw grating
                    obj.applyBackgound; %Send TTL for diode
                    obj.sendTTL(3,true);
                    [obj.flipOnsetTimeStamp(i,frame),obj.stimOnset(i,frame),obj.flipOffsetTimeStamp(i,frame),obj.flipMiss(i,frame)]=Screen('Flip',obj.PTB_win, ttmp(frame)); %Save timestamps
                    obj.sendTTL(3,false);
                    if frame==1
                        WaitSecs(obj.static_time);
                    end
                end
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.trialsPerCategory=i;
                    Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                    Screen('Flip',obj.PTB_win);
                    obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                    WaitSecs(obj.interTrialDelay);
                    disp('Trial ended early');
                    return
                end
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                Screen('Flip',obj.PTB_win);
                obj.sendTTL(2,false);
                WaitSecs(obj.interTrialDelay);
                disp('Trial ended');
                WaitSecs(obj.interTrialDelay);
                
            end
            Screen('Flip',obj.PTB_win);
            obj.sendTTL(1,false);
            WaitSecs(obj.postSessionDelay);
            disp('Session ended');
            
        end
        
        %class constractor
        function obj=VS_StaticDriftingGrating(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=obj.defaultStimDuration;
            obj.visualFieldBackgroundLuminance=obj.defaultVisualFieldBackgroundLuminance;
            obj.trialsPerCategory=obj.defaultTrialsPerCategory;
            %obj.hInteractiveGUI=h;
        end
        
    end
end %EOF