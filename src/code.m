function fourier_shape_descriptor()
    % Create GUI
    fig = uifigure('Name', 'Fourier Shape Descriptor', 'Position', [100 100 600 400]);
    
    % Load Image Button
    btnLoad = uibutton(fig, 'Text', 'Load Image', 'Position', [20 350 100 30], 'ButtonPushedFcn', @(btn,event) loadImage(fig));
    
    % Process Button
    btnProcess = uibutton(fig, 'Text', 'Process Image', 'Position', [140 350 100 30], 'ButtonPushedFcn', @(btn,event) processImage(fig));
    
    % Percentage Slider
    lbl = uilabel(fig, 'Text', 'Retain %:', 'Position', [260 355 60 20]);
    slider = uislider(fig, 'Position', [320 360 150 3], 'Limits', [1 100]);
    
    % Save Button
    btnSave = uibutton(fig, 'Text', 'Save Descriptor', 'Position', [480 350 100 30], 'ButtonPushedFcn', @(btn,event) saveDescriptor());
    
    % Axes for Image Display
    ax = uiaxes(fig, 'Position', [50 50 500 280]);
    setappdata(fig, 'AxesHandle', ax);
    setappdata(fig, 'SliderHandle', slider);
end

function loadImage(fig)
    [file, path] = uigetfile({'*.jpg;*.png;*.bmp', 'Image Files'});
    if file
        img = imread(fullfile(path, file));
        ax = getappdata(fig, 'AxesHandle');
        imshow(img, 'Parent', ax);
        setappdata(fig, 'ImageData', img);
    end
end

function processImage(fig)
    img = getappdata(fig, 'ImageData');
    if isempty(img)
        uialert(fig, 'Load an image first!', 'Error');
        return;
    end
    
    % Convert to grayscale and detect edges
    grayImg = rgb2gray(img);
    edges = edge(grayImg, 'Canny');
    
    % Extract boundary points
    [y, x] = find(edges);
    complexPoints = x + 1i * y;
    
    % Compute Fourier Descriptor
    FD = fft(complexPoints);
    
    % Retain Percentage of Coefficients
    slider = getappdata(fig, 'SliderHandle');
    retainPercent = round(slider.Value);
    numCoeffs = round(length(FD) * retainPercent / 100);
    FD(numCoeffs+1:end) = 0;
    
    % Reconstruct boundary
    reconPoints = ifft(FD);
    
    % Display results
    ax = getappdata(fig, 'AxesHandle');
    cla(ax);
    imshow(grayImg, 'Parent', ax); hold(ax, 'on');
    plot(ax, real(reconPoints), imag(reconPoints), 'r', 'LineWidth', 2);
    hold(ax, 'off');
    
    setappdata(fig, 'FourierDescriptor', FD);
end

function saveDescriptor()
    FD = getappdata(gcf, 'FourierDescriptor');
    if isempty(FD)
        uialert(gcf, 'No descriptor to save!', 'Error');
        return;
    end
    
    [file, path] = uiputfile('descriptor.mat', 'Save Fourier Descriptor');
    if file
        save(fullfile(path, file), 'FD');
    end
end

fourier_shape_descriptor();
