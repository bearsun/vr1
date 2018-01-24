function movierun_fmri(debug)
%VRUN Do one run
%   show pictures of 8 same-objects trials (1~8), 1 diff-obj trial(9), and
%   null trial (0).

global ptb_RootPath %#ok<NUSED>
global ptb_ConfigPath %#ok<NUSED>
%% prep params
rng('shuffle');
sid = 0;
tbeginning = NaN;
srect = [0 0 1025 769];
% monitorh=34.3;
% distance=110.5;

% request subj init, session, run number
subj=input('subject?','s');
session = input('session? (pre/post)','s');
run=input('run?');

% geometry
fixsi = 6;
fixring = 10;

% mri para
tr = 0; %TR counter

% color
%gray = [127 127 127];
white = [255 255 255];
black = [0 0 0];
% green = [0 255 0];
% red = [255 0 0];
fixcolor = white;
fixcolor2 = black;
bgcolor = black;

% load seq
seqfile = load('seqruns.mat');
seqruns = seqfile.seqruns;
catchseq = seqfile.catchseq;
seq = seqruns(:,run);
catchsq = catchseq(:,run);

% start_time of each trial (each trial 3TR = 6s)
tstart_tr = 1:3:(numel(seq)*3);

% button -----------------need to check 2 button box
if debug
    kn0 = KbName('Up');
    kn1 = KbName('Down');
    BUFFER = [];
    BUTTONS = [kn0,kn1];
    buttons = BUTTONS;
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

% possiblekn = [kn0,kn1];
sameobj = seq(seq~=0)~=9; %cut all zeros
seqcorkey = ones(numel(sameobj),1)*kn1;
seqcorkey(sameobj) = kn0;
% accuracy vector
cor = NaN(sum(seq>0),1);

%% open scanner communication
if ~debug
    IOPort('Closeall');
    P4 = IOPort('OpenSerialPort', '/dev/ttyUSB0','BaudRate=115200'); %open port for receiving scanner pulse
    fRead = @() ReadScanner;
else
    fRead = @() ReadFakeTrigger;
    tr_tmr = timer('TimerFcn',@SetTrigger,'Period',2,'ExecutionMode','fixedDelay','Name','tr_timer');
end

%% open files
path_data = [pwd,'/data/data-',subj,'-',session,'-run',num2str(run)];
log_data = [pwd,'/data/data-',subj,'-',session,'-run',num2str(run),'-log'];
design_data = [pwd,'/data/data-',subj,'-',session,'-run',num2str(run),'-design'];

