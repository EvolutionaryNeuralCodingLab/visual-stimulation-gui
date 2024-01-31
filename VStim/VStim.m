classdef (Abstract) VStim < handle
    properties (SetAccess=public)
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        interTrialDelay     = 0.5; %sec
        trialsPerCategory   = 1;
        preSessionDelay     = 1;
        postSessionDelay    = 0;
        trialStartTrig      = 'MC=2,Intan=6';
        experimenterName = '';
    end
    properties (SetObservable, AbortSet = true, SetAccess=public)
        visualFieldBackgroundLuminance  = 0; %mean grey value measured by SR and AH the 04-12-19 136
        visualFieldDiameter             = 0; %pixels
        showOnFullScreen                = 1; %0 - retina, 1- whole screen, 2- rectangle
        DMDcorrectionIntensity          = 0;
        stimDuration                    = 2;
        backgroundMaskSteepness         = 0.2;
        horizontalShift                 = 0;
        numPixels                       = 100;
        numMicrons                      = 100;
        sendMail                        = false;
    end
    properties (Constant)
        backgroudLuminance = 0;             %The background luminance
        maxTriggers=4;                      %The maximal number of triggers used for syncing
        digitalIOPlatforms = {'parallelPort-Win','parallelPort-Linux','onScreen','LabJack-Win'};

        %tooltips for the different class properties
        visualFieldBackgroundLuminanceTxt   = 'The luminance of the circular visual field that is projected to the retina';
        visualFieldDiameterTxt              = 'The diameter of the circular visual field that is projected to the retina [pixels], 0 takes maximal value';
        stimDurationTxt                     = 'The duration of the visual stimuls [s]';
        interTrialDelayTxt                  = 'The delay between trial end and new trial start [s], if vector->goes over all delays';
        trialsPerCategoryTxt                = 'The number of repetitions shown per category of stimuli';
        preSessionDelayTxt                  = 'The delay before the begining of a recording session [s]';
        postSessionDelayTxt                 = 'The delay after the ending of a recording session [s]';
        backgroundMaskSteepnessTxt          = 'The steepness of the border on the visual field main mask [0 1]';
        numPixelsTxt                        = 'The number of pixels to convert to um';
        stimPixelAreaTxt                    = 'The area on the screen in pixels where stimulation is presented [left, top, right, bottom]'
        showOnFullScreenTxT                 = 'Visual stimulation screen limits: 0=circular apperture; 1=full screen; 2=rectangular apperture'
    end
    properties (SetAccess=protected)
        mainDir     % main directory of visual stimulation toolbox
        rect        % the coordinates of the screen [pixels]: (left, top, right, bottom)
        fps         % monitor frames per second
        ifi         % inter flip interval for monitor
        actualStimDuration % the actual stim duration as an integer number of frames
        centerX     % the X coordinate of the visual field center
        centerY     % the Y coordinate of the visual field center
        actualVFieldDiameter % the actual diameter of the visual field
        nTotTrials = []; %the total number of trials in a stimulatin session
        nPTBScreens=[]; %number of screens to use for visual stimulation
        hInteractiveGUI %in case GUI is needed to interact with visual stimulation
        selectedDigitalIO='parallelPort-Win';
        digiNamesNET %only for LabJack - NET arrays for sending trigs names
        digiValuesNET %only for LabJack - NET arrays for sending trig values
    end

    properties (Hidden, SetAccess=protected)
        fSep = '\';
        escapeKeyCode   = []; %the key code for ESCAPE
        dirSep          = filesep; %choose file/dir separator according to platform
        OSPlatform      = 1 %checks what is the OS for sending TTLs: Window (1) or Linux (2) or simulation mode (3)
        computerName = [] %for exceptions on specific computers
        binaryMultiplicator = [1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768]; %512 1024 2048 4096 8192 16384 32768
        currentBinState     = [false false false false false false false false false false false false false false false false]; %false false false false false false false
        ioObj %parallel port communication object for PC
        parallelPortNum =  hex2dec('037F')%888; %Parallel port default number
        displaySyncSignal=true;
        pixelConversionFactor = 100/13; %microns per pixel
        sendMailTo %mail adresses to which a notificaion will be sent at the end of the stimulation (if sendMail=true)
        stimSavePath = "C:\Stimulations\"
        PTB_win                         %Pointer to PTB window
        whiteIdx                        %white index for screen
        blackIdx                        %black index for screen
        masktexOn                       %the mask texture for visual field with on rectangle on bottom left corner
        masktexOff                      %the mask texture for visual field with off rectangle on bottom left corner
        visualFieldBackgroundTex        %the background texture (circle) for visual field
        errorMsg            = [];       %The message the object returns in case of an error
        simulationMode      = false;    %a switch that is used to prepare visual stimulation without applying the stimulation itself
        lastExcecutedTrial  = 0;        %parameter that keeps the number of the last excecuted trial
        syncSquareSizePix               % the size of the the corder square for syncing stims
        syncSquareScreenFraction = 0.07 % the ratio relative to screen height of the the corder square for syncing stims
        syncSquareLuminosity= 255;      % The luminocity of the square used for syncing
        syncMarkerOn        = false;
    end

    properties (Hidden)
        trigChNames %the channel order for triggering in parallel port (first channel will be one)
        screenPositionsMatlab;
        visualFieldRect                 % the coordinates of the rectanle of visual field [pixel]
    end

    methods
        %class constractor
        function obj=VStim(PTB_WindowPointer,interactiveGUIhandle)
            addlistener(obj,'visualFieldBackgroundLuminance','PostSet',@obj.initializeBackground); %add a listener to visualFieldBackgroundLuminance, after its changed its size is updated in the changedDataEvent method
            addlistener(obj,'horizontalShift','PostSet',@obj.initializeBackground); %add a listener to visualFieldBackgroundLuminance, after its changed its size is updated in the changedDataEvent method
            addlistener(obj,'visualFieldDiameter','PostSet',@obj.initializeBackground); %add a listener to visualFieldDiameter, after its changed its size is updated in the changedDataEvent method
            addlistener(obj,'DMDcorrectionIntensity','PostSet',@obj.initializeBackground); %add a listener to visualFieldDiameter, after its changed its size is updated in the changedDataEvent method
            addlistener(obj,'showOnFullScreen','PostSet',@obj.initializeBackground); %add a listener to visualFieldDiameter, after its changed its size is updated in the changedDataEvent method
            addlistener(obj,'backgroundMaskSteepness','PostSet',@obj.initializeBackground); %add a listener to backgroundMaskSteepness, after its changed its size is updated in the changedDataEvent method
            addlistener(obj,'stimDuration','PostSet',@obj.updateActualStimDuration); %add a listener to stimDuration, after its changed its size is updated in the changedDataEvent method
            addlistener(obj, 'numPixels', 'PostSet', @(src,event)disp([num2str(obj.numPixels), ' is ', num2str(obj.numPixels*obj.pixelConversionFactor), ' microns']));
            addlistener(obj, 'numMicrons', 'PostSet', @(src,event)disp([num2str(obj.numMicrons), ' is ', num2str(obj.numMicrons/obj.pixelConversionFactor), ' pixels']));
            obj.nPTBScreens=numel(PTB_WindowPointer);

            if nargin==2
                obj.hInteractiveGUI=interactiveGUIhandle;
            end
            obj.fSep=filesep; %get the file separater according to opperating system

            % Enable alpha blending with proper blend-function.
            AssertOpenGL;

            %define the key code for escape for KbCheck
            KbName('UnifyKeyNames');
            obj.escapeKeyCode = KbName('ESCAPE');
            if nargin==0
                error('PTB window pointer is required to construct VStim object');
            end
            obj.PTB_win=PTB_WindowPointer;
            for i=1:obj.nPTBScreens
                Screen('BlendFunction', obj.PTB_win(i), GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            end
            %get the visual stimulation methods
            tmpDir=which('VStim'); %identify main folder
            [obj.mainDir, name, ext] = fileparts(tmpDir);

            %initialized TTL signalling
            visualStimGUIMainDir=fileparts(which('visualStimGUI'));
            configFile=[visualStimGUIMainDir filesep 'PCspecificFiles' filesep 'VSConfig.txt']; %JSON encoded

            if exist(configFile,'file')
                fid=fopen(configFile);
                configText=fscanf(fid,'%s');
                configData=jsondecode(configText);
                fclose(fid);
                fn = fieldnames(configData);
                for i=1:numel(fn)
                    obj.(fn{i})=configData.(fn{i});
                end
            end
            [~,obj.computerName]=system('hostname');

            obj.initializeTTL;

            obj.whiteIdx=WhiteIndex(obj.PTB_win(1));
            obj.blackIdx=BlackIndex(obj.PTB_win(1));
            if obj.visualFieldBackgroundLuminance<obj.blackIdx || obj.visualFieldBackgroundLuminance>obj.whiteIdx
                disp('Visual field luminance is not within the possible range of values, please change...');
                return;
            end

            %get general information
            for i=1:obj.nPTBScreens
                obj.rect(i,:)=Screen('Rect', obj.PTB_win(i));
                obj.fps(i)=Screen('FrameRate',obj.PTB_win(i));      % frames per second
                obj.ifi(i)=Screen('GetFlipInterval', obj.PTB_win(i)); %inter flip interval
            end

            %calculate optimal stim duration (as an integer number of frames)
            obj=updateActualStimDuration(obj);

            %set background luminance
            obj.initializeBackground;

            obj.sendTTL(1:4,[false false false false]) %leaving this to make sure ttl's are at zero when stim starts
        end

        function estimatedTime=estimateProtocolDuration(obj)
            %estimated time is given is seconds
            obj.simulationMode=true;
            obj=obj.run;
            estimatedTime=obj.nTotTrials*(mean(obj.actualStimDuration)+mean(obj.interTrialDelay))+obj.preSessionDelay+obj.postSessionDelay;
            obj.simulationMode=false;
        end

        function applyBackgound(obj,screens) %apply background and change the synchrony marker state (on/off)
            if nargin==1
                screens=1:obj.nPTBScreens;
            end
            obj.syncMarkerOn=~obj.syncMarkerOn;
            if obj.syncMarkerOn
                for i=screens
                    Screen('DrawTexture',obj.PTB_win(i),obj.masktexOn(i));
                end
            else
                for i=screens
                    Screen('DrawTexture',obj.PTB_win(i),obj.masktexOff(i));
                end
            end
            for i=screens
                Screen('DrawingFinished', obj.PTB_win(i)); % Tell PTB that no further drawing commands will follow before Screen('Flip')
            end
        end

        function initializeBackground(obj,event,metaProp)
            for i=1:numel(obj.PTB_win)
                if obj.visualFieldDiameter==0
                    obj.actualVFieldDiameter(i)=min(obj.rect(i,3)-obj.rect(i,1),obj.rect(i,4)-obj.rect(i,2));
                elseif obj.visualFieldDiameter==-1
                    obj.actualVFieldDiameter(i)=min(obj.rect(i,3)-obj.rect(i,1),obj.rect(i,4)-obj.rect(i,2));
                else
                    obj.actualVFieldDiameter(i)=obj.visualFieldDiameter(i);
                end
                obj.centerX(i)=(obj.rect(i,3)+obj.rect(i,1))/2+obj.horizontalShift;
                obj.centerY(i)=(obj.rect(i,4)+obj.rect(i,2))/2;

                obj.visualFieldRect(i,:)=round([obj.centerX(i)-obj.actualVFieldDiameter(i)/2,obj.centerY(i)-obj.actualVFieldDiameter(i)/2,obj.centerX(i)+obj.actualVFieldDiameter(i)/2,obj.centerY(i)+obj.actualVFieldDiameter(i)/2]);
                [x,y]=meshgrid((-obj.actualVFieldDiameter(i)/2):(obj.actualVFieldDiameter(i)/2-1),(-obj.actualVFieldDiameter(i)/2):(obj.actualVFieldDiameter(i)/2-1));
                %sig = @(x,y) 1 ./ (1 + exp( (sqrt(x.^2 + y.^2 - (obj.actualVFieldDiameter/2-50).^2 )) ));
                sig = @(x,y) 1-1 ./ ( 1 + exp(sqrt(x.^2 + y.^2) - obj.actualVFieldDiameter(i)/2+1).^obj.backgroundMaskSteepness );

                %maskblob=ones(obj.actualVFieldDiameter, obj.actualVFieldDiameter, 2) * obj.backgroudLuminance;
                %maskblob(:,:,2)=sig(x,y)*obj.whiteIdx;

                maskblobOff=ones(obj.rect(i,4)-obj.rect(i,2),obj.rect(i,3)-obj.rect(i,1),2) * obj.whiteIdx;
                if obj.showOnFullScreen==0
                    maskblobOff(:,:,1)=obj.visualFieldBackgroundLuminance; %obj.blackIdx
                    maskblobOff((obj.visualFieldRect(i,2)+1):obj.visualFieldRect(i,4),(obj.visualFieldRect(i,1)+1):obj.visualFieldRect(i,3),2)=sig(x,y)*obj.whiteIdx;
                elseif obj.showOnFullScreen==1
                    maskblobOff=ones(obj.rect(i,4)-obj.rect(i,2),obj.rect(i,3)-obj.rect(i,1),2) * obj.blackIdx;
                    maskblobOff(:,:,1)=obj.blackIdx;
                elseif obj.showOnFullScreen==2
                    maskblobOff(:,:,1)=obj.visualFieldBackgroundLuminance; %obj.blackIdx
                    maskblobOff((obj.visualFieldRect(i,2)+1):obj.visualFieldRect(i,4),(obj.visualFieldRect(i,1)+1):obj.visualFieldRect(i,3),2)=obj.blackIdx;
                end

                if obj.DMDcorrectionIntensity
                    [~,maskblobOff(:,:,2)]=meshgrid(1:size(maskblobOff,2),1:size(maskblobOff,1));
                    maskblobOff(:,:,2)=maskblobOff(:,:,2)/max(max(maskblobOff(:,:,2)))*255;
                end

                maskblobOn=maskblobOff; %make on mask addition
                if obj.displaySyncSignal
                    %calculate the rectangular size as a fraction of the visual field diameter
                    obj.syncSquareSizePix = round(obj.syncSquareScreenFraction*obj.actualVFieldDiameter);
                    maskblobOn((obj.rect(i,4)-obj.syncSquareSizePix):end,1:obj.syncSquareSizePix,1)=obj.syncSquareLuminosity;
                    maskblobOn((obj.rect(i,4)-obj.syncSquareSizePix):end,1:obj.syncSquareSizePix,2)=obj.whiteIdx;
                    maskblobOff((obj.rect(i,4)-obj.syncSquareSizePix):end,1:obj.syncSquareSizePix,2)=obj.whiteIdx;
                end

                % Build a single transparency mask texture:
                obj.masktexOn(i)=Screen('MakeTexture', obj.PTB_win(i), maskblobOn);
                obj.masktexOff(i)=Screen('MakeTexture', obj.PTB_win(i), maskblobOff);

                Screen('FillRect',obj.PTB_win(i),obj.visualFieldBackgroundLuminance);
                obj.syncMarkerOn = false;
                Screen('DrawTexture',obj.PTB_win(i),obj.masktexOff(i));
                Screen('Flip',obj.PTB_win(i));
            end
        end

        function [props]=getProperties(obj)
            props.metaClassData=metaclass(obj);
            props.allPropName={props.metaClassData.PropertyList.Name}';
            props.allPropSetAccess={props.metaClassData.PropertyList.SetAccess}';
            props.allPropHidden={props.metaClassData.PropertyList.Hidden}';
            props.publicPropName=props.allPropName(find(strcmp(props.allPropSetAccess, 'public') & ~cell2mat(props.allPropHidden)));
            for i=1:numel(props.publicPropName)
                if isprop(obj,[props.publicPropName{i} 'Txt']);
                    props.publicPropDescription{i,1}=obj.([props.publicPropName{i} 'Txt']);
                else
                    props.publicPropDescription{i,1}='description missing (add a property to the VStim object with the same name as the property but with Txt in the end)';
                end
                props.publicPropVal{i,1}=obj.(props.publicPropName{i});
            end
            %collect all prop values
            for i=1:numel(props.allPropName)
                props.allPropVal{i,1}=obj.(props.allPropName{i});
            end
        end

        function [VSMethods]=getVSControlMethods(obj)
            VSMethods.methodName=methods(obj);
            VSMethods.methodDescription={};
            pControlMethods=cellfun(@(x) sum(x(1:2)=='CM')==2,VSMethods.methodName);
            VSMethods.methodName=VSMethods.methodName(pControlMethods);
            for i=1:numel(VSMethods.methodName)
                if isprop(obj,[VSMethods.methodName{i} 'Txt']);
                    VSMethods.methodDescription{i,1}=obj.([VSMethods.methodName{i} 'Txt']);
                else
                    VSMethods.publicPropDescription{i,1}='description missing (add a property to the VStim object with the same name as the method but with Txt in the end)';
                end

                VSMethods.methodName{i,1}=VSMethods.methodName{i};
            end
        end

        function initializeTTL(obj)
            %select the digital IO scheme
            try
                switch obj.selectedDigitalIO
                    case 'parallelPort-Win'
                        obj.trigChNames=[[1;2;3;4] [5;6;7;8]];
                        if isunix || ismac
                            fprintf('The chosen synchronization method, parallelPort-Win, will not work on Linux/Mac!!! No triggers will be sent!!!\nSwitching to sync on display only!\n');
                            obj.selectedDigitalIO='onScreen';
                        end
                        if isempty(obj.ioObj)
                            %create IO64 interface object
                            obj.ioObj.ioObj = io64();

                            %install the inpoutx64.dll driver, status = 0 if installation successful
                            obj.ioObj.status = io64(obj.ioObj.ioObj);

                            if (obj.ioObj.status ~= 0)
                                error('inp/outp installation failed!!!!');
                            end
                        else
                            disp('Parallel port object already exists');
                        end
                    case 'parallelPort-Linux'
                        obj.trigChNames=[[2;3;4;5] [6;7;8;9]];
                        if ispc || ismac
                            fprintf('The chosen synchronization method, parallelPort-Linux, will not work on Windows/Mac!!! No triggers will be sent!!!\nSwitching to sync on display only!\n');
                            obj.selectedDigitalIO='onScreen';
                        end
                    case 'onScreen'
                    case 'LabJack-Win'
                        obj.trigChNames=[[1;2;3;4] [5;6;7;8]];
                        chNames=[{'DIO0','DIO4'};{'DIO1','DIO5'};{'DIO2','DIO6'};{'DIO3','DIO7'}];
                        if isunix || ismac
                            fprintf('The chosen synchronization method, LabJack-Win, will not work on Linux/Mac!!! No triggers will be sent!!!\nSwitching to sync on display only!\n');
                            obj.selectedDigitalIO='onScreen';
                        end
                        fprintf('Initializing LabJack Device and checking functionality...\n');
                        % Make the LJM .NET assembly visible in MATLAB
                        ljmAsm = NET.addAssembly('LabJack.LJM');

                        % Creating an object to nested class LabJack.LJM.CONSTANTS
                        t = ljmAsm.AssemblyHandle.GetType('LabJack.LJM+CONSTANTS');
                        LJM_CONSTANTS = System.Activator.CreateInstance(t);
                        try
                            [ljmError, obj.ioObj] = LabJack.LJM.OpenS('ANY', 'ANY', 'ANY', 0);
                            showDeviceInfo(obj.ioObj);
                            % Reading from the digital line in case it was previously an analog input.
                            nCh=numel(chNames);
                            obj.digiNamesNET=NET.createArray('System.String', nCh);
                            for i=1:nCh
                                obj.digiNamesNET(i)=chNames{i};
                            end
                            obj.digiValuesNET = NET.createArray('System.Double', nCh);
                            LabJack.LJM.eReadNames(obj.ioObj, nCh, obj.digiNamesNET, obj.digiValuesNET, 0);
                        catch
                            fprintf('%s\nLackJack device is not functional!!! No triggers will be sent!!!\nSwitching to sync on display only!\n',ljmError);
                            selectedDigitalIO='onScreen';
                        end
                end
            catch
                fprintf('\nImportant!!!\nCould not deliver triggers successfully! Triggers will only be shown on the screen!!!\n')
                obj.selectedDigitalIO='onScreen';
            end

        end %function initializeTTL

        %if future version, remove TTL functionality to a dedicated class
        function sendTTL(obj,TTLNum,TTLValue)
            %select the digital IO scheme
            switch obj.selectedDigitalIO
                case 'parallelPort-Win'
                    obj.currentBinState(obj.trigChNames(TTLNum,:))=[TTLValue;TTLValue]';
                    io64(obj.ioObj.ioObj,obj.parallelPortNum,sum(obj.binaryMultiplicator.*obj.currentBinState));
                case 'parallelPort-Linux'
                    pp(uint8(obj.trigChNames(TTLNum,:)),[TTLValue TTLValue],false,uint8(0),uint64(obj.parallelPortNum)); %session start trigger (also triggers the recording start)
                case 'onScreen'
                    disp(['Simulation mode trigger/value - ' num2str([TTLNum TTLValue])]);
                case 'LabJack-Win'
                    tmpNames=obj.trigChNames(TTLNum,:);
                    tmpValues=[TTLValue;TTLValue]';
                    for i=1:numel(tmpNames),obj.digiValuesNET(tmpNames(i))=tmpValues(i);end
                    LabJack.LJM.eWriteNames(obj.ioObj, numel(obj.trigChNames), obj.digiNamesNET, obj.digiValuesNET, 0);
            end

        end

        function obj=updateActualStimDuration(obj,event,metaProp)
            %calculate optimal stim duration (as an integer number of frames)
            for i=1:obj.nPTBScreens
                obj.actualStimDuration(i)=round(obj.stimDuration/obj.ifi(i))*obj.ifi(i);
            end
        end

        function calcMicrons(obj)
            disp([num2str(obj.numPixels), ' is ', num2str(obj.numPixels*obj.pixelConversionFactor), ' microns']);
            %uses the micron/pixel ratio to convert entered number of
            %pixels to microns
        end

        function obj = calcPixels(obj,event)
            %uses the micron/pixel ratio to convert entered number of
            %pixels to microns
        end


        function outStats=getLastStimStatistics(obj,hFigure)
        end

        function outPar=run(obj)
        end

        function cleanUp(obj)
        end

        function delete(obj)
            if strcmp(obj.selectedDigitalIO,'LabJack-Win')
                LabJack.LJM.Close(obj.ioObj);
            end
        end
        
    end

end %EOF