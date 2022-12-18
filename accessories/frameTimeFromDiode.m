function [frameShifts,upCross,downCross,diffStats,transitionNotFound,T]=frameTimeFromDiode(dataRecordingObj,varargin)
% [frameShifts,upCross,downCross,diffStats,transitionNotFound]=frameTimeFromDiode(dataRecordingObj);
% Function purpose : calculate triggers from recording
%
% Function recives :    dataRecordingObj - a data recording object for extracting analog and digital data
%                           varargin ('property name','property value')
%
% Function give back :  frameShifts - times of frame shifts
%                       upCross - diode upward threshold crossing
%                       downCross - diode downward threshold crossing
%                       T - digital data time stamps
%                       transitionNotFound - if matching time stamp was not found and original trigger taken instead
%
% Last updated : 15/07/15

%% default variables
tStart=0;
tEnd=dataRecordingObj.recordingDuration_ms;
Fs=dataRecordingObj.samplingFrequency(1);

chunckOverlap=1; %ms
maxChunck=1000*60*10; %ms
trialStartEndDigiTriggerNumbers=[3 4];
analogChNum=[]; %this used to be 1, now Kwik's getAnalog finds on its own
refCh=[]; %a reference channel to substract from the signal channel
transition=[];
delay2Shift=2.5/60*1000; %ms
maxFrameDeviation=1/60*1000; %ms
noisyAnalog = false; % recalculates thresholds for every window - usese a combination of digital triggers and analog data to extract locations in noisy cases
useDigitalTriggersAsInitialTimeStamps = true;
extractDiodeElectrodeChannel=false;
thresholdSelection='none';%'upper','lower','none','manual' - biases the threshold towards one of the clusters identified in test data
frameRate=1/60;
inputThreshold=[];

plotDiodeTransitions=0;
T=[]; %digital triggers in the recording

%LPF parameters
F=filterData(Fs);
F.lowPassStopCutoff=1/100;
F.lowPassPassCutoff=1/120;
F.highPassStopCutoff=0.000625;
F.highPassPassCutoff=0.00065625;
F=F.designLowPass;

%% Output list of default variables
%print out default arguments and values if no inputs are given
if nargin==0
    defaultArguments=who;
    for i=1:numel(defaultArguments)
        eval(['defaultArgumentValue=' defaultArguments{i} ';']);
        if numel(defaultArgumentValue)==1
            disp([defaultArguments{i} ' = ' num2str(defaultArgumentValue)]);
        else
            fprintf([defaultArguments{i} ' = ']);
            disp(defaultArgumentValue);
        end
    end
    return;
end

%% Collects all input variables
for i=1:2:length(varargin)
    eval([varargin{i} '=' 'varargin{i+1};'])
end

%% Main function
frameSamples=round(1/frameRate*Fs);

%extract digital triggers times if they were not provided during input
hWB=waitbar(0,'Getting digital triggers...');
if isempty(T) && useDigitalTriggersAsInitialTimeStamps
    dataRecordingObj.includeOnlyDigitalDataInTriggers=1;
    T=dataRecordingObj.getTrigger; %extract digital triggers throughout the recording
    
    %check if triggers exist and are not empty
    if isempty(T{trialStartEndDigiTriggerNumbers(1)}) || isempty(T{trialStartEndDigiTriggerNumbers(2)})
        disp('No start trigger detected in recording!!! Aborting calculation!');
        frameShifts=[];upCross=[];downCross=[];
        return;
    end
end

if ~isempty(inputThreshold)
    disp('Since a specific transition was chosen, the transition detection is swithched to fixed mode');
    thresholdSelection='fixed';
end

%determine the chunck size
if ~noisyAnalog
    if maxChunck>tEnd
        chunkStart=tStart;
        chunkEnd=tEnd;
    else
        chunkStart=0:maxChunck:tEnd;
        chunkEnd=[chunkStart(2:end)+chunckOverlap tEnd];
    end
else
    if isempty(T)   
        error('Using noisyAnalog=true requires triggers');
    end
    if T{trialStartEndDigiTriggerNumbers(1)}+maxChunck>tEnd
        chunkStart=T{trialStartEndDigiTriggerNumbers(1)};
        chunkEnd=tEnd;
    else
        chunkStart=T{trialStartEndDigiTriggerNumbers(1)}:maxChunck:tEnd;
        chunkEnd=[chunkStart(2:end)+chunckOverlap tEnd];
    end
end
nChunks=numel(chunkStart);

if numel(dataRecordingObj.analogChannelNumbers)==0
    extractDiodeElectrodeChannel=true;
end

