classdef VS_mrMovingBarsBatch < VStim
    properties (SetAccess=public)

        nTrials   = 5;%5
        nDirections     = 8;%8
        barWidth    = 333; %2497.5um
        barLength   = 120; %900 um
        barSpeed       = 80; %600um/sec
        maskRadius  = 500; %for the mea 400pix(3000px)should be fine
        barIntensity= 255; %white bar
        popBbarColor    = [1 1 1]; %white
        prestimWait = 5;
        delay       = 0.5; %2
        interTrialWait = 0.5; %2
        save_stimulus   = 0;
        screenIntensity = 0;%intensity when you project the bar, change to mean grey if you want white bar on grey screen
        popBscrColor    =[1 1 1]; %white
        chkBshowFlashesForGUI = 0;
        txtBflashPeriod = 1;
        txtBflashNumber = 2;
        directionList     = nan;
        chkBsaveImage   = 0;
        txtBsaveImageTime = 2;
        
    end
    properties (Hidden,Constant)
        barIntensityTxt    = 'The luminocity value for the rectangles, if array->show all given contrasts';
        barWidthTxt         = 'The width of the moving bar [pixels] - parallel to motion direction (<10)';
        barLengthTxt        = 'The length of the moving bar [pixels] - perpendicular to motion direction (<number of pixels in the smaller screen axis)';
        nDirectionsTxt = 'The number of directions to test (directions will be distributed uniformly over 360 degrees)';
        randomizeTxt        = 'Randomize the order of different trials';
        barSpeedTxt            = 'The speed of the moving object [pixels/sec]';
        parallelsOffsetTxt  = 'the offset [pixels] of parallel propagation paths'
        skipFramesTxt       = 'if to only show a subset of frames';
        remarks             = {'Categories in stimuli are: speed, offset'};
    end
    properties (SetAccess=protected)
        speeds
%         directions
        offsets
        barTrajectories1X
        barTrajectories2X
        barTrajectories1Y
        barTrajectories2Y
        nFrames
    end
    properties (Hidden, SetAccess=protected)
        flip
        stim
        flipEnd
        miss
    end
    methods
        
        function obj=run(obj)
          
            screen_full_color = obj.screenIntensity*obj.popBscrColor;
            if isnan(obj.directionList) 
                dirs = 0:(360/obj.nDirections):(360-(360/obj.nDirections));
            elseif isempty(obj.directionList) 
                dirs = 0:(360/obj.nDirections):(360-(360/obj.nDirections));
            else
                dirs = obj.directionList;
                dims = size(dirs);
                if dims(1)>dims(2)
                    dirs = dirs';
                end
            end
            directions = [];
            for r=1:obj.nTrials
                dirs_shuffled = Shuffle(dirs);
                directions=cat(2,directions,dirs_shuffled);
            end
            directions=directions';
            padding = 1;
            bar_full_color = obj.barIntensity*obj.popBbarColor;
            barTex = ones(obj.barWidth, obj.barLength+(2*padding), 2);
            for  ii =1:3   % 3 because of RGB                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
                barTex(1:obj.barWidth, 1+padding:obj.barLength+padding, ii) = bar_full_color(ii);
            end
            tex = Screen('MakeTexture', obj.PTB_win, barTex);
            
            %SR added this
            WaitSecs(obj.prestimWait); % duration of background (default: 2 sec)
            
            [x,y] = RectCenter(obj.rect);
            
            obj.maskRadius      = obj.maskRadius+obj.barLength/2; %added to fix the starting and ending position of bar
            start_maskRadius    = obj.maskRadius;
            endmaskRadius       = -obj.maskRadius;
            frame_rate          = 1/Screen('GetFlipInterval',obj.PTB_win);
            obj.sendTTL(1,true);
            for trial = 1 : length(directions)
                direction           = directions(trial);
                screen_full_color   = obj.screenIntensity*obj.popBscrColor;
                [width, height]     = Screen('WindowSize', obj.PTB_win);
                srcRect             = [0 0 floor(height/2) width];
                mask                = makeCircularMaskForGUI(obj.maskRadius,width, height,'color',screen_full_color);
                masktex             = Screen('MakeTexture', obj.PTB_win, mask);
                maskradius          = obj.maskRadius;
                obj.sendTTL(2,true);
                while maskradius >= endmaskRadius  
                    x_maskRadius    = maskradius;
                    y_maskRadius    = maskradius;
                    screen_full_color   = obj.screenIntensity*obj.popBscrColor;
                    Screen('FillRect', obj.PTB_win, screen_full_color, []);
                    startPos    = [x-(x_maskRadius*cosd(direction)) y-(y_maskRadius*sind(direction))];% startPosition [x y]
                    dstRect     = [0 0 obj.barLength+(2*padding) obj.barWidth];
                    dstRect     = CenterRectOnPoint(dstRect, startPos(1), startPos(2));
                    Screen('DrawTexture',obj.PTB_win,tex,[],dstRect,direction,1);
                    obj.sendTTL(3,true);
                    [keyIsDown, ~, keyCode] = KbCheck;
                    if keyCode(obj.escapeKeyCode)
                        % obj.trialsPerCategory=i;
                        Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                        Screen('Flip',obj.PTB_win);
                        obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                        % WaitSecs(obj.interTrialDelay);
                        disp('Trial ended early');
                        return
                    end
                    Screen('Flip', obj.PTB_win);
                    obj.sendTTL(3,false);
                    maskradius = maskradius-(obj.barSpeed/frame_rate);
                end
                obj.sendTTL(2,false);
                disp(['Direction ' num2str(trial) '/' num2str(obj.nTrials*obj.nDirections)]);
                WaitSecs(obj.interTrialWait);%pause to allow recording device to prepare for new trial
            end
            Screen('FillRect', obj.PTB_win, screen_full_color, []);
            Screen('Flip', obj.PTB_win);
            obj.sendTTL(1,false);
            SaveStimuli(obj,mfilename,'directions',directions)
        end

        function outStats=getLastStimStatistics(obj,hFigure)
           outStats.props=obj.getProperties; 
        end
        %class constractor
        function obj=VS_mrMovingBarsBatch(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=NaN;
        end
    end
end %EOF