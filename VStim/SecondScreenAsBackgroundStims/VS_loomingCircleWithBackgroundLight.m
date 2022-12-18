classdef VS_loomingCircleWithBackgroundLight < VStim
    properties (SetAccess=public)
        circleColor = [255 0 0];
        randomizeCircleColor = true;
        
        initialXYPosition = [0 0];
        randomizeInitialPositions = true;
        
        circleVelocity = 100;
        randomizeVelocity = true;
        
        circleTrueSize = 35;
        circleInitialDistance = 300;
        time2Collision = 5;
        
        replaceLoomAreaByFullfieldAngle = false;
        
        postLoomTime = 2;
        
        eye2ScreenDistance = 25;
        
        minimalRealDistance = 5;
        circleWithRandomNoise = false;
        
        displayWidthHeight = [12 7]; %the width and height of the screen in cm [width height]
        
        loomScreenNum = 1;
        lightScreenNum = 2;

        useScreen2AsLightSource=true;
        lightScreenLuminanceRGB=[0 0 255]; %in [R G B]
        waitAfterScreen2LightsOn=1; %sec
    end

    properties (Constant)
        
        circleVelocityTxt = 'The real approaching velocity of the object [cm/s]';
        circleTrueSizeTxt = 'The real size of the approaching object [cm]';
        circleInitialDistanceTxt = 'The initial distance of the object [cm]';
        
        eye2ScreenDistanceTxt = 'The distance between the fish eye and the screen [cm]';
        
        circleColorTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        randomizeCircleColorTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        
        replaceLoomAreaByFullfieldAngleTxt='Convert the size of the looming circle relative to background to polarization change';
        
        initialXYPositionTxt='The initial position of the looming circle center on the screen [cm, 2 x M, M being number of positions] ';

        randomizeVelocityTxt='Randomize size to speed ratio';
        
        minimalRealDistanceTxt='the minimal real distance between the approaching object and eye at the end of the stimulation';
        circleWithRandomNoiseTxt='if true looming circle with be composed of random intensities';
        displayWidthHeightTxt = 'the width and height of the screen in cm [width height]';

        useScreen2AsLightSourceTxt='Use a second screen as a background light source for the first screen'
        lightScreenLuminanceRGBTxt='[R G B] values for the background illumination of the second screen'
        waitAfterScreen2LightsOnTxt='The number of seconds to wait before turning second screen light on and before starting experiment'

        remarks={'Categories in stimuli are: speed, offset'};
    end
    
    properties (SetAccess=protected)
        circleColorSequence
        velocitySequence
        initialPositionSequence
        t
    end
    
    properties (Hidden, SetAccess=protected)
        flip
        stim
        flipEnd
        miss
    end
    methods
        function obj=run(obj)
            if obj.useScreen2AsLightSource
                if obj.nPTBScreens~=2
                    error('A second stimulation screen was not detected, Background illumination will not work! Run again with useScreen2AsLightSource=false');
                    return;
                end
            end
            
            %calculate the angles of directions
            nCircleColor=size(obj.circleColor,1);
            nVelocities=numel(obj.circleVelocity);
            nInitialPositions=size(obj.initialXYPosition,1);

            obj.nTotTrials=obj.trialsPerCategory*nCircleColor*nVelocities*nInitialPositions;
            
            %calculate sequece of positions and times
            obj.circleColorSequence=nan(3,obj.nTotTrials);
            obj.velocitySequence=nan(1,obj.nTotTrials);
            obj.initialPositionSequence=nan(2,obj.nTotTrials);
            c=1;
            for i=1:nCircleColor
                for j=1:nVelocities
                    for k=1:nInitialPositions
                        obj.circleColorSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.circleColor(i,:))';
                        obj.velocitySequence( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.circleVelocity(j);
                        obj.initialPositionSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.initialXYPosition(k,:))';
                        c=c+1;
                    end
                end
            end

            %randomize
            if obj.randomizeCircleColor
                randomPermutation=randperm(obj.nTotTrials);
                obj.circleColorSequence=obj.circleColorSequence(:,randomPermutation);
            end
            if obj.randomizeVelocity
                randomPermutation=randperm(obj.nTotTrials);
                obj.velocitySequence=obj.velocitySequence(randomPermutation);
            end
            if obj.randomizeInitialPositions
                randomPermutation=randperm(obj.nTotTrials);
                obj.initialPositionSequence=obj.initialPositionSequence(:,randomPermutation);
            end
            
            %get screen properties
            
            %determine initial position 
            x0=obj.centerX(obj.loomScreenNum)+obj.initialPositionSequence(1,:).*(obj.rect(obj.loomScreenNum,3)/obj.displayWidthHeight(1));
            y0=obj.centerY(obj.loomScreenNum)+obj.initialPositionSequence(2,:).*(obj.rect(obj.loomScreenNum,4)/obj.displayWidthHeight(2));
            
            maxFrames=ceil(obj.time2Collision/obj.ifi(obj.loomScreenNum));
            movementDuration=maxFrames*obj.ifi(obj.loomScreenNum);
            obj.t=(obj.ifi(obj.loomScreenNum):obj.ifi(obj.loomScreenNum):movementDuration);
            nFrames=numel(obj.t);
                        
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false; %initialize sync signal
            Screen('FillRect',obj.PTB_win(obj.loomScreenNum),obj.visualFieldBackgroundLuminance);
            Screen('DrawTexture',obj.PTB_win(obj.loomScreenNum),obj.masktexOff(obj.loomScreenNum));
            Screen('Flip',obj.PTB_win(obj.loomScreenNum));
            %Screen('BlendFunction', obj.PTB_win(obj.loomScreenNum), GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);     
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
                        
            obj.flip=nan(obj.nTotTrials,maxFrames);
            obj.stim=nan(obj.nTotTrials,maxFrames);
            obj.flipEnd=nan(obj.nTotTrials,maxFrames);
            obj.miss=nan(obj.nTotTrials,maxFrames);
            
            %generate mask for noise image
            if obj.circleWithRandomNoise
                [X,Y]=meshgrid(1:(obj.visualFieldRect(obj.loomScreenNum,3)-obj.visualFieldRect(obj.loomScreenNum,1)),1:(obj.visualFieldRect(obj.loomScreenNum,4)-obj.visualFieldRect(obj.loomScreenNum,2)));
                X=(X-size(X,1)/2).^2;
                Y=(Y-size(X,2)/2).^2;
            end
            
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');

            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)

            if obj.useScreen2AsLightSource
                Screen('FillRect',obj.PTB_win(obj.lightScreenNum),obj.lightScreenLuminanceRGB,obj.rect(obj.lightScreenNum,:));
                Screen('DrawingFinished', obj.PTB_win(obj.lightScreenNum));
                Screen('Flip',obj.PTB_win(obj.lightScreenNum));
                obj.sendTTL(4,true);
                WaitSecs(obj.waitAfterScreen2LightsOn);
            end

            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials

                tmpCircleColor=obj.circleColorSequence(:,i);
                tmpVelocity=obj.velocitySequence(i);
                
                r=obj.eye2ScreenDistance*obj.circleTrueSize/tmpVelocity./obj.t(end:-1:1);
                
                if obj.replaceLoomAreaByFullfieldAngle
                    polarizationAngle=(r./r(end)).^2.*tmpCircleColor;
                    r(:)=r(end);
                else
                    polarizationAngle=tmpCircleColor*ones(1,nFrames);
                end
                ovalCoordinates=round([max(obj.rect(obj.loomScreenNum,1),x0(i)-r);max(obj.rect(obj.loomScreenNum,2),y0(i)-r);min(x0(i)+r,obj.rect(obj.loomScreenNum,3));min(obj.rect(obj.loomScreenNum,4),y0(i)+r)]);
                
                
                if obj.circleWithRandomNoise
                    noiseimg=255*rand(obj.visualFieldRect(obj.loomScreenNum,3)-obj.visualFieldRect(obj.loomScreenNum,1),obj.visualFieldRect(obj.loomScreenNum,4)-obj.visualFieldRect(obj.loomScreenNum,2));
                end
                
                ttmp=obj.t+GetSecs+obj.ifi(obj.loomScreenNum);
                obj.sendTTL(2,true);
                for j=1:nFrames
                    if obj.circleWithRandomNoise
                        %tex=Screen('MakeTexture', obj.PTB_win(obj.loomScreenNum), noiseimg);
                        % Convert it to a texture 'tex':
                        noiseimgTmp=noiseimg;
                        noiseimgTmp((X+Y)>(r(j)^2))=0;
                        tex=Screen('MakeTexture', obj.PTB_win(obj.loomScreenNum), noiseimgTmp);
                        Screen('DrawTexture', obj.PTB_win(obj.loomScreenNum), tex, [], [], [], 0, [], tmpCircleColor);
                    else
                        % Update display
                        Screen('FillOval',obj.PTB_win(obj.loomScreenNum),polarizationAngle(:,j),ovalCoordinates(:,j),obj.rect(obj.loomScreenNum,4));%the last input is needed due to a strange bug that only occurs when working with 2 screens
                    end
                    obj.applyBackgound(obj.loomScreenNum);  %set background mask and finalize drawing (drawing finished)
                    obj.sendTTL(3,true);
                    [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win(obj.loomScreenNum),ttmp(j));
                    obj.sendTTL(3,false);
                end
                endStimTime=GetSecs;
                
                Screen('FillRect',obj.PTB_win(obj.loomScreenNum),obj.visualFieldBackgroundLuminance);
                obj.applyBackgound(obj.loomScreenNum);  %set background mask and finalize drawing (drawing finished)
                
                WaitSecs(obj.postLoomTime-(GetSecs-endStimTime));
                Screen('Flip',obj.PTB_win(obj.loomScreenNum));
                obj.sendTTL(2,false);
                endTrialTime=GetSecs;

                %Screen('DrawTexture',obj.PTB_win,obj.masktex);
                %[endSessionTime]=Screen('Flip',obj.PTB_win);
                % Start wait: Code here is run during the waiting for the new session
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end

                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                WaitSecs(obj.interTrialDelay-(GetSecs-endTrialTime));
            end
            
            if obj.useScreen2AsLightSource
                Screen('FillRect',obj.PTB_win(obj.lightScreenNum),[0 0 0],obj.rect(obj.lightScreenNum,:));
                Screen('DrawingFinished', obj.PTB_win(obj.lightScreenNum));
                Screen('Flip',obj.PTB_win(obj.lightScreenNum));
                obj.sendTTL(4,false);
            end
            
            WaitSecs(obj.postSessionDelay);
            
            obj.sendTTL(1,false);
            disp('Session ended');
        end

        function outStats=getLastStimStatistics(obj,hFigure)
           outStats.props=obj.getProperties;
            
            intervals=-1e-1:2e-4:1e-1;
            intCenter=(intervals(1:end-1)+intervals(2:end))/2;
            
            stimOnsetShifts=diff(obj.flip,[],2);
            n1=histc(stimOnsetShifts(:),intervals);
            
            flipDurationShifts=obj.flipEnd-obj.flip;
            n2=histc(flipDurationShifts(:),intervals);
            
            flipToStim=(obj.stim-obj.flip);
            n3=histc(flipToStim(:),intervals);
            
            n4=histc([obj.miss(:)],intervals);
            
            figure(hFigure);
            subplot(2,2,1);
            bar(1e3*intCenter,n1(1:end-1),'Edgecolor','none');
            xlim(1e3*intervals([max(1,find(n1>0,1,'first')-3) min(numel(n1),find(n1>0,1,'last')+4)]));
            ylabel('\Delta(Flip)');
            xlabel('Time [ms]');
            line([obj.ifi obj.ifi],ylim,'color','k','LineStyle','--');
            
            subplot(2,2,2);
            bar(1e3*intCenter,n2(1:end-1),'Edgecolor','none');
            xlim([-0.5 1e3*intervals(min(numel(n2),find(n2>0,1,'last')+4))]);
            ylabel('Flip duration');
            xlabel('Time [ms]');
            line([0 0],ylim,'color','k','LineStyle','--');
            
            subplot(2,2,3);
            bar(1e3*intCenter,n3(1:end-1),'Edgecolor','none');
            xlim(1e3*intervals([max(1,find(n3>0,1,'first')-3) min(numel(n3),find(n3>0,1,'last')+4)]));
            ylabel('Flip 2 Stim');
            xlabel('Time [ms]');
            line([0 0],ylim,'color','k','LineStyle','--');
            
            subplot(2,2,4);
            bar(1e3*intCenter,n4(1:end-1),'Edgecolor','none');
            xlim(1e3*intervals([max(1,find(n4>0,1,'first')-3) min(numel(n4),find(n4>0,1,'last')+4)]));
            ylabel('Miss stats');
            xlabel('Time [ms]');
            line([0 0],ylim,'color','k','LineStyle','--');
        end
        %class constractor
        function obj=VS_loomingCircleWithBackgroundLight(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=NaN;
        end
    end
end %EOF