if ~noisyAnalog %if noisy, estimate for each chunk
    %estimate transition points
    if isempty(transition)
        hWB=waitbar(0,hWB,'Classifying transition on sample data...');
        %take the analog data during the first 10 trials (if available) with length of double the trial size
        if useDigitalTriggersAsInitialTimeStamps
            avgTrialDuration=round(mean(T{trialStartEndDigiTriggerNumbers(2)}-T{trialStartEndDigiTriggerNumbers(1)})*2);
            if extractDiodeElectrodeChannel %in some cases diode is recorded on an electrode channel rather than an analog channel
                [Atmp]=dataRecordingObj.getData([analogChNum refCh],T{trialStartEndDigiTriggerNumbers(1)}(randi([2, max(11,numel(T{trialStartEndDigiTriggerNumbers(1)}))-1],[1 min(10,numel(T{trialStartEndDigiTriggerNumbers(1)}))-2]))-100,avgTrialDuration);
            else
                [Atmp]=dataRecordingObj.getAnalogData([analogChNum refCh],T{trialStartEndDigiTriggerNumbers(1)}(randi([2, max(11,numel(T{trialStartEndDigiTriggerNumbers(1)}))-1],[1 min(10,numel(T{trialStartEndDigiTriggerNumbers(1)}))-2]))-100,avgTrialDuration);
            end
        else
            avgTrialDuration=100000;
            if extractDiodeElectrodeChannel %in some cases diode is recorded on an electrode channel rather than an analog channel
                [Atmp]=dataRecordingObj.getData([analogChNum refCh],round(dataRecordingObj.recordingDuration_ms/2),avgTrialDuration);
                
            else
                [Atmp]=dataRecordingObj.getAnalogData([analogChNum refCh],round(dataRecordingObj.recordingDuration_ms/2),avgTrialDuration);
            end
        end
        if ~isempty(refCh)
            Atmp=Atmp(1,:,:)-Atmp(2,:,:);
        end
        Atmp=permute(Atmp,[3 1 2]);Atmp=Atmp(:);
        medAtmp = fastmedfilt1d(Atmp,round(frameSamples*0.8));
        eva = evalclusters(medAtmp,'kmeans','DaviesBouldin','KList',[2:4]);
        [idx,cent] = kmeans(medAtmp,eva.OptimalK,'Replicates',5);
        [cent,sortind]=sort(cent);
        switch thresholdSelection
            case 'none'
                transitions=(cent(1:end-1)+cent(2:end))/2;
            case 'upper'
                s=std(Atmp(idx==sortind(1)));
                transitions=cent(2)-s/2;
            case 'lower'
                s=std(Atmp(idx==sortind(1)));
                transitions=cent(1)+s/2;
            case 'manual'
                f=figure;plot(medAtmp);hold on;line([1 numel(medAtmp)],[transitions(1) transitions(1)]);
                pt=ginput(1);
                transitions=pt(2);
                close(f);
            case 'fixed'
                transitions=inputThreshold;
        end
    end
    %show the threshold separation, this will close at the end of the detection.
    f=figure;plot(medAtmp);hold on;line([1 numel(medAtmp)],[transitions(1) transitions(1)]);
end

%main loop
hWB=waitbar(0,hWB,'Extracting analog diode data from recording...');
upCross=cell(1,nChunks);
downCross=cell(1,nChunks);
for i=1:nChunks
    if extractDiodeElectrodeChannel %in some cases diode is recorded on an electrode channel rather than an analog channel
        [A,t_ms]=dataRecordingObj.getData([analogChNum refCh],chunkStart(i),chunkEnd(i)-chunkStart(i));
    else
        [A,t_ms]=dataRecordingObj.getAnalogData([analogChNum refCh],chunkStart(i),chunkEnd(i)-chunkStart(i));
    end
    if ~isempty(refCh)
        A=A(1,:,:)-A(2,:,:);
    end
    if ~noisyAnalog
        A=squeeze(A);
        medA = fastmedfilt1d(A,round(frameSamples*0.8));
    else
        Ftmp=F.getFilteredData(A);
        Aflat=A-Ftmp; %flatten oscilations and drift
        medA = fastmedfilt1d(Aflat(:),round(frameSamples*2));
        eva = evalclusters(medA,'kmeans','DaviesBouldin','KList',[2:4]);
        [idx,cent] = kmeans(medA,eva.OptimalK,'Replicates',2);
        cent=sort(cent);
        transitions=(cent(1:end-1)+cent(2:end))/2;
    end
%     f=figure;plot(medA);hold on;line([1 numel(medA)],[transitions(1) transitions(1)]);
    upCross{i}=chunkStart(i)+find(medA(1:end-1)<transitions(1) & medA(2:end)>=transitions(1))/Fs*1000;
    downCross{i}=chunkStart(i)+find(medA(1:end-1)>transitions(1) & medA(2:end)<=transitions(1))/Fs*1000;
    %plot(medA);hold on;plot(upCross{i}*Fs/1000,medA(round(upCross{i}*Fs/1000)),'or');plot(downCross{i}*Fs/1000,medA(round(downCross{i}*Fs/1000)),'sg')
    waitbar(i / nChunks);
