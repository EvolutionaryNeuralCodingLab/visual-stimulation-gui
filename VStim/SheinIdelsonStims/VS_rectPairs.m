classdef VS_rectPairs < VStim
    properties (SetAccess=public)
        rectLuminosity = 255; %(L_high-L_low)/L_low
        rectGridSize = 4;
        randomize = true;
        tilingRatio = 1;
        rotation = 0;
        pairsRatio = 0.5;
    end
    properties (Constant)
        rectLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        randomizeTxt='Randomize values';
        rectGridSizeTxt='The size (N x N) of the rectangular grid';
        rotationTxt='The angle for visual field rotation (clockwise)';
        tilingRatioTxt='The ratio (0-1) beween the total tile length and field length (e.g. if 0.5 tiles are half the size require for complete tiling)';
        remarks={'Categories in Flash stimuli are: Luminocity'};
    end
    properties (SetAccess=protected)
        pos2X
        pos2Y
        pos
        luminosities
        pValidRect
        rectData
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
        
        function obj=calculatePositions(obj)
            %calculate the coordinates for the rectangles that fit into the visual space
            centerX=obj.actualVFieldDiameter/2;
            centerY=obj.actualVFieldDiameter/2;
            
            %calculate the coordinates for the rectangles that fit into the visual space
            rectSpacing=floor(obj.actualVFieldDiameter/obj.rectGridSize)-1;
            rectSide=rectSpacing*obj.tilingRatio;
            edges=floor((rectSpacing-rectSide)/2):rectSpacing:(obj.actualVFieldDiameter-rectSide);
            edges=floor(edges+((obj.actualVFieldDiameter-(edges(end)+rectSide))-edges(1))/2);
            [X1,Y1]=meshgrid(edges,edges);
            X1=X1;
            Y1=Y1;
            X2=X1+rectSide-1;
            Y2=Y1;
            X3=X1+rectSide-1;
            Y3=Y1+rectSide-1;
            X4=X1;
            Y4=Y1+rectSide-1;
            %find rects that dont overlap with syncSquare
            syncSquareSizePix   = 60;
            obj.pValidRect=find(X1>syncSquareSizePix & Y3<(obj.actualVFieldDiameter-syncSquareSizePix));
            %move data to object
            obj.rectData.X1=X1;obj.rectData.Y1=Y1;
            obj.rectData.X2=X2;obj.rectData.Y2=Y2;
            obj.rectData.X3=X3;obj.rectData.Y3=Y3;
            obj.rectData.X4=X4;obj.rectData.Y4=Y4;
            
            %calculate X and Y position for the valid places
            obj.pos2X=rem(obj.pValidRect,obj.rectGridSize);
            obj.pos2X(obj.pos2X==0)=obj.rectGridSize;
            
            obj.pos2Y=ceil((obj.pValidRect-0.5)/obj.rectGridSize);
            
            obj.pos2X=obj.pos2X-min(obj.pos2X)+1;
            obj.pos2Y=obj.pos2Y-min(obj.pos2Y)+1;
            
        end
        
        function obj=run(obj)
            
            obj.calculatePositions;
            
            nPositions=numel(obj.pValidRect);
            nLuminosities=numel(obj.rectLuminosity);
            pairs=nchoosek(1:nPositions,2);
            totPairs=nchoosek(nPositions,2);
            randPairs=randperm(totPairs);
            permutPairs=pairs(randPairs,:);
            nPairs=totPairs*obj.pairsRatio;
            pairBank=permutPairs(1:nPairs,:);
            obj.nTotTrials=(obj.trialsPerCategory*nLuminosities*nPositions+obj.trialsPerCategory*nLuminosities*nPairs);
            
            %calculate sequece of positions and times
            obj.pos=nan(2,obj.nTotTrials);
            obj.luminosities=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nPositions
                for j=1:nLuminosities
                    obj.pos( 1,((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=i;
                    obj.luminosities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=j;
                    c=c+1;
                end
            end
            obj.pos(2,1:nPositions*obj.trialsPerCategory)=0; %padding with zeros for one rect trials
            for i=1:nPairs
                for j=1:nLuminosities
                    obj.pos(1,((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=pairBank(i,1);
                    obj.pos(2,((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=pairBank(i,2);
                    obj.luminosities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=j;
                    c=c+1;
                end
            end
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.pos=obj.pos(:,randomPermutation);
                obj.luminosities=obj.luminosities(randomPermutation);
            end
            obj.pos=[obj.pos obj.pos(:,1)]; %add an additional stimulus that will never be shown
            obj.luminosities=[obj.luminosities obj.luminosities(1)]; %add an additional stimulus that will never be shown
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;

            %obj.syncMarkerOn
            % Update image buffer for the first time
            for i=1:nPositions
                for j=1:nLuminosities
                    I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
                    I(obj.rectData.X1(obj.pValidRect(i)):obj.rectData.X3(obj.pValidRect(i)),obj.rectData.Y1(obj.pValidRect(i)):obj.rectData.Y3(obj.pValidRect(i)))=obj.rectLuminosity(j);
                    imgTex(i,j)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
                end
            end
            for i=1:nPairs
                for j=1:nLuminosities
                    I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
                    I(obj.rectData.X1(obj.pValidRect(pairBank(i,1))):obj.rectData.X3(obj.pValidRect(pairBank(i,1))),obj.rectData.Y1(obj.pValidRect(pairBank(i,1))):obj.rectData.Y3(obj.pValidRect(pairBank(i,1))))=obj.rectLuminosity(j);
                    I(obj.rectData.X1(obj.pValidRect(pairBank(i,2))):obj.rectData.X3(obj.pValidRect(pairBank(i,2))),obj.rectData.Y1(obj.pValidRect(pairBank(i,2))):obj.rectData.Y3(obj.pValidRect(pairBank(i,2))))=obj.rectLuminosity(j);
                    imgTex2(i,j)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
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
            
            if obj.pos(2,1)==0
                Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(1,1),obj.luminosities(1)),[],obj.visualFieldRect,obj.rotation);
                
            else
                Screen('DrawTexture',obj.PTB_win,imgTex2(pairBank(:,1)==obj.pos(1,1)&pairBank(:,2)==obj.pos(2,1),obj.luminosities(1)),[],obj.visualFieldRect,obj.rotation);
                
            end
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
                
                if obj.pos(2,i+1)==0
                    Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(1,i+1),obj.luminosities(i+1)),[],obj.visualFieldRect,obj.rotation);
                else
                    Screen('DrawTexture',obj.PTB_win,imgTex2(pairBank(:,1)==obj.pos(1,i+1)&pairBank(:,2)==obj.pos(2,i+1),obj.luminosities(i+1)),[],obj.visualFieldRect,obj.rotation);
                end
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
            
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger
            disp('Session ended');
            Screen('Close',imgTex);
        end
        
        function obj=CMShowGrid(obj,srcHandle,eventData,hPanel)
            
            obj.tilingRatio=obj.tilingRatio*0.95;
            obj.calculatePositions;
            obj.tilingRatio=obj.tilingRatio/0.95;
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
        function obj=VS_rectPairs(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.inVivoSettings = true;
        end
    end
end %EOF