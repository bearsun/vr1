function rsc_loc(debug)
%RSC_LOC localizer for rsc and ppa
%   Scene > objects, scrambled objects > scene
global ptb_RootPath %#ok<NUSED>
global ptb_ConfigPath %#ok<NUSED>
rng('shuffle');

% Screen('Preference', 'SkipSyncTests', 1);

%% parameter
postscreenwait = 4; % Screen wait after IOport closed
tr = 0;
tbeginning = NaN;
pretr = 5;
blocktr = 15; %15s sti, 15s fixation
nrepeat = 4;
blocktypes = [1 2 3]; %scene, objects, scrambled objects
block_seq = repmat(blocktypes,1,nrepeat);

block_start = cumsum([1,ones(1,numel(block_seq)-1)*blocktr])+pretr;

nblock = numel(block_seq);

% geometry
sid = 0;
srect = [0 0 1025 769];
fixsi = 6;
fixring = 10;

% colors
gray = [127 127 127];
white = [255 255 255 255];
black = [0 0 0];
% green = [0 255 0];
bgcolor = gray;
fixcolor = white;
fixcolor2 = black;

% button -----------------need to check 2 button box
if debug
    kn0 = KbName('Up');
    kn1 = KbName('Down');
    BUFFER = [];
    BUTTONS = [kn0,kn1];
    CODES = 49:50;
else
    % buttonbox setting
    buttons = 49:50; %top, left, (right, bottom)
    trigger=53;
    kn0 = buttons(1); %top
    kn1 = buttons(2); %left
    %kn2 = buttons(4); %right
    %kn3 = buttons(3); %bottom
end

possiblekn = [kn0,kn1];

%% random sequence of pics
% 15 pics per block, 12 block, 88 availabe pics in each category
seqpics = randi(88,nblock,15);
% add random repeat, 2 repeats per block
for iblock = 1:12
    krepeat1 = randi(7)+1;% 2 to 8
    seqpics(iblock,krepeat1) = seqpics(iblock,krepeat1-1);
    krepeat2 = randi(6)+9;
    seqpics(iblock,krepeat2) = seqpics(iblock,krepeat2-1);
end

%% open scanner communication
if ~debug
    IOPort('Closeall');
    P4 = IOPort('OpenSerialPort', '/dev/ttyUSB0','BaudRate=115200'); %open port for receiving scanner pulse
    fRead = @() ReadScanner;
else
    fRead = @() ReadFakeTrigger;
    tr_tmr = timer('TimerFcn',@SetTrigger,'Period',2,'ExecutionMode','fixedDelay','Name','tr_timer');
end

subj=input('subject?','s');

log_data = [pwd,'/data/rsc-loc-',subj,'-log'];
design_data = [pwd,'/data/rsc-loc-',subj,'-design'];

outdesign = fopen(design_data,'w');
fprintf(outdesign,'%s\t %s\n','block_start','block_seq');
fprintf(outdesign,'%d\t %d\n', [block_start;block_seq]);
fclose(outdesign);

outlog = fopen(log_data,'w');
fprintf(outlog,'%s\t %s\n','when','what');

%% initialize window
[mainwin,rect] = Screen('OpenWindow', sid, bgcolor, srect);

%center = [(rect(3)-rect(1))/2, (rect(4)-rect(2))/2];
fixRect = CenterRect([0 0 fixsi fixsi], rect);
fixRing = CenterRect([0 0 fixring fixring], rect);

%% exp start
% for debug
if debug
    start(tr_tmr);
end

% recording any button press
pressseq = NaN(nblock,17); %17 check in photo seq

