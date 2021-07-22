% UI PROMPTS
% single or batch
answer = questdlg('Single or batch mode?', ...
	'Select mode', ...
	'Single','Batch', 'Cancel', 'Single');
% Handle response
switch answer
    case 'Single'
        disp('Proceeding in single mode')
        [input_file, input_dir] = uigetfile('*.czi');
        files = dir(fullfile(input_dir, input_file));
    case 'Batch'
        disp('Proceeding in batch mode')
        input_dir = uigetdir;
        files = dir(fullfile(input_dir, '*.czi'));
    case 'Cancel'
        return
end

output_dir = uigetdir(input_dir);


for f = 1:numel(files)
    disp(['Processing file ' num2str(f) ' of ' num2str(numel(files))])

    file = fullfile(input_dir, files(f).name);
    [filepath,name,ext] = fileparts(file);

    % Create a reader but do not initialize it
    reader = bfGetReader();

    % Create the options and pass it to the reader
    options = javaObject('loci.formats.in.DynamicMetadataOptions');
    options.setBoolean(java.lang.String('zeissczi.autostitch'), java.lang.Boolean('FALSE'));
    reader.setMetadataOptions(options);

    % Initialize the reader
    reader.setId(file);
    seriesCount = reader.getSeriesCount();
    sizeX = reader.getSizeX();
    sizeY = reader.getSizeY();
    sizeC = reader.getSizeC();
    
    output_ffp = zeros(sizeY, sizeX, sizeC);

    for ch = 1:sizeC
        stack = zeros(sizeY, sizeX, seriesCount);
        for s = 1:seriesCount
            reader.setSeries(s - 1)
            iPlane = reader.getIndex(0, ch - 1, 0) + 1;
            plane = bfGetPlane(reader, iPlane);
            stack( :, :, s) = plane;
        end
        ffp = BaSiC(stack);
        output_ffp(:, :, ch) = ffp;
        ffp_output_file = fullfile(output_dir, strcat(name,'-c', int2str(ch), '_FFP','.tif'));

        t = Tiff(ffp_output_file, 'w');
        tagstruct.ImageLength = size(ffp, 1);
        tagstruct.ImageWidth = size(ffp, 2);
        tagstruct.Compression = Tiff.Compression.None;
        tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP;
        tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
        tagstruct.BitsPerSample = 32;
        tagstruct.SamplesPerPixel = 1;
        tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
        t.setTag(tagstruct);
        t.write(single(ffp));
        t.close();
    end

    ffp_output_file = fullfile(output_dir, strcat(name, '_FFP','.tif'));

    t = Tiff(ffp_output_file, 'w');
    tagstruct.ImageLength = size(output_ffp, 1);
    tagstruct.ImageWidth = size(output_ffp, 2);
    tagstruct.Compression = Tiff.Compression.None;
    tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP;
    tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
    tagstruct.BitsPerSample = 32;
    tagstruct.SamplesPerPixel = 1;
    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    for ii=1:size(output_ffp,3)
        t.setTag(tagstruct);
        t.write(single(output_ffp(:,:,ii)));
        writeDirectory(t);
    end
    t.close();
    
end