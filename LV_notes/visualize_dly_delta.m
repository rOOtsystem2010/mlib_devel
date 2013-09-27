clear; clc; close all;

round_hund=@(x) round(x*100)/100;

clk = 286e6;
refclk = 200e6;
delays_per_ref = 64;

DLY_DELTA = 1/refclk/delays_per_ref; %specified in ps
HOLD_TIME = 400e-12; % specified in ps
BIT_STEPS = HOLD_TIME/DLY_DELTA+1;




num_per = 4;
%num_dly_2plot = 10;

per = 1/clk;
half_per = per/2;
num_half_per = 32;


t = linspace(0,num_per*per,10000);
clk_val = ones(size(t));

% want everything in the first clock cycle to be 1, so thats odd multiples
% of half_per, so all values from 0*half_per to 1*half_per, all values from
% 2*half_per to 3*half_per, etc...

for k = 0:2:num_half_per
    %k
    clk_val(k*half_per<=t & t<(k+1)*half_per) = 0;
end

% plot clock and label ns
plot(t*1e9, clk_val)
xlabel('nanoseconds')
ylim([-1 2])
hold on
plot([0 0],[-0.5 1.5],'k:')
text(0+0.1*half_per,1.5,[num2str(0),' ns'])
plot([half_per*1e9 half_per*1e9],[-0.5 1.5],'k:')
text(half_per*1e9+0.1*half_per,1.5,[num2str(half_per*1e9),' ns'])
plot([per*1e9 per*1e9],[-0.5 1.5],'k:')
text(per*1e9+0.1*half_per,1.5,[num2str(per*1e9),' ns'])

num_dly_per_per = per/DLY_DELTA;
%num_dly_2plot = num_dly_per_per/2;
num_dly_2plot = num_half_per;

dly_loc = linspace(0,num_dly_2plot-1,num_dly_2plot)*DLY_DELTA+per+half_per;
for dly = 1:num_dly_2plot
    plot([dly_loc(dly)*1e9 dly_loc(dly)*1e9],[0.85,1.15],'m')
end
text(dly_loc(1)*1e9+0.1*half_per,1.05,[num2str(DLY_DELTA*1e12),'ps'])

num_hold_per_per = per/HOLD_TIME;
num_hold_2plot = num_hold_per_per/2;

hold_loc = linspace(0,num_hold_2plot-1,num_hold_2plot)*HOLD_TIME+2*per+half_per;
for hld = 1:num_hold_2plot
    plot([hold_loc(hld)*1e9 hold_loc(hld)*1e9],[0.85,1.15],'g')
end
text(hold_loc(1)*1e9+0.1*half_per,1.05,[num2str(HOLD_TIME*1e12),'ps'])


title({['Clk Freq ',num2str(clk/1e6),' MHz, Period ',num2str(per*1e9),' ns']; ...
    ['Ref Clk Freq ',num2str(refclk/1e6),' MHz, assume 32 delays per half period'];...
    ['Num ',num2str(DLY_DELTA*1e12),'ps delays per half period: \approx ',num2str(round_hund(num_dly_per_per/2))]; ...
    ['Num 400ps hold times per period: \approx ',num2str(round_hund(num_hold_per_per))]; ...
    ['Num delays in hold: \approx ',num2str(round_hund(BIT_STEPS-1)),' (BIT STEPS \approx',num2str(round_hund(BIT_STEPS)),')']})

text(0.5,-0.7,'32 delays plotted, length calculated from refclk','color','m')
text(0.5,-0.9,'FPGA clk plotted in blue','color','blue')