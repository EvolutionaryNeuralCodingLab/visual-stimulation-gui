classdef VS_linearlyMovingBouncingDots < VStim
    properties (SetAccess=public)
        luminosities = 255; %(L_high-L_low)/L_low
        randomize = true;
        speeds = 100; %pixel per second
        dotsNumbers= 1000 % number of dots
        dotSize= 5 % width of dot (pixels)
        waitFromOnset = 1; %time to wait between dots appearance and dot movement
    end
    properties (Constant)
        luminositiesTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        dotSizeTxt='The size of the dots [pixels]';
        rotateDotsTxt='True/false/[true false] - whether to rotate, zoom or both';
        randomizeTxt='Randomize the order of different trials';
        dotsNumbersTxt='The number of dots to be shown, if array->show all given dot numbers';
        speedTxt='The speed of the moving dots [pixels/sec], if array->show all given speeds';
        waitFromOnsetTxt='The time [s] to wait from presentation of dots to start of motion'
        remarks={'Categories in stimuli are: speed, rotateDots, rotationZoomDirection'};
    end
    properties (SetAccess=protected)
        allSpeeds
        allLuminocities
        allDotNumbers
        screenWidth
        xi
        vi
    end
    properties (Hidden, SetAccess=protected)
        flip
        stim
        flipEnd
        miss
    end
    
    methods
        
        function obj=run(obj)
            %calculate the angles of directions
            nSpeeds=numel(obj.speeds);
            nLuminocities=numel(obj.luminosities);
            nDotNumbers=numel(obj.dotsNumbers);
            
            obj.nTotTrials=obj.trialsPerCategory*nSpeeds*nLuminocities*nDotNumbers;
            
            %calculate sequece of positions and times
            obj.allSpeeds=nan(1,obj.nTotTrials);
            obj.allLuminocities=nan(1,obj.nTotTrials);
            obj.allDotNumbers=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nSpeeds
                for j=1:nLuminocities
                    for k=1:nDotNumbers
                        obj.allSpeeds( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.speeds(i);
                        obj.allLuminocities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.luminosities(j);
                        obj.allDotNumbers( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.dotsNumbers(k);
                        c=c+1;
                    end
                end
            end
            %randomize
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.allSpeeds=obj.allSpeeds(randomPermutation);
                obj.allLuminocities=obj.allLuminocities(randomPermutation);
                obj.allDotNumbers=obj.allDotNumbers(randomPermutation);
            end
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            obj.syncMarkerOn = false; %initialize sync signal
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            
            nFrames = ceil(obj.stimDuration/obj.ifi(1)); % number of animation frames in loop
            obj.flip=nan(obj.nTotTrials,nFrames);
            obj.stim=nan(obj.nTotTrials,nFrames);
            obj.flipEnd=nan(obj.nTotTrials,nFrames);
            obj.miss=nan(obj.nTotTrials,nFrames);
            
            tFrame=(0:obj.ifi:(obj.stimDuration+obj.ifi(1)))';
            tFrame(2:end)=tFrame(2:end)+obj.waitFromOnset;
            obj.screenWidth = obj.visualFieldRect(3:4)-obj.visualFieldRect(1:2);

            %pre calculate the initial conditions for all trials - from these every dot can be calculated later
            for i=1:obj.nTotTrials
                obj.xi{i} = ceil(rand(obj.allDotNumbers(i),2)*[obj.screenWidth(1),0;0,obj.screenWidth(2)]) + obj.visualFieldRect([1,2]);
                obj.vi{i} = rand(obj.allDotNumbers(i),2)-0.5;
                obj.vi{i} = obj.vi{i}./sqrt(obj.vi{i}(:,1).^2+obj.vi{i}(:,2).^2)*obj.allSpeeds(i);
            end

            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials

                tmpLum=obj.allLuminocities(i);
                tmpNum=obj.allDotNumbers(i);

                x=obj.xi{i};
                v=obj.vi{i};
                xAll=zeros([size(x),tmpNum]);
                xAll(:,:,1)=x;
                for f=2:nFrames
                    xAll(:,:,f)=xAll(:,:,f-1)+v*obj.ifi(1);
                    p1=xAll(:,1,f)>=obj.visualFieldRect(3) | xAll(:,1,f)<=obj.visualFieldRect(1);
                    p2=xAll(:,2,f)>=obj.visualFieldRect(4) | xAll(:,2,f)<=obj.visualFieldRect(2);
                    pC=p1|p2;
                    xAll(pC,:,f)=xAll(pC,:,f-1)-v(pC,:)*obj.ifi(1);
                    v(p1,1)=-v(p1,1);
                    v(p2,2)=-v(p2,2);
                    xAll(pC,:,f)=xAll(pC,:,f-1)+v(pC,:)*obj.ifi(1);
                end
                
                %set times for all frames
                j=1; %restart 
                tFrameTmp=tFrame+GetSecs+obj.ifi;
                obj.sendTTL(2,true); %session start trigger (also triggers the recording start)

                % Plots initial dot position
                Screen('DrawDots', obj.PTB_win(1), squeeze(xAll(:,:,j))', obj.dotSize, tmpLum, [] ,1);  % change 1 to 0 to draw square dots [obj.centerX,obj.centerY]
                %[minSmoothPointSize, maxSmoothPointSize, minAliasedPointSize, maxAliasedPointSize] = Screen('DrawDots', windowPtr
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                obj.sendTTL(3,true); %session start trigger (also triggers the recording start)
                [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,tFrameTmp(j));
                obj.sendTTL(3,false); %session start trigger (also triggers the recording start)
                WaitSecs(obj.waitFromOnset);
                
                for j=2:nFrames
                    % Update display
                    Screen('DrawDots', obj.PTB_win(1), squeeze(xAll(:,:,j))', obj.dotSize, tmpLum, [] ,1);  % change 1 to 0 to draw square dots [obj.centerX,obj.centerY]
                    obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)

                    obj.sendTTL(3,true); %session start trigger (also triggers the recording start)
                    [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,tFrameTmp(j));
                    obj.sendTTL(3,false); %session start trigger (also triggers the recording start)
                end
                obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
                [endSessionTime]=Screen('Flip',obj.PTB_win);
                % Start wait: Code here is run during the waiting for the new session
                
                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.interTrialDelay-(GetSecs-endSessionTime));
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger
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
        function obj=VS_linearlyMovingBouncingDots(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration = 10;
        end
    end
end %EOF