
% Course          : AE4350 Bio-Inspired Intelligence and Learning for
%                   Aerospace Applications
% Student Name    : Reggie Johanes
% Student Number  : 5477506
% Submission Date : 31 August 2023

% Learning process will take roughly 1-2 minutes to complete with 80000 episodes.

clc
clear
close all

tic

starttime = datetime; % start date & time
figname = 'Figures\fig' + string(starttime,"yyyyMMdd_HHmmss");
logname = 'Dataout\' + string(starttime,"yyyyMMdd_HHmmss");

%% SETUP

% race parameters ---------------------------------------------------------
% determine basic race parameters based on race data:
% number of laps, base time (fastest lap), pit duration, time loss at start

filename = 'Data/2023-7-R.csv';
[n_laps,t_base,pitavg,pitinavg,pitoutavg,tstart] = getraceinfo(filename);

% tire parameters ---------------------------------------------------------
% generate tire degradation model -- optimized for VER @ 2023 Spannish GP

n_cmpds       = 3; % number of different compounds used
[fit,maxage]  = tiredeg_model(n_laps,t_base);

% fuel parameters ---------------------------------------------------------
fuel_start    = 110;   % [kg] fuel load at start of race
fuel_end      = 0;     % [kg] fuel load at end of race
fuel_penalty  = 0.03;  % [s/kg] 
fuel_load     = linspace(fuel_start,fuel_end,n_laps+1); % [kg] fuel weight at start of each lap
t_fuel        = fuel_load * fuel_penalty; % time loss due to fuel weight

dummy1        = zeros(n_laps+2,1);
dummy1(1)     = t_fuel(1); % duplicate first fuel load for pseudostart
dummy1(2:end) = t_fuel;
t_fuel        = dummy1;
clear dummy1

% driver laptime variance -------------------------------------------------
mu            = 0;     % mean
sigma         = 0.2; % standard deviation

% possible actions --------------------------------------------------------
action_list   = [1,... % stay out
                 2,... % pit for new softs (at end of lap)
                 3,... % pit for new mediums
                 4];   % pit for new hards

% initialize policy & Q matrices ------------------------------------------
policy        = randi(length(action_list),[n_laps+1,n_laps+1,n_cmpds,n_cmpds]);
Q             = zeros(n_laps+1,n_laps+1,n_cmpds,n_cmpds,length(action_list));

% no. of episodes ---------------------------------------------------------
n_episodes    = 80000;

% initialize history matrices ---------------------------------------------
racetime_hist = zeros(n_episodes,1);
laptime_hist  = zeros(n_laps+1,n_episodes);
action_hist   = zeros(n_laps+1,n_episodes);
cmpd_hist     = zeros(n_laps+1,n_episodes);

% learning parameters -----------------------------------------------------
alpha         = 1.0;   % learning rate
gamma         = 1.0;   % discount rate
eps           = 0.0;   % exploration probability

%% LEARNING LOOP

fprintf('Learning Progress:\n')
fprintf(' ____________________ \n')
fprintf('|START       COMPLETE|\n')
fprintf(' ')

for episode = 1:n_episodes

    % start state & action
    s = [1,... % lap number
         1,... % tire age
         1,... % tire compound (1=soft, 2=med, 3=hard)
         1];   % number of unique compounds used (min=2)
    action = policy(s(1),s(2),s(3),s(4));

    % initialize pit duration arrays
    t_pit_in  = zeros(n_laps+1,1);
    t_pit_out = zeros(n_laps+1,1);

    % generate lap time variance
    clear t_lapvar
    t_lapvar = sigma.*randn(n_laps+1,1)+mu;