outdesign = fopen(design_data,'w');
fprintf(outdesign,'%s %s\n','tr_start','trial_cond');
fprintf(outdesign,'%d %d\n', [tstart_tr;seq']);
fclose(outdesign);

outlog = fopen(log_data,'w');
fprintf(outlog,'%s\t %s\n','when','what');

outfile = fopen(path_data,'w');
fprintf(outfile,'%s\t %s\t %s\t %s\t %s\t %s\t %s\n','subject' ,'session' ,'trial','cond', 'keypressed', 'cor', 'rt');

%% initialize window and object pictures
[mainwin,rect] = Screen('OpenWindow', sid, bgcolor, srect);

fixRect = CenterRect([0 0 fixsi fixsi], rect);
fixRing = CenterRect([0 0 fixring fixring], rect);
Screen('FillRect', mainwin, fixcolor2, fixRing);
Screen('FillRect', mainwin, fixcolor, fixRect);

% load all movies 8 objects X 3 view angles X 4 movies
views = 'lmr';
movpath = cell(8,3,4);
for iobj = 1:8
    for iview = 1:3
        for imov = 1:4
        movpath{iobj,iview,imov} = ['/home/liwei/Documents/studies/vr/objmov/obj',num2str(iobj),views(iview),'-',num2str(imov),'.mp4'];
        end
    end
end

%% Trial
% for debug
if debug
    start(tr_tmr);
end
trialtime = NaN;
resptrial = 1; %for non-zero trial counter
ntrials = numel(seq);
for itrial = 1:ntrials
    trialcond = seq(itrial);
    
    if trialcond
        mv = PrepTrial(trialcond,itrial);
    end
    
    lasttrialtime = trialtime;
    % timelock the beginning of each trial to certain tr
    TRWait(tstart_tr(itrial));
    trialtime = GetSecs;
    disp('trialtime');
    disp(trialtime-lasttrialtime);
    if trialcond == 0 %null trial
        Screen('FillRect', mainwin, fixcolor2, fixRing);
        Screen('FillRect', mainwin, fixcolor, fixRect);
        Screen('Flip',mainwin);
        continue
    end
    
    % Do trial
    showmov(mv,resptrial,trialcond);
    resptrial = resptrial+1;
end

%% save and close everything
WaitSecs(6); %last blank trial
fRead();
fclose(outfile);
fclose(outlog);
if debug
    StopTimer;
else
    IOPort('Closeall');
end

sca;

fprintf('Accuracy: %d\n',nansum(cor)/numel(cor));

%% PrepTrial: load movies
    function mv = PrepTrial(cond,trial)
        mv = NaN(3,1);
        mvangle = randperm(3,3);
        mvclip = randperm(4,3);
        if cond == 9
            targetobj = catchsq(trial);
            shapediff = mod(targetobj + randi(7)-1,8)+1;
            mv(1) = Screen('OpenMovie',mainwin,movpath{targetobj,mvangle(1),mvclip(1)});
            mv(2) = Screen('OpenMovie',mainwin,movpath{targetobj,mvangle(2),mvclip(2)});
            mv(3) = Screen('OpenMovie',mainwin,movpath{shapediff,mvangle(3),mvclip(3)});
        else
            mv(1) = Screen('OpenMovie',mainwin,movpath{cond,mvangle(1),mvclip(1)});
            mv(2) = Screen('OpenMovie',mainwin,movpath{cond,mvangle(2),mvclip(2)});
            mv(3) = Screen('OpenMovie',mainwin,movpath{cond,mvangle(3),mvclip(3)});
        end
    end

%% show movie and collect data (3s)
    function showmov(mv,trial,cond)
        trialstart = GetSecs;
        % first movie
        for imv = 1:3 %three movie
            Screen('PlayMovie',mv(imv),1);
            moviestart = GetSecs;
            while GetSecs-moviestart <.77%for iframe = 1:24 %800ms at 30Hz
                tex = Screen('GetMovieImage', mainwin, mv(imv));
                if tex<=0
                    break
                end
                Screen('DrawTexture', mainwin, tex);
                Screen('FillRect', mainwin, fixcolor2, fixRing);
                Screen('FillRect', mainwin, fixcolor, fixRect);
%                 Screen('Flip',mainwin,[],1);
                Screen('Flip',mainwin);
                Screen('Close',tex);
            end
            % 200ms fixation
            Screen('FillRect', mainwin, fixcolor2, fixRing);
            Screen('FillRect', mainwin, fixcolor, fixRect);
            eachmvend = Screen('Flip',mainwin);
            Screen('PlayMovie',mv(imv),0);
            if imv == 3
                break
            end
            WaitSecs(.2);
            disp('each movie:');
            disp(eachmvend-moviestart);
        end
        
        % wait for response
        bresponded = 0;
        keypressed = NaN;
        rt = NaN;
        while ~bresponded
            [data, when] = fRead();
            if ~isempty(data)
                if ismember(data,buttons)
                    keypressed = buttons(ismember(buttons,data));
                    rt = when-eachmvend;
                    bresponded = 1;
                    fprintf('BUTTON RECIEVED: %d @ %d\n',keypressed,rt*1000);
                    fprintf(outlog,'BUTTON RECIEVED: %d @ %d\n',keypressed,rt);
                end
            end
            
            if GetSecs-eachmvend >= 2.5  %%%test to determine non-response
                break
            end
            WaitSecs(.02);
        end
        
        % close movies
        for imv = 1:3
            Screen('CloseMovie', mv(imv));
        end
        
        % feedback and save
        if keypressed == seqcorkey(trial)
            cor(trial) = 1;
%             Screen('FillRect', mainwin, green, fixRect);
        else
%             Screen('FillRect', mainwin, red, fixRect);
            cor(trial) = 0;
        end
        fprintf(outfile,'%s\t %s\t %d\t %d\t %d\t %d %d\n', ...
            subj, session, trial, cond, keypressed, cor(trial),rt);
%         tfb = Screen('Flip', mainwin);
%         tt = GetSecs;
%         fbon = 1;
%         while tt-tstart < 3
%             WaitSecs(.02);
%             tt = GetSecs;
%             if fbon && (tt - tfb > .2) %feedback on for 200ms maximally
% %                 Screen('FillRect', mainwin, fixcolor, fixRect);
%                 Screen('Flip', mainwin);
%                 fbon = 0;
%             end
%         end
        disp('trialend:');
        disp(GetSecs-trialstart);
    end

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

