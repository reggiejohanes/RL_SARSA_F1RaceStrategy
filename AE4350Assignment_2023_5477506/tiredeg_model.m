function [fit,maxage] = tiredeg_model(n_laps,t_base)

%% RACE INFO

% clc
% clear
% close all
% 
% n_laps = 66;
% t_base = 76.33;

%% DEGRADATION ASSUMPTIONS

% best possible laptime for each compound
basetime(1) = t_base;
basetime(2) = basetime(1)/0.992;
basetime(3) = basetime(1)/0.993;

% assumed tire lifespan
maxage(1) = round(0.25*n_laps); % soft
maxage(2) = round(0.44*n_laps); % mediums
maxage(3) = round(0.65*n_laps); % hards

% additional time loss compared to base time when tire age = max age
maxdelta(1) = 1.4; % soft
maxdelta(2) = 1; % medium
maxdelta(3) = 2.2; % hard

% degradation rate multiplier when tire age > max age
droprate  = 5;

%% GENERATE FIT MATRIX

for i=1:3
    basedelta(i) = basetime(i)-basetime(1)+0.2;
    fit(i,:)     = polyfit([0 maxage(i)],[basedelta(i) basedelta(i)+maxdelta(i)],1);
    fit(i+3,1)   = fit(i,1)*droprate;
    fit(i+3,2)   = polyval(fit(i,:),maxage(i))-fit(i+3,1)*maxage(i);
end

%% VISUALIZE DEGRADATION

% xq=1:60;
% for cmpd=1:3
%     for tireage=xq
%         if tireage<=maxage(cmpd)
%             t(cmpd,tireage)=polyval(fit(cmpd,:),tireage-1);
%         else
%             t(cmpd,tireage)=polyval(fit(cmpd+3,:),tireage-1);
%         end
%         t_total(cmpd,tireage)=sum(t(cmpd,:));
%     end
% end
% 
% figure('Position', [800 200 700 600])
% hold on
% linestyle=[".-r",".-y",".-w"];
% for i=1:3
%     plot(xq-1,t_total(i,:),linestyle(i),'LineWidth',1)
% end
% legend(["SOFT","MEDIUM","HARD"],'Location','northwest','TextColor','w','Color','none')
% xlabel('Tire Age [laps]')
% ylabel('Cumulative Time Losses [s]')
% set(gca,'color',[0 0 0])
% grid on
% set(gca,'GridColor','w')
% ylim([0 160])
% 
% figure('Position', [50 200 700 600])
% hold on
% linestyle=[".-r",".-y",".-w"];
% for i=1:3
%     plot(xq-1,t(i,:),linestyle(i),'LineWidth',1)
% end
% legend(["SOFT","MEDIUM","HARD"],'Location','northwest','TextColor','w','Color','none')
% xlabel('Tire Age [laps]')
% ylabel('Gap to Ideal Laptime [s]')
% set(gca,'color',[0 0 0])
% grid on
% set(gca,'GridColor','w')
% ylim([0 7])

end