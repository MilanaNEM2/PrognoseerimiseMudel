% See skript treenib närvivõrgu mudeli hüpoteetilise hoonete energiatarbimise ennustamiseks
clc; clear;

% Hoone pindalade määramine ruutmeetrites
areaSOC = 10360; % SOC hoone pindala
areaTIM = 642.0; % TIM hoone pindala
areaD04 = 4323.6; % D04 hoone pindala

% Sisend- ja väljundandmete laadimine  failidest
inputAll = readtable('Input_data_SOC_TIM_D04.csv', 'Delimiter', ';');
outputAll = readtable('Output_data_S01.csv', 'Delimiter', ';');


% teisendatakse stringidest arvudeks  hoonete tarbimisväärtused
for col = {'SOC','TIM','D04'}
    inputAll.(col{1}) = str2double(strrep(string(inputAll.(col{1})), ',', '.'));
end
outputAll.S01 = str2double(strrep(string(outputAll.S01), ',', '.'));
 % luuakse ajatemplid perioodide ja kellaaegade põhjal
inputAll.FullTime = datetime(inputAll.Periood, 'InputFormat','dd.MM.yyyy') + duration(inputAll.time);
outputAll.FullTime = datetime(outputAll.Periood, 'InputFormat','dd.MM.yyyy') + duration(outputAll.time);

%õppimiseks kasutatavate nädalate ja vastavate ilmastikufailide määratlemine
weeks = {
    % Jaanuari andmeperioodid
    struct('start', datetime(2023,1,2), 'end', datetime(2023,1,8,23,0,0), 'weatherFile', 'Tallinn 2023-01-01 to 2023-01-31.csv');
    struct('start', datetime(2023,1,16), 'end', datetime(2023,1,22,23,0,0), 'weatherFile', 'Tallinn 2023-01-01 to 2023-01-31.csv');

    %Veebruari andmeperioodid
    struct('start', datetime(2023,2,6), 'end', datetime(2023,2,12,23,0,0), 'weatherFile', 'Tallinn 2023-02-01 to 2023-02-28.csv');
    struct('start', datetime(2023,2,20), 'end', datetime(2023,2,26,23,0,0), 'weatherFile', 'Tallinn 2023-02-01 to 2023-02-28.csv');

    %Märtsi ja aprilli andmeperioodid
    struct('start', datetime(2023,3,13), 'end', datetime(2023,3,19,23,0,0), 'weatherFile', 'Tallinn 2023-03-01 to 2023-04-30.csv');
    struct('start', datetime(2023,4,3), 'end', datetime(2023,4,9,23,0,0), 'weatherFile', 'Tallinn 2023-03-01 to 2023-04-30.csv');

    %Mai andmeperioodid
    struct('start', datetime(2023,5,8), 'end', datetime(2023,5,14,23,0,0), 'weatherFile', 'Tallinn 2023-05-01 to 2023-05-31.csv');
    struct('start', datetime(2023,5,22), 'end', datetime(2023,5,28,23,0,0), 'weatherFile', 'Tallinn 2023-05-01 to 2023-05-31.csv');

    %Juuni andmeperioodid
    struct('start', datetime(2023,6,5), 'end', datetime(2023,6,11,23,0,0), 'weatherFile', 'Tallinn 2023-06-01 to 2023-06-30.csv');
    struct('start', datetime(2023,6,19), 'end', datetime(2023,6,25,23,0,0), 'weatherFile', 'Tallinn 2023-06-01 to 2023-06-30.csv');

    %Juuli ja augusti andmeperioodid
    struct('start', datetime(2023,7,10), 'end', datetime(2023,7,16,23,0,0), 'weatherFile', 'Tallinn 2023-07-01 to 2023-08-31.csv');
    struct('start', datetime(2023,8,14), 'end', datetime(2023,8,20,23,0,0), 'weatherFile', 'Tallinn 2023-07-01 to 2023-08-31.csv');

    %Septembri  andmeperioodid
    struct('start', datetime(2023,9,4), 'end', datetime(2023,9,10,23,0,0), 'weatherFile', 'Tallinn 2023-09-01 to 2023-09-30.csv');
    struct('start', datetime(2023,9,18), 'end', datetime(2023,9,24,23,0,0), 'weatherFile', 'Tallinn 2023-09-01 to 2023-09-30.csv');

    %Oktoobri andmeperioodid
    struct('start', datetime(2023,10,9), 'end', datetime(2023,10,15,23,0,0), 'weatherFile', 'Tallinn 2023-10-01 to 2023-10-31.csv');
    struct('start', datetime(2023,10,23), 'end', datetime(2023,10,29,23,0,0), 'weatherFile', 'Tallinn 2023-10-01 to 2023-10-31.csv');

    %Detsembri andmeperioodid
    struct('start', datetime(2023,12,4), 'end', datetime(2023,12,10,23,0,0), 'weatherFile', 'Tallinn 2023-12-01 to 2023-12-31.csv');
    struct('start', datetime(2023,12,11), 'end', datetime(2023,12,17,23,0,0), 'weatherFile', 'Tallinn 2023-12-01 to 2023-12-31.csv');
};

