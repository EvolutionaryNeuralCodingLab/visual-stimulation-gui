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

samplingFreq=20000; %Hz
chunckOverlap=1; %ms
maxChunck=1000*60*20; %ms
trialStartEndDigiTriggerNumbers=[3 4];
analogChNum=[]; %this used to be 1, now Kwik's getAnalog finds on its own
transition=[];
delay2Shift=2.5/60*1000; %ms
maxFrameDeviation=1/60*1000; %ms

plotDiodeTransitions=0;
T=[]; %digital triggers in the recording

%LPF parameters
F=filterData(samplingFreq);
F.lowPassStopCutoff=1/100;
F.lowPassPassCutoff=1/120;
F.highPassStopCutoff=0.000625;
F.highPassPassCutoff=0.00065625;


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
Fs=dataRecordingObj.samplingFrequency(1);
frameSamples=round(1/60*Fs);
F=F.designLowPass;

%extract digital triggers times if they were not provided during input
hWB=waitbar(0,'Getting digital triggers...');
if isempty(T)
    dataRecordingObj.includeOnlyDigitalDataInTriggers=1;
    T=dataRecordingObj.getTrigger; %extract digital triggers throughout the recording
end

if isempty(T{trialStartEndDigiTriggerNumbers(1)}) || isempty(T{trialStartEndDigiTriggerNumbers(2)})
    disp('No start trigger detected in recording!!! Aborting calculation!');
    frameShifts=[];upCross=[];downCross=[];
    return;
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
    if T{trialStartEndDigiTriggerNumbers(1)}+maxChunck>tEnd
        chunkStart=T{trialStartEndDigiTriggerNumbers(1)};
        chunkEnd=tEnd;
    else
        chunkStart=T{trialStartEndDigiTriggerNumbers(1)}:maxChunck:tEnd;
        chunkEnd=[chunkStart(2:end)+chunckOverlap tEnd];
    end
end

nChunks=numel(chunkStart);

if ~noisyAnalog %if noisy, estimate for each chunk
    %estimate transition points
    if isempty(transition)
        hWB=waitbar(0,hWB,'Classifying transition on sample data...');
        %take the analog data during the first 10 trials (if available) with length of double the trial size 
        avgTrialDuration=round(mean(T{trialStartEndDigiTriggerNumbers(2)}-T{trialStartEndDigiTriggerNumbers(1)})*2);
        [Atmp]=dataRecordingObj.getAnalogData(analogChNum,T{trialStartEndDigiTriggerNumbers(1)}(randi([2, max(11,numel(T{trialStartEndDigiTriggerNumbers(1)}))-1],[1 min(10,numel(T{trialStartEndDigiTriggerNumbers(1)}))-2]))-100,avgTrialDuration);
        Atmp=permute(Atmp,[3 1 2]);Atmp=Atmp(:);
        medAtmp = fastmedfilt1d(Atmp,round(frameSamples*0.8));
        eva = evalclusters(medAtmp,'kmeans','DaviesBouldin','KList',[2:4]);
        [idx,cent] = kmeans(medAtmp,eva.OptimalK,'Replicates',5);
        cent=sort(cent);
        transitions=(cent(1:end-1)+cent(2:end))/2;
    end
    %show the threshold separation, this will close at the end of the detection.
    f=figure;plot(medAtmp);hold on;line([1 numel(medAtmp)],[transitions(1) transitions(1)]);
end

%main loop
hWB=waitbar(0,hWB,'Extracting analog diode data from recording...');
upCross=cell(1,nChunks);
downCross=cell(1,nChunks);
for i=1:nChunks
    [A,t_ms]=dataRecordingObj.getAnalogData(analogChNum,chunkStart(i),chunkEnd(i)-chunkStart(i));
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