Screen('FillRect', mainwin, fixcolor2, fixRing);
Screen('FillRect', mainwin, fixcolor, fixRect);
Screen('Flip', mainwin);
for block = 1:nblock
    
    btype = block_seq(block);
    seqpic = seqpics(block,:);
    switch btype
        case 1 %scene
            prefile = './localizer_combined/scenes/nonfamousplace (';
        case 2 %object
            prefile = './localizer_combined/objects/objects (';
        case 3 %scrambled
            prefile = './localizer_combined/objects_scrambled/objectsScram (';
    end
    
    TRWait(block_start(block));
    for iphoto = 1:17 %1 pic per sec
        tstart = GetSecs;
        if iphoto<16
            immat = imread([prefile,num2str(seqpic(iphoto)),').bmp']);
            t = Screen('MakeTexture', mainwin, immat);
            Screen('DrawTexture', mainwin, t);
        end
        Screen('FillRect', mainwin, fixcolor2, fixRing);
        Screen('FillRect', mainwin, fixcolor, fixRect);
        Screen('Flip',mainwin);
        WaitSecs(.8);
        Screen('FillRect', mainwin, fixcolor2, fixRing);
        Screen('FillRect', mainwin, fixcolor, fixRect);
        Screen('Flip',mainwin);
        if iphoto<16
            Screen('Close',t);
        end
        while GetSecs - tstart < 1
            WaitSecs(.01);
        end
        [data,when] = fRead();
        if ismember(data,possiblekn)
            pressseq(block,iphoto) = 1;
            fprintf('%d\t %s\n',when-tbeginning,'Keydown');
            fprintf(outlog, '%d\t %s\n',when-tbeginning,'Keydown');
        end
    end
    Screen('FillRect', mainwin, fixcolor2, fixRing);
    Screen('FillRect', mainwin, fixcolor, fixRect);
    Screen('Flip',mainwin);
end

%% check accuracy
cor = [];
for block = 1:nblock
    seqpic = seqpics(block,:);
    seqkey = pressseq(block,:);
    lastpic = seqpic(1);
    for iphoto = 2:15
        if seqpic(iphoto) == lastpic
            cor = [cor;any(seqkey(iphoto:(iphoto+2)))]; %#ok<AGROW>
        end
        lastpic = seqpic(iphoto);
    end
end

acc = mean(cor);

%% save and close everything

TRWait(block_start(end)+blocktr); % wait for all stuff end
if debug
    StopTimer;
else
    IOPort('Closeall');
end

WaitSecs(postscreenwait);

fprintf('Accuracy: %d\n',acc);
fprintf(outlog,'Accuracy: %d\n',acc);
save([pwd,'/data/rsc-loc-',subj,'.mat'],'seqpics','pressseq');
sca;
fclose(outlog);

%% function wrapper for IOPort('Read'),also counting the total TRs
    function [data, when] = ReadScanner
        [data, when] = IOPort('Read',P4);
        
        if ~isempty(data)
            fprintf('data: %d\n',data);
            tr=tr+sum(data==trigger);
            if tr == 1
                tbeginning = when;
            end
            fprintf('%d\t %d\n',when-tbeginning,tr);
            fprintf(outlog, '%d\t %d\n',when-tbeginning,tr);
        end
    end

%% function to wait until certain trs
    function TRWait(t)
        while t > tr
            fRead();
            WaitSecs(.01);
        end
    end

%% function to read the faked triggers from buffer
    function [data,when] = ReadFakeTrigger
        data = BUFFER;
        BUFFER = [];
        [~,~,kDown] = KbCheck;
        b = logical(kDown(BUTTONS));
        BUFFER = [BUFFER CODES(b)];
        when = GetSecs;
    end
%-----------------------------------------------------------------------------%
%% function to simulate triggers in the buffer, handle for timer
    function SetTrigger(varargin)
        tr=tr+1;
        fprintf('TR TRIGGER %d\n',tr);
        BUFFER = [BUFFER 53];
    end
%-----------------------------------------------------------------------------%
%% function to stop the simulation
    function StopTimer
        if isobject(tr_tmr) && isvalid(tr_tmr)
            if strcmpi(tr_tmr.Running,'on')
                stop(tr_tmr);
            end
            delete(tr_tmr);
        end
    end
end

