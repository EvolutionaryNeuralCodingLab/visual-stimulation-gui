function [nI,IS]=normalizationAndPhaseShuffling(I,targetMeanIntensity)
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
% Randomize spatial phase while preserving color (hue/chroma).
% Strategy: convert RGB->Lab, shuffle phases of L only, then Lab->RGB.

    I = im2double(I);
    if size(I,3) ~= 3, error('RGB image required'); end

    % RGB -> Lab (L in [0,100], a/b around [-128,128])
    Ilab = rgb2lab(I);
    L  = Ilab(:,:,1);    % luminance
    aC = Ilab(:,:,2);    % chroma a
    bC = Ilab(:,:,3);    % chroma b

    % Work with L normalized to [0,1] for convenience
    Ln = L / 100;

    % Randomize phase of L (method='random'), enforce Hermitian symmetry
    F  = fft2(Ln);
    A  = abs(F);
    P  = -pi + 2*pi*rand(size(Ln));
    S  = A .* exp(1i*P);
    S  = enforceHermitian(S);

    Ln_shuf = ifft2(S,'symmetric');

    % Rescale back to original L range and clip safely
    Ln_shuf = Ln_shuf - min(Ln_shuf(:));
    if max(Ln_shuf(:)) > 0
        Ln_shuf = Ln_shuf ./ max(Ln_shuf(:));
    end
    L_shuf = 100 * Ln_shuf;

    % Reassemble Lab and convert back to RGB
    Ilab_out       = Ilab;
    Ilab_out(:,:,1)= L_shuf;
    IS = lab2rgb(Ilab_out);               % double in [0,1]
    IS = min(max(IS,0),1);                % guard against tiny numeric drift
end

function Sout = enforceHermitian(S)
    Sflip = conj(flipud(fliplr(S)));
    Sout  = 0.5*(S + Sflip);
    Sout(1,1) = real(Sout(1,1));
    [H,W] = size(S);
    if mod(H,2)==0, Sout(H/2+1,:) = real(Sout(H/2+1,:)); end
    if mod(W,2)==0, Sout(:,W/2+1) = real(Sout(:,W/2+1)); end
end