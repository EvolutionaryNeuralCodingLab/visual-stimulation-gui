classdef VS_linearlyMovingBouncingDotsCoherence < VStim
    properties (SetAccess=public)
        luminosities = 255; %(L_high-L_low)/L_low
        randomize = true;
        speeds = 100; %pixel per second
        dotsNumbers= 50 % number of dots
        dotSize= 50; % width of dot (pixels)
        coherence = 0.5; %Percentage of dots athat are not moving randomly
        directions = 0; %Directions (in degrees) for coherent motion
        waitFromOnset = 1; %time to wait between dots appearance and dot movement
    end
    properties (Constant)
        luminositiesTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        dotSizeTxt='The size of the dots [pixels]';
        rotateDotsTxt='True/false/[true false] - whether to rotate, zoom or both';
        randomizeTxt='Randomize the order of different trials';
        coherenceTxT  =  'Percentage of dots athat are not moving randomly';
        directionsTxt = 'Directions (in degrees) for coherent motion';
        dotsNumbersTxt='The number of dots to be shown, if array->show all given dot numbers';
        speedTxt='The speed of the moving dots [pixels/sec], if array->show all given speeds';
        waitFromOnsetTxt='The time [s] to wait from presentation of dots to start of motion'
        remarks={'Categories in stimuli are: speed, rotateDots, rotationZoomDirection'};
    end
    properties (SetAccess=protected)
        allSpeeds
        allLuminocities
        allDotNumbers
        allCoherences
        allDirections
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
        function obj = run(obj)
            % === SETUP ===
            % Determine number of parameter combinations
            nSpeeds = numel(obj.speeds);
            nLuminocities = numel(obj.luminosities);
            nDotNumbers = numel(obj.dotsNumbers);
            nCoherences = numel(obj.coherence);
            nDirections = numel(obj.directions);

            % Total number of trials
            obj.nTotTrials = obj.trialsPerCategory * nSpeeds * nLuminocities * nDotNumbers * nCoherences * nDirections;

            % Preallocate arrays for trial parameters
            obj.allSpeeds = nan(1, obj.nTotTrials);
            obj.allLuminocities = nan(1, obj.nTotTrials);
            obj.allDotNumbers = nan(1, obj.nTotTrials);
            obj.allCoherences = nan(1, obj.nTotTrials);
            obj.allDirections = nan(1, obj.nTotTrials);

            % === GENERATE TRIAL PARAMETERS ===
            c = 1;
            for i = 1:nSpeeds
                for j = 1:nLuminocities
                    for k = 1:nDotNumbers
                        for m = 1:nCoherences
                            for d = 1:nDirections
                                idx = ((c - 1) * obj.trialsPerCategory + 1):(c * obj.trialsPerCategory);
                                obj.allSpeeds(idx) = obj.speeds(i);
                                obj.allLuminocities(idx) = obj.luminosities(j);
                                obj.allDotNumbers(idx) = obj.dotsNumbers(k);
                                obj.allCoherences(idx) = obj.coherence(m);
                                obj.allDirections(idx) = obj.directions(d);
                                c = c + 1;
                            end
                        end
                    end
                end
            end

            % Randomize trial order if required
            if obj.randomize
                randPerm = randperm(obj.nTotTrials);
                obj.allSpeeds = obj.allSpeeds(randPerm);
                obj.allLuminocities = obj.allLuminocities(randPerm);
                obj.allDotNumbers = obj.allDotNumbers(randPerm);
                obj.allCoherences = obj.allCoherences(randPerm);
                obj.allDirections = obj.allDirections(randPerm);
            end

            % === SIMULATION MODE CHECK ===
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end

            % === TIMING SETUP ===
            nFrames = ceil(obj.stimDuration / obj.ifi(1));
            obj.flip = nan(obj.nTotTrials, nFrames);
            obj.stim = nan(obj.nTotTrials, nFrames);
            obj.flipEnd = nan(obj.nTotTrials, nFrames);
            obj.miss = nan(obj.nTotTrials, nFrames);

            tFrame = (0:obj.ifi:(obj.stimDuration + obj.ifi(1)))';
            tFrame(2:end) = tFrame(2:end) + obj.waitFromOnset;

            % Compute screen dimensions based on visual field rect
            obj.screenWidth = obj.visualFieldRect(3:4) - obj.visualFieldRect(1:2);

            % === INITIALIZE DOT POSITIONS AND VELOCITIES ===
            for i = 1:obj.nTotTrials
                tmpNum = obj.allDotNumbers(i);
                tmpSpeed = obj.allSpeeds(i);
                tmpCoherence = obj.allCoherences(i);
                tmpDirectionDeg = obj.allDirections(i);

                % Initial dot positions
                obj.xi{i} = ceil(rand(tmpNum, 2) .* obj.screenWidth) + obj.visualFieldRect([1, 2]);

                % Create motion vectors (signal and noise)
                signalN = round(tmpNum * tmpCoherence);
                noiseN = tmpNum - signalN;

                theta = deg2rad(tmpDirectionDeg);
                v_signal = repmat([cos(theta), sin(theta)] * tmpSpeed, signalN, 1);
                randAngles = rand(noiseN, 1) * 2 * pi;
                v_noise = [cos(randAngles), sin(randAngles)] * tmpSpeed;

                v = [v_signal; v_noise];
                v = v(randperm(tmpNum), :);  % Shuffle
                obj.vi{i} = v;
            end

            save tmpVSFile obj;

            % === BEGIN SESSION ===
            disp('Session starting');
            obj.sendTTL(1, true);
            WaitSecs(obj.preSessionDelay);

            for i = 1:obj.nTotTrials
                tmpLum = obj.allLuminocities(i);
                tmpNum = obj.allDotNumbers(i);
                x = obj.xi{i};
                v = obj.vi{i};

                xAll = zeros([size(x), nFrames]);
                xAll(:, :, 1) = x;
                dotRadius = obj.dotSize / 2;

                % === UPDATE DOT POSITIONS ACROSS FRAMES ===
                for f = 2:nFrames
                    xNew = xAll(:, :, f-1) + v * obj.ifi(1);

                    % Wrapping logic: wrap only when the full dot is outside
                    for d = 1:tmpNum
                        if xNew(d,1) + dotRadius < obj.visualFieldRect(1)
                            xNew(d,1) = xNew(d,1) + obj.screenWidth(1);
                        elseif xNew(d,1) - dotRadius > obj.visualFieldRect(3)
                            xNew(d,1) = xNew(d,1) - obj.screenWidth(1);
                        end

                        if xNew(d,2) + dotRadius < obj.visualFieldRect(2)
                            xNew(d,2) = xNew(d,2) + obj.screenWidth(2);
                        elseif xNew(d,2) - dotRadius > obj.visualFieldRect(4)
                            xNew(d,2) = xNew(d,2) - obj.screenWidth(2);
                        end
                    end

                    xAll(:,:,f) = xNew;
                end

                tFrameTmp = tFrame + GetSecs + obj.ifi;
                obj.sendTTL(2, true);

                % === DRAW AND FLIP EACH FRAME ===
                for j = 1:nFrames
                    for iDot = 1:tmpNum
                        dotX = xAll(iDot, 1, j);
                        dotY = xAll(iDot, 2, j);

                        % Draw with full wrapping awareness (may need subfunction)
                        drawWrappedDot(dotX, dotY, dotRadius, obj.visualFieldRect, obj.PTB_win(1), tmpLum, obj.screenWidth);
                    end

                    obj.applyBackgound;
                    obj.sendTTL(3, true);
                    [obj.flip(i, j), obj.stim(i, j), obj.flipEnd(i, j), obj.miss(i, j)] = Screen('Flip', obj.PTB_win, tFrameTmp(j));
                    obj.sendTTL(3, false);
                end

                % === END OF TRIAL ===
                obj.sendTTL(2, false);
                Screen('FillRect', obj.PTB_win, obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;
                endSessionTime = Screen('Flip', obj.PTB_win);

                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);

                % Early exit on escape key
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial = i;
                    return;
                end

                % Inter-trial wait
                WaitSecs(obj.interTrialDelay - (GetSecs - endSessionTime));
            end

            % === END SESSION ===
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1, false);
            disp('Session ended');

            function drawWrappedDot(x, y, r, rect, win, lum, screenSize)
                % drawWrappedDot Draws a dot and its wrapped copies at screen edges
                %
                % This ensures smooth wrapping by drawing the same dot multiple times
                % wherever its edges might overlap the opposite border of the visual field.
                %
                % Inputs:
                %   x, y        - center coordinates of the dot
                %   r           - dot radius (in pixels)
                %   rect        - visual field rect: [left, top, right, bottom]
                %   win         - window pointer for Screen('FillOval')
                %   lum         - dot luminance (color)
                %   screenSize  - width and height of the screen area in [width, height]

                % Define dot coordinates
                dotRect = [x - r, y - r, x + r, y + r];

                % Calculate shifts in horizontal and vertical direction
                xShifts = [0, -screenSize(1), screenSize(1)];
                yShifts = [0, -screenSize(2), screenSize(2)];

                % Loop through all combinations of x and y shifts
                % (i.e., draw up to 9 copies of the dot if near corners)
                for dx = xShifts
                    for dy = yShifts
                        shiftedRect = dotRect + [dx, dy, dx, dy];

                        % Only draw if part of the shifted dot is on screen
                        if IsInRect(shiftedRect(1), shiftedRect(2), rect) || ...
                                IsInRect(shiftedRect(3), shiftedRect(4), rect)
                            Screen('FillOval', win, lum, shiftedRect);
                        end
                    end
                end
            end

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
        function obj=VS_linearlyMovingBouncingDotsCoherence(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration = 10;
        end

    end
end %EOF