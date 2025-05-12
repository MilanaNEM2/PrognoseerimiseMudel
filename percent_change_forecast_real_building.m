% See skript treenib närvivõrgu mudeli reaalse hoonete energiatarbimise ennustamiseks
clc; clear;

% Hoone pindalade määramine ruutmeetrites
areaSOC = 10360; % SOC hoone pindala
areaTIM = 642.0; % TIM hoone pindala
areaD04 = 4323.6; % D04 hoone pindala

% Sisend- ja väljundandmete laadimine failidest
inputAll = readtable('Input_data_SOC_TIM_D04.csv', 'Delimiter', ';');
outputAll = readtable('Output_data_S01.csv', 'Delimiter', ';');

% teisendatakse stringidest arvudeks hoonete tarbimisväärtused
for col = {'SOC','TIM','D04'}
    inputAll.(col{1}) = str2double(strrep(string(inputAll.(col{1})), ',', '.'));
end
outputAll.S01 = str2double(strrep(string(outputAll.S01), ',', '.'));
%luuakse ajatemplid perioodide ja kellaaegade põhjal
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
%Andmete ühendamise ja  tunnuste kogumise  aalustamine
% valmistatakse sisend- ja  väljundmaatriksid
X = [];
Y = [];
% töödeldakse iga nädal  eraldi
for i = 1:numel(weeks)

   %Märatakse konkreetse nädala algusaeg ja lõppaeg
    s = weeks{i}.start;
    e = weeks{i}.end;
   %loetakse nädala vastav ilmatabel
    weather = readtable(weeks{i}.weatherFile);
   %teisendatakse ilmaandmete ajatemplid   datetime-kujulee
    weather.datetime = datetime(weather{:,1}, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
    % teisendatakse temperatuur arvuliseks väärtuseks
    weather.temp = str2double(strrep(string(weather.temp), ',', '.'));

    % luuakse ajavektorid praeguse ja eelmise nädala tundide kohta
    t_now = s:hours(1):e; % iga tunni ajatempel praegusel  nädalall
    t_prev = t_now - days(7);   % samade kellaaegade ajatemplid nädal varem

    % töödeldakse iga tunni kaupa
    for j = 1:length(t_now)
        time_now = t_now(j);% konkreetne kellaaeg  praegusel nädalal
        time_prev = t_prev(j); % vastav kellaaeg eelmisel nädalal
        % leitakse read,  mis vastavad praegusele  ja eelmisele ajale
        row_now = outputAll.FullTime == time_now ;
        row_prev = outputAll.FullTime == time_prev;
        %leitakse hetke - ja varasem temperatuur
        temp_now = weather.temp(weather.datetime == time_now);
        temp_prev = weather.temp(weather.datetime == time_prev);

        % kui mõlema nädala väärtused on olemas ja temperatuurid teada
        if any(row_now) && any(row_prev) && ~isempty(temp_now) && ~isempty(temp_prev)
            y_now = outputAll.S01(row_now);  % praeguse aja tegelik tarbimine
            y_prev = outputAll.S01(row_prev); % eelmise nädala sama aja tarbimine
            i_now = inputAll.FullTime == time_now;  % sisendandmete rida vastava ajaga

        % kui kõik  väärtused on olemas ja eelnev tarbimine on positiivne
            if any(i_now) && ~isnan(y_now(1)) && ~isnan(y_prev(1)) && y_prev(1) > 0

                % loetakse kellaaeg, kuu ja  nädalapäev
            h = hour(time_now);
                m = month(time_now);
                wd = weekday(time_now);

                % määratakse, kas on nädalavahetus (1=pühapäev, 7 =laupäev)
                isWeekend = ismember(wd, [1,7]);

                % teisendatakse kellaaeg ja kuu perioodilisteks tunnusteks
                hourSin = sin(2*pi*h/24);  % sinusoidaalne kellaaeg
                hourCos = cos(2*pi*h/24);  % koosinus kellaaeg
               monthSin = sin(2*pi*m/12) ;  % sinusoidaalne kuu
             monthCos = cos(2*pi*m/12);  % koosinus kuu

                % arvutatakse normaliseeritud energiatarbimine vastavalt pindalale
                soc = inputAll.SOC(i_now) * areaSOC;
                tim = inputAll.TIM(i_now) * areaTIM ;
                d04 = inputAll.D04(i_now) * areaD04;

                % lisatakse rida X-massiivi (sisendtunnused )
                X(end+1,:) = [soc(1), tim(1), d04(1), hourSin, hourCos, ...
                             monthSin, monthCos, double(isWeekend), ...
                              temp_now(1), temp_prev(1)];

               % lisatakse rida Y-vektorisse (sihtväärtus)- protsentuaalne muutus
                Y(end+1,1) = 100 * (y_now(1) - y_prev(1)) / y_prev(1);
            end
        end
    end
end
% normaliseeritakse  kõik sisendtunnused peale pindala ja  nädalavahetuse näitaja
Xnorm = X;
Xnorm(:,[1:3,4:5,6:7,9:10]) = normalize(X(:,[1:3,4:5,6:7,9:10]), 'range', [-1 1]);
% luuakse närvivõrk kahe peidetud  kihiga (6 ja  4 neuronit)
net = feedforwardnet([6, 4]);

% määr atakse õppemeetodiks Levenberg–Marquardt algoritm
net.trainFcn = 'trainlm';
 %kogu  andmestik kasutatakse ainult treeninguks, valideerimist ei toimu
net.divideParam.trainRatio = 1;
net.divideParam.valRatio = 0;
net.divideParam.testRatio = 0;
% määratakse  maksimaalne epohhide arv ja katkestamise tingimus
net.trainParam.epochs = 10000;
net.trainParam.max_fail = 20;
%Käivitatakse  võrgu treenimine  normaliseritud andmetega
[net, tr] = train(net, Xnorm', Y');

%arvutatakse võrgu väljundid
Yhat = net(Xnorm');
 %arvutatakse veavektor tegelike ja ennustatud väärtuste vahel
err = Y - Yhat';
% arvutatakse veamõõdikud
mseError = mean(err.^2);     % keskmine ruutviga
maeError = mean(abs(err)); % keskmine absoluutviga
meanError = mean(err);    % keskmine viga (kallutatus)
R2 = 1 - sum(err.^2) / sum((Y - mean(Y)).^2); %määramiskordaja

% kuvatakse tulemused käsureale
fprintf('\nTäpsuse hinnangud (%% muutus):\n');
fprintf('MSE: %.2f %%² | MAE: %.2f %% | ME: %.2f %% | R^2: %.4f\n', mseError, maeError, meanError, R2);
fprintf('Prognoositav muutus: %.2f %% … %.2f %%\n', min(Yhat), max(Yhat));
% salvestatakse treenitud  mudel
save('trainedModel_percentDelta.mat',  'net');
fprintf('Mudel salvestatud:  trainedModel_percentDelta.mat\n');
