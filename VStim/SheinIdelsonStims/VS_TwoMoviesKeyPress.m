classdef VS_TwoMoviesKeyPress < VStim
    properties (SetAccess=public)
        playAsImgSequence = true;
        randomize = true;
        loops = 1;
        skipFrames = 0;
        initialFrozenFrames = 0;
        trialTimeOut = 60;
    end
    properties (SetObservable, SetAccess=public)
        rotation = 0;
    end
    properties (Constant)
        CMloadMovieTxt='load movie file or sequence of images to be presented as a movie';
        CMsaveVideoAsSingleImagesTxt='save single movie images as presented on the screen';
        skipFramesTxt='Show movie in lower temporal resolution than screen refresh by skipping n frames per frame (e.g. use 1 for showing 30Hz movie on 60Hz display)';
        playAsImgSequenceTxt='Play movie using the ptb movie function or as sequence of textures (frames)';
        rotationTxt='The angle for visual field rotation (clockwise)';
        nMoviesTxt='the number of movies to play';
        loopsTxt='Number of times to play the movie in a single trial';
        trialTimeOutTxt='The timeout afterwhich if prey is not caught, the trial is canceled';
        remarks={'Categories in stimuli are: speed, rotateDots, rotationZoomDirection'};
    end
    properties (SetAccess=protected)
        nVideos
        movieSequence
        movTex
        movPtr
        movDuration
        movFps
        movWidth
        movHeight
        movFrameCount
        movAspectRatio
        movieFileName
        movPathName
    end
    properties (Hidden, SetAccess=protected)
        flip
        stim
        flipEnd
        miss
        syncTime
    end
    
    methods
        
        function obj=run(obj)
            
            obj.nTotTrials=obj.trialsPerCategory*obj.nVideos;
            obj.interTrialDelay=nan(1,obj.nTotTrials);
            %calculate sequence of positions and times
            obj.movieSequence=reshape(repmat(1:obj.nVideos,obj.trialsPerCategory,1),1,size(repmat(1:obj.nVideos,obj.trialsPerCategory,1),1)*size(repmat(1:obj.nVideos,obj.trialsPerCategory,1),2));
            
            
            %randomize
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.movieSequence=obj.movieSequence(randomPermutation);
            end
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false;
            Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            Screen('DrawTexture',obj.PTB_win,obj.masktexOff);
            Screen('Flip',obj.PTB_win);
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            
            obj.flip=nan(obj.nVideos,obj.nTotTrials,obj.initialFrozenFrames+max(obj.movFrameCount));
            obj.stim=nan(obj.nVideos,obj.nTotTrials,obj.initialFrozenFrames+max(obj.movFrameCount));
            obj.flipEnd=nan(obj.nVideos,obj.nTotTrials,obj.initialFrozenFrames+max(obj.movFrameCount));
            obj.miss=nan(obj.nVideos,obj.nTotTrials,obj.initialFrozenFrames+max(obj.movFrameCount));
            
            %Prepare display gui
            screenPosExperimenterSignal=obj.screenPositionsMatlab(2,:);
            screenPosExperimenterSignal(1:2)=[screenPosExperimenterSignal(1:2)+[300 600]];screenPosExperimenterSignal(3:4)=[150 300];
            createMsg.Interpreter='tex';
            createMsg.WindowStyle = 'non-modal';
            hMsgBox = msgbox('\fontsize{200}-','Value',createMsg);
            hMsgBox.Children(1).delete;
            %hJavaMsg = get(hMsgBox,'JavaFrame');

            for i=1:obj.nVideos
                tFrame{i}=( 0 : ((obj.skipFrames+1)*obj.ifi) : (( (obj.skipFrames+1)*obj.ifi)*(obj.initialFrozenFrames+obj.movFrameCount(i)-1)) )';
                frameIdx{i}=[ones(1,obj.initialFrozenFrames) 1:obj.movFrameCount(i)];
            end
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
                       
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials
                trialStopped=false;
                currMovie=obj.movieSequence(i);
                
                %wait for a key to be pressed to start a trial
                fprintf('Movie %d preared - waiting for any mouse key press to start next trial...',currMovie);
                hMsgBox.Children.Children.String=['\fontsize{200}' num2str(currMovie)];figure(hMsgBox);%hJavaMsg.requestFocus;
                
                [clicks,~,~,whichButton] = GetClicks(obj.PTB_win);
                startTrialTime=GetSecs;
                disp('Waiting for any mouse key press to mark pray catch...');

                obj.sendTTL(2,true); %session start trigger (also triggers the recording start)
                
                frameTTL=true;
                if ~obj.playAsImgSequence
                    [droppedframes] = Screen('PlayMovie', obj.movPtr(currMovie), 1, obj.loops);
                else
                    for k=1:obj.loops
                        tFrameTmp=tFrame{currMovie}+GetSecs+obj.ifi/2;
                        for j=frameIdx{currMovie}
                            % Update display
                            Screen('DrawTexture',obj.PTB_win,obj.movTex(j,currMovie),[],obj.visualFieldRect,obj.rotation);
                            obj.applyBackgound;
                            
                            [obj.flip(currMovie,i,j),obj.stim(currMovie,i,j),obj.flipEnd(currMovie,i,j),obj.miss(currMovie,i,j)]=Screen('Flip',obj.PTB_win,tFrameTmp(j));
                            obj.sendTTL(3,frameTTL);
                            frameTTL=~frameTTL;
                            
                            [~,~,buttons] = GetMouse(obj.PTB_win);
                            if(buttons(1)==1)
                                obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                                obj.interTrialDelay(i)=GetSecs-startTrialTime;
                                trialStopped=true;
                                disp('Prey catch captured!!!');
                                break;
                            end
                        end
                    if trialStopped, break; end
                    end
                end
                [endSessionTime]=GetSecs;
                obj.sendTTL(3,false);
                
                % Start wait: Code here is run during the waiting for the new session
                obj.syncMarkerOn = true; %
                
                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    s=input('Experiment halted! to resume press r (or another key) and Enter, to stop and save press s and Enter: ','s');
                    if ~isempty(s)
                        if (s=='s' || s=='S')
                            return;
                        end
                    end
                end
                
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;
                Screen('Flip',obj.PTB_win);
                %WaitSecs(obj.interTrialDelay-(GetSecs-endSessionTime));
                
                %wait for a key to be pressed to start a trial
                if ~trialStopped
                    tTimeOut=GetSecs;
                    while GetSecs-tTimeOut < obj.trialTimeOut
                        [~,~,buttons] = GetMouse(obj.PTB_win);
                        if(buttons(1)==1)
                                break;
                        end
                    end
                    obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                    obj.interTrialDelay(i)=GetSecs-startTrialTime;
                    disp('Trial ended!!!!');
                end
            end
            
            WaitSecs(obj.postSessionDelay);
            
            obj.sendTTL(1,false); %session end trigger

            delete(hMsgBox);
            disp('Session ended');
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            
            figure;
            text(0.1,0.5,{'Statistics code not written','please add to method!!!'},'FontSize',20);
        end
        
        function cleanUp(obj)
            %clear previous textures
            if ~isempty(obj.movTex)
                Screen('Close',obj.movTex);
                obj.movTex=[];
            end
        end
        
        function obj=CMloadMovie(obj,srcHandle,eventData,hPanel)
            [obj.movieFileName, obj.movPathName] = uigetfile('*.*','Choose movie files or series of images named *_F001-*_FXXX','MultiSelect','On');
            obj.nVideos=numel(obj.movieFileName);
            obj.calculateVideoTextures;
        end
        
        function obj=calculateVideoTextures(obj,event,metaProp)
            disp(['preparing textures with rotation ' num2str(obj.rotation) ' !!!!']);
            obj.cleanUp;
            
            if obj.playAsImgSequence
                for iMov=1:obj.nVideos
                    disp('Uploading video to memory...');
                    readerObj=VideoReader([obj.movPathName obj.movieFileName{iMov}]);
                    frameRatio=readerObj.FrameRate/(1/obj.ifi);
                    %frameRatio=1;
                    vid=read(readerObj);
                    [M,N,l,numF]=size(vid);
                    
                    obj.movFrameCount(iMov)=floor(numF./frameRatio);
                    disp('Calculating single frame textures:');
                    fprintf('Mov %d:',iMov);
                    for i=1:obj.movFrameCount(iMov)
                        
                        if obj.inVivoSettings==1;
                            obj.movTex(i,iMov)=Screen('MakeTexture', obj.PTB_win,squeeze(vid(:,:,:,ceil(i*frameRatio))),obj.rotation);
                        elseif N>=M
                            cutPixels=round((N-M)/2);
                            obj.movTex(i,iMov)=Screen('MakeTexture', obj.PTB_win,squeeze(vid(:,(cutPixels+1):(end-cutPixels),:,ceil(i*frameRatio))),obj.rotation);
                        else
                            cutPixels=round((M-N)/2);
                            obj.movTex(i,iMov)=Screen('MakeTexture', obj.PTB_win,squeeze(vid(:,:,(cutPixels+1):(end-cutPixels),ceil(i*frameRatio))),obj.rotation);
                        end
                        fprintf('%d ',i);
                    end
                    delete(readerObj);
                end
            else
                for iMov=1:obj.nVideos
                [obj.movPtr(iMov),obj.movDuration(iMov),obj.movFps(iMov),obj.movWidth(iMov),obj.movHeight(iMov),obj.movFrameCount(iMov),obj.movAspectRatio(iMov)]=...
                    Screen('OpenMovie',obj.PTB_win,[obj.movPathName obj.movieFileName{iMov}]);
                end
            end
            fprintf('\n');
            disp(['Done preparing movie ' num2str(obj.movFrameCount) ' textures']);
        end
        
    
        function obj=CMsaveVideoAsSingleImages(obj,srcHandle,eventData,hPanel)
            
            [fileName, pathName] = uiputfile('*.*','Choose file base name');
            
            disp('Exporting movie to single images...');
            for i=1:obj.nVideos
                frameIdx=[ones(1,obj.initialFrozenFrames) 1:obj.movFrameCount(i)];
                f=figure;
                c=1;
                for j=frameIdx
                    fprintf('%d ',j);
                    % Update display
                    Screen('DrawTexture',obj.PTB_win,obj.movTex(j,i),[],obj.visualFieldRect,obj.rotation);
                    obj.applyBackgound;
                    
                    Screen('Flip',obj.PTB_win);
                    WaitSecs(0.1);
                    imageArray=Screen('GetImage',obj.PTB_win);
                    
                    hh=imshow(imageArray);
                    print(f,[pathName fileName '_' num2str(i) '_' num2str(c,'%.4d')],'-djpeg','-r200');
                    delete(hh);
                    c=c+1;
                end
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;
                Screen('Flip',obj.PTB_win);
                WaitSecs(0.1);
                imageArray=Screen('GetImage',obj.PTB_win);
                hh=imshow(imageArray);
                print(f,[pathName fileName num2str(j+1,'%.4d')],'-djpeg','-r200');
            end
        end
        
        %class constractor
        function obj=VS_TwoMoviesKeyPress(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=NaN;
            obj.interTrialDelay=NaN;
            obj.syncSquareSizePix=20;
            obj.inVivoSettings=true;
            addlistener(obj,'rotation','PostSet',@obj.calculateVideoTextures); %add a listener to rotation, after its changed the textures should be updated
        end
    end
end %EOF