%     t_lapvar = zeros(n_laps+1,1); % uncomment to disable lap time variance

    for lap=1:n_laps+1
        
        cmpd_hist(lap,episode)   = s(3);   % save tire compound history
        action_hist(lap,episode) = action; % save action history
        
        % update new states -----------------------------------------------
        
        % lap number
        ns(1) = min(s(1)+1,n_laps+1);

        % tyre age & compound
        if action==1           % 1 = stay out
            ns(2) = min(s(2)+1,n_laps+1);
            ns(3) = s(3);
        else
            ns(2) = 1;
            if action == 2     % 2 = pit for softs
                ns(3) = 1;
            elseif action == 3 % 3 = pit for mediums
                ns(3) = 2;
            elseif action == 4 % 4 = pit for hards
                ns(3) = 3;
            else
                error('Unknown Action')
            end
        end
        if lap==1
            ns(2)=1; % reset tyre age at pseudostart
        end

        % number of unique compounds used
        if lap==1
            ns(4)=1; % reset count at pseudostart
        else
            ns(4)=length(unique(nonzeros(cmpd_hist(2:end,episode))));
        end

        % reward (calculate laptime) --------------------------------------
        
        % pit duration
        if action~=1 && lap~=1
            t_pit_in(lap) = pitinavg;
            t_pit_out(lap+1) = pitoutavg;
        end

        % tire degradation
        tire_age = s(2)-1;
        if tire_age<=maxage(s(3))
            t_tire = polyval(fit(s(3),:),tire_age);
        else
            t_tire = polyval(fit(s(3)+3,:),tire_age);
        end

        % 2-compound rule penalty
        if s(1)==n_laps-1 && s(4)==1
            t_penalty=100;
        else
            t_penalty=0;
        end

        % time loss at start
        if s(1)==2
            t_start=tstart;
        else
            t_start=0;
        end

        % no laptime for pseudostate
        if lap==1
            laptime_hist(lap,episode) = 0;
        else
            laptime_hist(lap,episode) = t_base + t_start + t_tire + t_fuel(lap)...
                                     + t_pit_in(lap) + t_pit_out(lap)...
                                     + t_penalty + t_lapvar(lap);
        end
        reward = -1*(laptime_hist(lap,episode));

        % new action according to current policy --------------------------
        newaction = policy(ns(1),ns(2),ns(3),ns(4));

        % update state-action values --------------------------------------
        if lap~=n_laps+1 
            Q(s(1),s(2),s(3),s(4),action) = Q(s(1),s(2),s(3),s(4),action)+...
                alpha*(reward+gamma*Q(ns(1),ns(2),ns(3),ns(4),newaction)-...
                Q(s(1),s(2),s(3),s(4),action));
        else % terminal state (last lap)
            Q(s(1),s(2),s(3),s(4),action) = Q(s(1),s(2),s(3),s(4),action)+...
                alpha*(reward+gamma*0-Q(s(1),s(2),s(3),s(4),action));
        end

        % update policy ---------------------------------------------------
        if rand<eps
            policy(s(1),s(2),s(3),s(4)) = randi(length(action_list));
        else
            dummy(:,:) = Q(s(1),s(2),s(3),s(4),:);
            [~,policy(s(1),s(2),s(3),s(4))] = max(dummy);
            clear dummy;
        end

        % update state and action -----------------------------------------
        s = ns; % state = newstate
        action = newaction;
    end
    racetime_hist(episode) = sum(laptime_hist(:,episode)); % save racetime history
    if rem(episode,n_episodes/20)==0
        fprintf('=')
    end
end

% remove first lap (pseudostart)
laptime_hist(1,:) = [];
cmpd_hist(1,:)    = [];
action_hist(1,:)  = [];

%% RESULTS

close all

% print last & best race times --------------------------------------------
last_racetime=racetime_hist(n_episodes);
time=seconds(last_racetime);
time.Format='hh:mm:ss.SSS';
fprintf('\n')
fprintf('\n')
fprintf('Last race time = '+string(time)+'\n')

best_racetime=min(racetime_hist);
best_time=seconds(best_racetime);
best_time.Format='hh:mm:ss.SSS';
fprintf('Best race time = '+string(best_time)+'\n')
fprintf('\n')

% plot learning progress --------------------------------------------------
fig(1)=figure('Name','Learning Progress','Position', [50 250 600 500]);
plot(racetime_hist)
title('Learning Progress')
xlabel('Episode')
ylabel('Total Race Time [s]')
grid on
% xlim([0 80000])

% plot laptimes -----------------------------------------------------------

% compile laptimes by stints
pitlaps=[];
for i=1:n_laps
    if action_hist(i,end)~=1
        pitlaps(end+1)=i;
    end
end
n_pits=length(pitlaps);
n_stints=n_pits+1;
for i=1:n_stints
    stintnames(i)="stint"+string(i);
    if i==1
        stints.(stintnames(i)).stint_start_lap=1;
    else
        stints.(stintnames(i)).stint_start_lap=pitlaps(i-1)+1;
    end
    i_cmpd=min(stints.(stintnames(i)).stint_start_lap+1,n_laps);
    stints.(stintnames(i)).cmpd=cmpd_hist(i_cmpd,end);
end
for i=1:n_stints
    stintstart=stints.(stintnames(i)).stint_start_lap;
    if i==n_pits+1
        stintend=n_laps;
    else
        stintend=stints.(stintnames(i+1)).stint_start_lap-1;
    end
    stints.(stintnames(i)).laptimes(:,1)=linspace(stintstart,stintend,(stintend-stintstart+1));
    stints.(stintnames(i)).laptimes(:,2)=laptime_hist(stintstart:stintend,end);
end

% plot stints
fig(2)=figure('Position', [700 200 600 450]);
title('Lap Times (Last Episode), Total Race Time: '+string(time))
hold on
for i=1:n_stints
    plotdata=stints.(stintnames(i)).laptimes;
    plotcmpd=stints.(stintnames(i)).cmpd;
    if plotcmpd == 3
        plotstyle='.-w';
    elseif plotcmpd == 2
        plotstyle='.-y';
    else
        plotstyle='.-r';
    end
    plot(plotdata(:,1),plotdata(:,2),plotstyle)
end
xlabel('Lap Number')
ylabel('Lap Time [s]')
set(gca,'color',[0 0 0])
set(gcf, 'InvertHardCopy', 'off'); 
grid on
set(gca,'GridColor','w')

% save figures ------------------------------------------------------------
savefig(fig,figname+ '_figs');

saveas(fig(1),figname+'_fig1','jpeg')
saveas(fig(2),figname+'_fig2','jpeg')

% save(logname)

toc
