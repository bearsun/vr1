function movieprac
%movieprac Practice before scan

global ptb_RootPath %#ok<NUSED>
global ptb_ConfigPath %#ok<NUSED>
%% prep params
rng('shuffle');
sid = 0;

srect = [0 0 1025 769];

subj=input('subject?','s');
session = input('session? (pre/post)','s');

% geometry
fixsi = 6;
fixring = 10;

white = [255 255 255];
black = [0 0 0];
green = [0 255 0];
red = [255 0 0];
fixcolor = white;
fixcolor2 = black;
bgcolor = black;

seq = [randperm(8,8),randperm(8,8),randperm(8,8)];
catchseq = zeros(1,24);
catchseq(randperm(24,8)) = 1;
cor = NaN(1,24);
rt = NaN(1,24);

kn0 = KbName('0');
kn1 = KbName('9');

possiblekn = [kn0,kn1];

path_data = [pwd,'/data/data-',subj,'-',session,'-mprac'];
outfile = fopen(path_data,'w');
fprintf(outfile,'%s\t %s\t %s\t %s\t %s\t %s\n','subject' ,'session' ,'trial','cond', 'cor', 'rt');

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

ntrials = numel(seq);
KbStrokeWait;
for itrial = 1:ntrials
    trialcond = seq(itrial);
    mv = PrepTrial(trialcond,catchseq(itrial));
    [cor(itrial),rt(itrial)]= showmov(mv,catchseq(itrial));
    fprintf(outfile,'%s\t %s\t %d\t %d\t %d\t %d\n', ...
        subj ,session ,itrial,trialcond, cor(itrial), rt(itrial));
end

fclose(outfile);
sca;

fprintf('Accuracy: %d\n',nansum(cor)/24);

%% PrepTrial: load movies
    function mv = PrepTrial(cond,bcatch)
        mv = NaN(3,1);
        mvangle = randperm(3,3);
        mvclip = randperm(4,3);
        if bcatch
            shapediff = mod(cond + randi(7)-1,8)+1;
            mv(1) = Screen('OpenMovie',mainwin,movpath{cond,mvangle(1),mvclip(1)});
            mv(2) = Screen('OpenMovie',mainwin,movpath{cond,mvangle(2),mvclip(2)});
            mv(3) = Screen('OpenMovie',mainwin,movpath{shapediff,mvangle(3),mvclip(3)});
        else
            mv(1) = Screen('OpenMovie',mainwin,movpath{cond,mvangle(1),mvclip(1)});
            mv(2) = Screen('OpenMovie',mainwin,movpath{cond,mvangle(2),mvclip(2)});
            mv(3) = Screen('OpenMovie',mainwin,movpath{cond,mvangle(3),mvclip(3)});
        end
    end

%% show movie and collect data (3s)
    function [tcor,rt]=showmov(mv,bcatch)
        % first movie
        for imv = 1:3 %three movie
            Screen('PlayMovie',mv(imv),1);
            moviestart = GetSecs;
            while GetSecs-moviestart <1%for iframe = 1:24 %800ms at 30Hz
                tex = Screen('GetMovieImage', mainwin, mv(imv));
                if tex<=0
                    break
                end
                Screen('DrawTexture', mainwin, tex);
                Screen('FillRect', mainwin, fixcolor2, fixRing);
                Screen('FillRect', mainwin, fixcolor, fixRect);
                Screen('Flip',mainwin);
                Screen('Close',tex);
            end
            % 200ms fixation
            Screen('FillRect', mainwin, fixcolor2, fixRing);
            Screen('FillRect', mainwin, fixcolor, fixRect);
            vonset = Screen('Flip',mainwin);
            Screen('PlayMovie',mv(imv),0);
            if imv == 3
                break
            end
            WaitSecs(.2);
        end
        
        
        keypressed = NaN;
        rt = NaN;
        while 1
            [keyIsDown, timeSecs, keyCode] = KbCheck;
            if keyIsDown
                if sum(keyCode) == 1
                    if any(keyCode(possiblekn))
                        keypressed=find(keyCode);
                        rt = timeSecs - vonset;
                        break;
                    end
                end
            end
        end
        
        for imv = 1:3
            Screen('CloseMovie', mv(imv));
        end
        % cor?
        tcor = (bcatch&&(keypressed == kn0))||((~bcatch)&&(keypressed == kn1));
        
        if tcor
            Screen('FillRect', mainwin, green, fixRect);
        else
            Screen('FillRect', mainwin, red, fixRect);
        end
        Screen('Flip',mainwin);
        WaitSecs(.1);
    end

end