end
close(hWB);
upCross=cell2mat(upCross');
downCross=cell2mat(downCross');
if ~noisyAnalog
    try %to prevent error when closing the figure window manually before it is closed during run
        close(f);
    catch
    end
end

udCross{1}=upCross;udCross{2}=downCross;
frameShifts=udCross;

if useDigitalTriggersAsInitialTimeStamps
crossFinal=zeros(2,numel(T{trialStartEndDigiTriggerNumbers(1)}));
transitionNotFound=zeros(2,numel(T{trialStartEndDigiTriggerNumbers(1)}));
for i=1:numel(trialStartEndDigiTriggerNumbers)
    tmpTig=T{trialStartEndDigiTriggerNumbers(i)}+delay2Shift;
    checkSingleTriggers=1;
    if numel(tmpTig)==numel(udCross{i})
        if all(tmpTig-udCross{i}<maxFrameDeviation)
            fprintf('Same number of transitions in session %d diode and triggers, taking diode signal as time stamps\n',trialStartEndDigiTriggerNumbers(i));
            crossFinal(i,:)=udCross{i};
            fprintf('mean difference in lag was %f +- %f',mean(tmpTig'-udCross{i}),std(tmpTig'-udCross{i}));
            checkSingleTriggers=0;
        end
    end
    if checkSingleTriggers
        fprintf('Number of diode transitions in session %d, different from triggers, checking single events\n',trialStartEndDigiTriggerNumbers(i));
        for j=1:numel(tmpTig)
            tmpT1=udCross{1}(udCross{1}>=(tmpTig(j)-maxFrameDeviation) & udCross{1}<=(tmpTig(j)+maxFrameDeviation));
            tmpT2=udCross{2}(udCross{2}>=(tmpTig(j)-maxFrameDeviation) & udCross{2}<=(tmpTig(j)+maxFrameDeviation));
            if isempty(tmpT1) & isempty(tmpT2)
                crossFinal(i,j)=tmpTig(j);
                transitionNotFound(i,j)=1;
            elseif ~isempty(tmpT1) & ~isempty(tmpT2)
                [d1,pmin1]=min(abs(tmpT1-tmpTig(j)));
                [d2,pmin2]=min(abs(tmpT2-tmpTig(j)));
                if abs(d1)>=abs(d2)
                    crossFinal(i,j)=tmpT2(pmin2);
                else
                    crossFinal(i,j)=tmpT1(pmin1);
                end
            elseif isempty(tmpT1)
                [d2,pmin2]=min(abs(tmpT2-tmpTig(j)));
                crossFinal(i,j)=tmpT2(pmin2);
            else
                [d1,pmin1]=min(abs(tmpT1-tmpTig(j)));
                crossFinal(i,j)=tmpT1(pmin1);
            end
        end
    end
    diffStats{i}=crossFinal(i,:)-tmpTig;
end
upCross=crossFinal(1,:);
downCross=crossFinal(2,:);
end

if plotDiodeTransitions
    figure;
    mx=max(A)+100;
    t_ms=(1:numel(A))/Fs*1000;
    for i=1:numel(transitions)
        line([t_ms(1) t_ms(end)],[transitions(i) transitions(i)],'color','k');
    end
    hold on;
    
    hp1=plot(t_ms,A);
    hp2=plot(t_ms,medA,'g');
    
    upCrossTmp=find(medA(1:end-1)<transitions(1) & medA(2:end)>=transitions(1));
    downCrossTmp=find(medA(1:end-1)>transitions(1) & medA(2:end)<=transitions(1));
    hp3=plot(t_ms(upCrossTmp),medA(upCrossTmp),'^r');
    hp4=plot(t_ms(downCrossTmp),medA(downCrossTmp),'vr');
    mMedA=mean(medA);
    
    p=find(T{trialStartEndDigiTriggerNumbers(1)}>=chunkStart(end) & T{trialStartEndDigiTriggerNumbers(1)}<chunkEnd(end));
    hp5=plot(T{trialStartEndDigiTriggerNumbers(1)}(p)-chunkStart(end),mMedA*ones(1,numel(p)),'ok');
    
    p=find(upCross>=chunkStart(end) & upCross<chunkEnd(end));
    hp6=plot(upCross(p)-chunkStart(end),mMedA*ones(1,numel(p)),'*m');
    
    p=find(downCross>=chunkStart(end) & downCross<chunkEnd(end));
    hp7=plot(downCross(p)-chunkStart(end),mMedA*ones(1,numel(p)),'sc');
    
    l=legend([hp1 hp2 hp3 hp4 hp5 hp6 hp7],{'Diode','Diode-Filt','upCrossDiode','downCrossDiode','digitalTrig','finalUp','finalDown'});
end

