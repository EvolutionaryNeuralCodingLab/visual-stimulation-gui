% MATLAB Code for Generating a Simulation with Spiral Waves

% Parameters for the grid and wave
gridSize = 200;      % Size of the grid
[X, Y] = meshgrid(linspace(-pi, pi, gridSize), linspace(-pi, pi, gridSize));

% Parameters for the spiral wave
timeSteps = 100;     % Number of time steps for the simulation
omega = 2*pi/20;     % Angular frequency of the wave

% Preallocate the video writer
v = VideoWriter('spiralWaves.avi');
open(v);

% Generate the spiral wave pattern over time
for t = 1:timeSteps
    Z = exp(1i*(X + Y + omega*t));  % Complex representation of the wave
    wavePattern = real(Z);         % Extract the real part to get the wave pattern
    
    % Plotting
    imagesc(wavePattern);          % Display the wave pattern
    colormap('jet');               % Color map used to visualize the wave
    colorbar;
    axis square off;               % Square axis and turn off the axis labels
    
    % Capture the frame
    frame = getframe(gcf);
    writeVideo(v, frame);
end

% Close the video writer
close(v);