%initsialiseeritakse sisendi ja väljundi andmemasiivid
X = [];
Y = [];

 for i = 1:numel(weeks)
    s = weeks{i}.start;
    e = weeks{i}.end;
    weather = readtable(weeks{i}.weatherFile);
    weather.datetime = datetime(weather{:,1}, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
    weather.temp = str2double(strrep(string(weather.temp), ',', '.'));
 %Genereeritakse kõik tunnid nädala sees
    t_now = s:hours(1):e;
 %iga tunni kohta kontrollitakse, kas väärtused eksisteerivad
   for j = 1:length(t_now)
        time_now = t_now(j);
        row_now = outputAll.FullTime == time_now;
        i_now = inputAll.FullTime == time_now;
        temp_now = weather.temp(weather.datetime == time_now);
  % kui  kõik vajalikud väärtused eksisteerivad
        if any(row_now) && any(i_now) && ~isempty(temp_now)
            y_now = outputAll.S01(row_now);
            if ~isnan(y_now(1))
                   % ajapõhiste tunnuste loomine
                h = hour(time_now);
                m = month(time_now);
                wd = weekday(time_now);
                isWeekend = ismember(wd, [1,7]);
                %teisendatakse kellaaeg ja kuu  perioodilisteks tunnusteks
                hourSin = sin(2*pi*h/24);
                hourCos = cos(2*pi*h/24);
                monthSin = sin(2*pi*m/12);
                monthCos = cos(2*pi*m/12);
             % kolmest hoonest sisendväärtuste skaleerimine pindala  kaaudu
                soc = inputAll.SOC(i_now) * areaSOC;
                tim = inputAll.TIM(i_now) * areaTIM;
                d04 = inputAll.D04(i_now) * areaD04;
            % sisendmassivi koostamine (üks rida tunnuse kohta)
                X(end+1,:) = [soc(1), tim(1), d04(1), hourSin, hourCos, ...
                              monthSin, monthCos, double(isWeekend), temp_now(1)];
                % väljundina  kasutatakse absoluutset energiatarbimise väärtust
                Y(end+1,1) = y_now(1);
            end
        end
    end
end
% normaliseeritakse kõik tunnused vahemikku [-1, 1], v.a pindalad ja nädalavahetuse näitaja
Xnorm = X;
Xnorm(:,[1:3,4:5,6:7,9]) = normalize(X(:,[1:3,4:5,6:7,9]), 'range', [-1 1]);
 % luuakse närvivõrk kahe peidetud kihiga
net = feedforwardnet([6, 4]);
%kasutatakse Levenberg-Marquardti algoritmi õppimiseks
net.trainFcn = 'trainlm';
%kasutatakse kogu andmestikku  treenimiseks ( valideerimist ja ttestimist ei tehta)
net.divideParam.trainRatio = 1;
net.divideParam.valRatio = 0;
net.divideParam.testRatio = 0;
 %määratakse  treeningu parameetrid
net.trainParam.epochs = 10000;
net.trainParam.max_fail = 20;
[net, tr] = train(net, Xnorm', Y');

% võrgu väljundi arvutamine
Yhat = net(Xnorm');

% arvutatakse erinevus tegelike  ja ennustatud  väärtuste vahel
err = Y - Yhat';
%klassikalised mõõdikud mudeli täpsuse hindamiseks
MAE = mean(abs(err));               % keskmine absoluutne viga
RMSE = sqrt(mean(err.^2));                % keskmine ruutviga
R2 = 1 - sum(err.^2) / sum((Y - mean(Y)).^2);  % määramiskordaja
%täiendavad mõõdikud
mseError = mean(err.^2);
maeError = MAE;           % sama mis MAE
meanError = mean(err);    % keskmine prognoosiviga

%Ttäpsustulemuste kuvamine käsureal
fprintf('\nTäpsuse hinnangud (kWh):\n');
fprintf('MAE: %.2f kWh\n', MAE);
fprintf('RMSE: %.2f kWh\n', RMSE);
fprintf('R^2: %.4f\n', R2);
fprintf('\nTäpsuse laiendatud hinnangud:\n');
fprintf('MSE: %.4f | MAE:  %.4f | ME: %.4f |  R^2: %.4f\n', mseError, maeError, meanError, R2);
fprintf('Prognoositav tarbimine: %.2f … %.2f kWh\n', min(Yhat), max(Yhat));

%Salvestatakse treenitud mudel ja sisendite skaleerimisparameetrid
Xmin = min(X);
Xmax = max(X);
save('trainedModel_absolute.mat', 'net', 'Xmin', 'Xmax');

fprintf('Mudel salvestatud: trainedModel_absolute.mat\n');
