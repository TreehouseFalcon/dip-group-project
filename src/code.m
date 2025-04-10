function fourier_shape_descriptor()
    % Create GUI
    fig = uifigure('Name', 'Fourier Shape Descriptor', 'Position', [100 100 600 400]);
    
    % Load Image Button
    uibutton(fig, 'Text', 'Load Image', 'Position', [20 350 100 30], 'ButtonPushedFcn', @(btn,event) loadImage(fig));
    
    % Process Button
    uibutton(fig, 'Text', 'Process Image', 'Position', [140 350 100 30], 'ButtonPushedFcn', @(btn,event) processImage(fig));
    
    % Percentage Slider
    uilabel(fig, 'Text', 'Retain %:', 'Position', [260 355 60 20]);
    percentInput = uieditfield(fig, 'numeric', 'Position', [320 355 30 22], ...
    'Value', 30, ... % Default value
    'Limits', [1 100], ... 
    'RoundFractionalValues', 'on');
    percentInput.ValueChangedFcn = @(src,event) processImage(fig);
    
    % Save Button
    uibutton(fig, 'Text', 'Save Descriptor', 'Position', [480 350 100 30], 'ButtonPushedFcn', @(btn,event) saveDescriptor(fig));
    
    % Axes for Image Display
    ax = uiaxes(fig, 'Position', [50 50 500 280]);
    setappdata(fig, 'AxesHandle', ax);
    setappdata(fig, 'Percentage', percentInput);
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


function sortedPoints = sortPoints(complexPoints)
    % Configuration parameters. Should probably be fine left as is.
    distanceThreshold = 2;
    angleThreshold = pi;
    closeLoops = false;

    toBeSorted = complexPoints;
    sortedPoints = {};

    
    % While points are left to be sorted, create paths
    while size(toBeSorted) ~= 0
        currentPath = {};

        % While new pivot is close to previous point, create segments
        currentSegment = [toBeSorted(1)];
        while any(abs(toBeSorted(1) - currentSegment(end)) < distanceThreshold)
            
            % If theres only one point left, add it to path and break
            if size(toBeSorted) == 1
                currentSegment = [toBeSorted(1)];
                toBeSorted(1) = [];
                currentPath = [currentPath, currentSegment];
                break
            end

            % Re-sort array based on distance to pivot
            [~,sortedIndices] = sort(abs(toBeSorted - toBeSorted(1)));
            toBeSorted = toBeSorted(sortedIndices);

            % Initialize segment, and segment step parameters
            currentSegment = [toBeSorted(1)];
            consecutiveDistance = abs(toBeSorted(2) - toBeSorted(1));
            heading = angle(toBeSorted(2) - toBeSorted(1));
            angleDiff = 0;
            toBeSorted(1) = [];

            % While next canidate point is close enough, add point to segment
            while consecutiveDistance < distanceThreshold & angleDiff < angleThreshold & size(toBeSorted) > 1
                currentSegment = [currentSegment, toBeSorted(1)];
                consecutiveDistance = abs(toBeSorted(2) - toBeSorted(1));
                angleDiff = abs(heading - angle(toBeSorted(2) - toBeSorted(1)));
                angleDiff = min(angleDiff, 2*pi - angleDiff);
                heading = angle(toBeSorted(2) - toBeSorted(1));
                toBeSorted(1) = [];
            end

            currentPath = [currentPath, currentSegment];
        end

        % Check if end of path is close to any other segments or paths to connect
        previousSegments = cat(2,currentPath{1:end-2});
        previousPaths = cat(2,currentPath{1:end-2});
        lastPointInPath = currentSegment(end);

        if closeLoops & any(abs(previousSegments - lastPointInPath) < distanceThreshold)
            index = find(abs(previousSegments - lastPointInPath) < distanceThreshold);
            index = index(1);
            currentPath = [currentPath, previousSegments(index)];
        elseif closeLoops & any(abs(previousPaths - lastPointInPath) < distanceThreshold)
            index = find(abs(previousPaths - lastPointInPath) < distanceThreshold);
            index = index(1);
            currentPath = [currentPath, previousPaths(index)];
        end

        % If there is one point left, discard it, since it is not enough to
        % create a path
        if size(toBeSorted) == 1
            toBeSorted(1) = [];
        end

        currentPath = cat(2,currentPath{:});
        sortedPoints = [sortedPoints, currentPath];
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

    
    % Set edges to zero
    edges(1:2,:) = 0;
    edges(end-1:end,:) = 0;
    edges(:,1:2) = 0;
    edges(:,end-1:end) = 0;

    % Close gaps as much as possible
    edges = imclose(edges, strel("disk", 15));
    edges = imfill(edges, "holes");
    edges = edge(edges, 'Canny');

    % Extract boundary points
    [y, x] = find(edges);
    complexPoints = x + 1i * y;

    % Sort edge pixels by finding center of mass, and sorting on angle from
    % center of mass
    complexPoints = sortPoints(complexPoints);

    % Compute Fourier Descriptor
    for i=1:length(complexPoints)
        FD{i} = fft(complexPoints{i});
    end

    % Retain Percentage of Coefficients
    pInput = getappdata(fig, 'Percentage');
    retainPercent = pInput.Value;

    for i=1:length(FD)
        numCoeffs = round(length(FD{i})* (retainPercent / 100));
        FD{i} = fftshift(FD{i});
        FD{i}(1:ceil((length(FD{i})-numCoeffs)/2)) = 0;
        FD{i}(length(FD{i})-floor((length(FD{i})-numCoeffs)/2):end) = 0;
        FD{i} = ifftshift(FD{i});
    end

        
    % Reconstruct boundary
    for i=1:length(FD)
        reconPoints{i} = ifft(FD{i});
    end

    % Display results
    ax = getappdata(fig, 'AxesHandle');
    cla(ax);
    imshow(grayImg, 'Parent', ax); hold(ax, 'on');
    for i=1:length(reconPoints)
        plot(ax, real(reconPoints{i}), imag(reconPoints{i}), 'r', 'LineWidth', 2);
    end
    hold(ax, 'off');    
    setappdata(fig, 'FourierDescriptor', FD);
end

function saveDescriptor(fig)
    FD = getappdata(fig, 'FourierDescriptor');
    if isempty(FD)
        uialert(fig, 'No descriptor to save!', 'Error');
        return;
    end

    exportgraphics(fig, "../descriptor.jpg");

    selectedSaveRawDataOption = uiconfirm(fig, ...
        "Save raw descriptor data?", ...
        "Export Raw Data", ...
        "Options",["Save", "Don't Save"] ...
    );
    if selectedSaveRawDataOption ~= "Save"
        return;
    end
    
    [file, path] = uiputfile('../descriptor.mat', 'Save Fourier Descriptor');
    if file
        save(fullfile(path, file), 'FD');
    end
end

fourier_shape_descriptor();
