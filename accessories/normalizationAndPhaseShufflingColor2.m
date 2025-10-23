function [nI,IS]=normalizationAndPhaseShuffling2(I,targetMeanIntensity)
maxI=255;
scalingType='lin';
nI=I;meanI = 0;
while meanI>targetMeanIntensity+1 || meanI<targetMeanIntensity-1
    meanI = mean(nI(:));
    dev=(targetMeanIntensity-meanI);
    fprintf('%f,',meanI);
    switch scalingType
        case 'addition'
            nI=round(nI-meanI+targetMeanIntensity);
        case 'scaling'
            nI=round(nI/meanI*targetMeanIntensity);
        case 'no'
            nI=I;
        case 'lin'
            if dev>0
                nI = imadjust(nI, [],[],0.98);  % gamma < 1 brightens
            else
                nI = imadjust(nI, [],[],1.02);  % gamma < 1 brightens
            end
    end
end
fprintf('Done!\n');


IS = shuffleColorPhases(nI);

% Show results
f=figure('Position',[100 100 900 300]);
subplot(1,3,1); imshow(I);title('Original');
subplot(1,3,2); imshow(nI);title('normalized');
subplot(1,3,3); imshow(IS);title('normalized Phase-shuffled');
end

function IS = shuffleColorPhases(I)
 I = im2double(I);  [H,W,~] = size(I);
    if size(I,3) ~= 3, error('RGB image required'); end

    % Make one random phase map
    P = -pi + 2*pi*rand(H,W);

    IS = zeros(size(I));
    for c = 1:3
        F  = fft2(I(:,:,c));
        A  = abs(F);
        S  = A .* exp(1i*P);
        S  = enforceHermitian(S);
        IS(:,:,c) = ifft2(S,'symmetric');
    end

    % Normalize to [0,1] for display
    IS = IS - min(IS(:));
    if max(IS(:))>0, IS = IS ./ max(IS(:)); end
end

function Sout = enforceHermitian(S)
    Sflip = conj(flipud(fliplr(S)));
    Sout  = 0.5*(S + Sflip);
    Sout(1,1) = real(Sout(1,1));
    [H,W] = size(S);
    if mod(H,2)==0, Sout(H/2+1,:) = real(Sout(H/2+1,:)); end
    if mod(W,2)==0, Sout(:,W/2+1) = real(Sout(:,W/2+1)); end
end