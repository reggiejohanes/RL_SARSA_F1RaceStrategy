function [n_laps,FL,pitavg,pitinavg,pitoutavg,t_start] = getraceinfo(filename)

% clc
% clear
% % close all
% filename = 'Data/2022-6-R.csv';

% import raw data ---------------------------------------------------------
rawdata = readtable(filename);

% check number of laps, fastest lap time ----------------------------------
n_laps  = max(rawdata.LapNumber);
FL      = min(rawdata.LapTime_in_seconds);
FL107   = FL*1.07;

% calculate fuel-corrected laptimes ---------------------------------------
fuel_start               = 110;
fuel_end                 = 1;
fuel_penalty             = 0.03;
rawdata.FuelWeight       = interp1([1 n_laps+1],[fuel_start fuel_end],rawdata.LapNumber);
rawdata.FuelPenalty      = rawdata.FuelWeight*fuel_penalty;
rawdata.CorrectedLaptime = rawdata.LapTime_in_seconds-rawdata.FuelPenalty;

% calculate average time loss due to pit ----------------------------------
pittimes=[];
% for i=1:height(rawdata)-1
%     driver1    = string(rawdata.Driver(i));
%     driver2    = string(rawdata.Driver(i+1));
%     pitintime  = string(rawdata.PitInTime(i));
%     pitouttime = string(rawdata.PitOutTime(i+1));
%     strlen1    = strlength(pitintime);
%     strlen2    = strlength(pitouttime);
%     if driver1==driver2 && strlen1>0 && strlen2>0
%         pitintime       = duration(str2double(strsplit(extractAfter(pitintime,7),':')));
%         pitouttime      = duration(str2double(strsplit(extractAfter(pitouttime,7),':')));
%         pitduration     = pitouttime-pitintime;
%         pittimes(end+1) = seconds(pitduration);
%     end
% end
for i=1:height(rawdata)-3
    pitintime  = string(rawdata.PitInTime(i+1));
    pitouttime = string(rawdata.PitOutTime(i+2));
    lapnumber  = rawdata.LapNumber(i);
    strlen1    = strlength(pitintime);
    strlen2    = strlength(pitouttime);
    if lapnumber<n_laps-3 && strlen1>0 && strlen2>0
        laptime1   = rawdata.CorrectedLaptime(i);
        laptime2   = rawdata.CorrectedLaptime(i+1);
        laptime3   = rawdata.CorrectedLaptime(i+2);
        laptime4   = rawdata.CorrectedLaptime(i+3);
        pitinduration     = laptime2-laptime1;
        pitoutduration    = laptime3-laptime4;
        pitduration       = pitinduration+pitoutduration;
        pittimes(end+1,1) = pitinduration;
        pittimes(end,2)   = pitoutduration;
        pittimes(end,3)   = pitduration;
    end
end
% for i=1:length(pittimes)
%     if isnan(sum(pittimes(i,:)))
%         pittimes(i,:)=[];
%     end
% end
pitinavg  = mean(rmmissing(pittimes(:,1)));
pitoutavg = mean(rmmissing(pittimes(:,2)));
pitavg    = mean(rmmissing(pittimes(:,3)));

% calculate average time loss at start ------------------------------------
starttimes=[];
for i=1:height(rawdata)-1
    t_lap1  = rawdata.CorrectedLaptime(i);
    t_lap2  = rawdata.CorrectedLaptime(i+1);
    if rawdata.LapNumber(i)==1 && t_lap2<=FL107
        gridpos = rawdata.Position(i);
        t_start = t_lap1-t_lap2;
        starttimes(end+1,1) = gridpos; %position at end of lap 1
        starttimes(end,2)   = t_start;
%         starttimes(end,3)   = i;
    end
end
t_start=min(starttimes(:,2));

% t_start = polyval(tstartfit,gridpos);
% tstartfit = polyfit(starttimes(:,1),starttimes(:,2),1);
% xplot=1:20;
% yplot=polyval(tstartfit,xplot);
% figure
% plot(starttimes(:,1),starttimes(:,2),'ok')
% hold on
% plot(xplot,yplot,'r')
% grid on

end