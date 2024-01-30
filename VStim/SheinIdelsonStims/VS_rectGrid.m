classdef VS_rectGrid < VStim
    properties (SetAccess=public)
        rectLuminosity = 255; %(L_high-L_low)/L_low
        rectGridSize = 4;
        rectangleAspectRatioOne = true;
        randomize = true;
        tilingRatio = [1];
        rotation = 0;
        shape = 'rectangle';
    end
    properties (Constant)
        rectLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        randomizeTxt='Randomize values';
        shapeeTxt='Switch shape circle/rectangle';
        rectGridSizeTxt='The size [N x N] (width x height) of the rectangular grid';
        rotationTxt='The angle for visual field rotation (clockwise)';
        tilingRatioTxt='The ratio (0-1) beween the total tile length and field length (e.g. if 0.5 tiles are half the size require for complete tiling)';
        rectangleAspectRatioOneTxt='Squares will have an aspect ratio of 1 (can reduce number of squares)'
        remarks={'Categories in Flash stimuli are: Luminocity'};
    end
    properties (Hidden)
        pos2X
        pos2Y
        pos
        luminosities
        pValidRect
        rectData
        rectSide
        tilingRatios
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
            
            nLuminosities=numel(obj.rectLuminosity);
            nTilingRatios=numel(obj.tilingRatio);

            [obj]=calculateRectangularGridPositions(obj); %Calcylate Grid positions for each ratio

            nPositions=numel(obj.pValidRect);
            obj.nTotTrials=obj.trialsPerCategory*nLuminosities*nPositions*nTilingRatios;
           
            %calculate sequece of positions and times
            obj.pos=nan(1,obj.nTotTrials);
            obj.luminosities=nan(1,obj.nTotTrials);
            obj.tilingRatios=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nPositions
                for j=1:nLuminosities
                    for k=1:nTilingRatios
                        obj.pos( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=i;
                        obj.luminosities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=j;
                        obj.tilingRatios( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=k;
                        c=c+1;
                    end
                end
            end
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.pos=obj.pos(randomPermutation);
                obj.luminosities=obj.luminosities(randomPermutation);
                obj.tilingRatios=obj.tilingRatios(randomPermutation);
            end
            obj.pos=[obj.pos obj.pos(1)]; %add an additional stimulus that will never be shown
            obj.luminosities=[obj.luminosities obj.luminosities(1)]; %add an additional stimulus that will never be shown
            obj.tilingRatios=[obj.tilingRatios obj.tilingRatios(1)];

            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;

            % Update image buffer for the first time
            if strcmp(obj.shape,'circle')
                for i=1:nPositions
                    for j=1:nLuminosities
                        for k=1:nTilingRatios % on tile ratio
                            I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
                            x0=round((obj.rectData.X1{k}(obj.pValidRect(i))+obj.rectData.X3{k}(obj.pValidRect(i)))/2);
                            y0=round((obj.rectData.Y1{k}(obj.pValidRect(i))+obj.rectData.Y3{k}(obj.pValidRect(i)))/2);

                            pX=obj.rectData.X1{k}(obj.pValidRect(i)):obj.rectData.X3{k}(obj.pValidRect(i));
                            pY=obj.rectData.Y1{k}(obj.pValidRect(i)):obj.rectData.Y3{k}(obj.pValidRect(i));
                            [Xtmp,Ytmp]=meshgrid(pX,pY);
                            pV=((Xtmp-x0).^2+(Ytmp-y0).^2)<(obj.rectSide(k)/2).^2;%*obj.tilingRatio(k);
                            tmpInd=sub2ind(size(I),Xtmp(pV),Ytmp(pV));
                            I(tmpInd)=obj.rectLuminosity(j);
                            imgTex(i,j,k)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
                        end
                    end
                end
            elseif strcmp(obj.shape,'rectangle')
                for i=1:nPositions
                    for j=1:nLuminosities
                        for k=1:nTilingRatios
                            I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
                            I(obj.rectData.X1{k}(obj.pValidRect(i)):obj.rectData.X3{k}(obj.pValidRect(i)),obj.rectData.Y1{k}(obj.pValidRect(i)):obj.rectData.Y3{k}(obj.pValidRect(i)))=obj.rectLuminosity(j);
                            imgTex(i,j,k)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
                        end
                    end
                end
            end

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
            save tmpVSFile obj; %temporarily save object in case of a system crash
            disp('Session starting');

            Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(1),obj.luminosities(1),obj.tilingRatios(1)),[],obj.visualFieldRect,obj.rotation);
            obj.applyBackgound;

            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
                [obj.on_Flip(i),obj.on_Stim(i),obj.on_FlipEnd(i),obj.on_Miss(i)]=Screen('Flip',obj.PTB_win);
                %pp(uint8(obj.trigChNames(2)),[true true],false,uint8(0),uint64(32784)); %stim onset trigger
                 obj.sendTTL(2,true);               
                % Update display
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;

                [obj.off_Flip(i),obj.off_Stim(i),obj.off_FlipEnd(i),obj.off_Miss(i)]=Screen('Flip',obj.PTB_win,obj.on_Flip(i)+obj.actualStimDuration-0.5*obj.ifi);
               % pp(uint8(obj.trigChNames(2)),[false false],false,uint8(0),uint64(32784)); %stim offset trigger
                   obj.sendTTL(2,false); 
                % Update image buffer for the first time
                Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(i+1),obj.luminosities(i+1),obj.tilingRatios(i+1)),[],obj.visualFieldRect,obj.rotation);
                obj.applyBackgound;

                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    obj.sendTTL(1,false);
                    return;
                end
                
                WaitSecs(obj.interTrialDelay-(GetSecs-obj.off_Flip(i)));
            end
            obj.pos(end)=[]; %remove the last stim which is not shown
            obj.luminosities(end)=[];%remove the last stim which is not shown
            obj.tilingRatios(end)=[];%

            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger
            disp('Session ended');
            Screen('Close',imgTex);
        end
        
        function obj=CMShowGrid(obj,srcHandle,eventData,hPanel)
            
            obj.tilingRatio(1)=obj.tilingRatio(1)*0.95;
            %obj.calculatePositions;
            disp('Positions are not recalculated. Check in the future!')
            obj.tilingRatio(1)=obj.tilingRatio(1)/0.95;
            nPositions=numel(obj.pValidRect);
            
            Screen('TextFont',obj.PTB_win, 'Courier New');
            Screen('TextSize',obj.PTB_win, 13);
            
            % Update image buffer for the first time
            I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
            for i=1:nPositions
                I(obj.rectData.X1(obj.pValidRect(i)):obj.rectData.X3(obj.pValidRect(i)),obj.rectData.Y1(obj.pValidRect(i)):obj.rectData.Y3(obj.pValidRect(i)))=obj.rectLuminosity;
            end
            imgTex=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
            Screen('DrawTexture',obj.PTB_win,imgTex,[],obj.visualFieldRect,obj.rotation);
            
            for i=1:nPositions
                Screen('DrawText', obj.PTB_win, num2str(i),obj.visualFieldRect(1)+obj.rectData.Y1(obj.pValidRect(i)),obj.visualFieldRect(2)+obj.rectData.X1(obj.pValidRect(i)),[min(obj.rectLuminosity+50,255) 0 0],[]);
                
                %DrawFormattedText(obj.PTB_win, num2str(i), obj.rectData.X1(obj.pValidRect(i)),obj.rectData.Y1(obj.pValidRect(i)),[255 0 0]);
            end
            
            obj.applyBackgound;
            Screen('Flip',obj.PTB_win);
            
            while 1
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                    obj.applyBackgound;
                    Screen('Flip',obj.PTB_win);
                    Screen('Close',imgTex);
                    obj.sendTTL(1,false);
                    return;
                end
            end
            
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            if nargin==2
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
        function obj=VS_rectGrid(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF