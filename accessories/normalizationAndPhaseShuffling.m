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
% SHUFFLECOLORPHASES Randomizes the Fourier phases of each channel
% of a color image independently (method='random', mode='independent').
%
%   IS = shuffleColorPhases(I)
%
%   Input:
%       I  - RGB color image (uint8, uint16, single, or double)
%   Output:
%       IS - Phase-shuffled image (double, in [0,1])
%
%   Each channel is transformed independently:
%   1. Compute 2D FFT.
%   2. Keep amplitude spectrum.
%   3. Replace phase spectrum with uniform random [-pi, pi].
%   4. Enforce Hermitian symmetry so result is real-valued.
%   5. Inverse FFT to reconstruct.

    % Convert to double [0,1]
    I = im2double(I);
    [H, W, C] = size(I);
    if C ~= 3
        error('Input must be an RGB image (HxWx3).');
    end
    
    IS = zeros(size(I));
    
    for c = 1:C
        F = fft2(I(:,:,c));
        A = abs(F);                         % amplitude spectrum
        P = -pi + 2*pi*rand(H, W);          % random phases
        
        % Construct new spectrum
        S = A .* exp(1i*P);
        
        % Enforce Hermitian symmetry so ifft2 result is real
        S = enforceHermitian(S);
        
        % Reconstruct channel
        IS(:,:,c) = ifft2(S, 'symmetric');
    end
    
    % Normalize result to [0,1] for display
    IS = IS - min(IS(:));
    if max(IS(:)) > 0
        IS = IS ./ max(IS(:));
    end
end

% --- Helper: enforce Hermitian symmetry in 2D spectrum ---
function Sout = enforceHermitian(S)
    [H,W] = size(S);
    Sflip = conj(flipud(fliplr(S)));
    Sout  = 0.5*(S + Sflip);  % symmetrize
    % DC real
    Sout(1,1) = real(Sout(1,1));
    % Handle Nyquist frequencies if even dims
    if mod(H,2) == 0
        Sout(H/2+1,:) = real(Sout(H/2+1,:));
    end
    if mod(W,2) == 0
        Sout(:,W/2+1) = real(Sout(:,W/2+1));
    end
end