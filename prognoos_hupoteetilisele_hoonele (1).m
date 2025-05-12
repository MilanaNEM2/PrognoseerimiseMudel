clc; clear;
%Määratakse hüpoteetilise  hoone pindala ruutmeetrites (kasutatakse ainult TIM positsioonis)
newArea = 1156.5;
 % laaditakse treenitud mudel ja vastavad sisendite min/max väärtused normaliseerimiseks
load('trainedModel_absolute.mat', 'net', 'Xmin', 'Xmax');

%Määratakse analüüsitavad hooajad ja  nendele vastavad ilmafailid
seasons = {
    'Talv',  datetime(2023,12,3), datetime(2023,12,9,23,0,0), 'Tallinn 2023-12-01 to 2023-12-31.csv';
    'Kevad', datetime(2023,3,19), datetime(2023,3,25,23,0,0), 'Tallinn 2023-03-01 to 2023-04-30.csv';
    'Suvi',  datetime(2023,7,23), datetime(2023,7,29,23,0,0), 'Tallinn 2023-07-01 to 2023-08-31.csv';
    'Sügis', datetime(2023,10,22), datetime(2023,10,28,23,0,0), 'Tallinn 2023-10-01 to 2023-10-31.csv';
};


% luuakse graafikuaken
figure;
for i = 1:size(seasons,1)
    % määratakse hooaja nimi ja Vastav ajavahemik ning failinimi
    season = seasons{i,1};
    startDate = seasons{i,2};
    endDate   = seasons{i,3};
    fileName  = seasons{i,4};
    % Kontrollitakse, kas ilmafail eksisteerib
    if ~isfile(fileName)
        error('Ilmafaili ei leitud: %s', fileName);
    end
    % loetakse ilmaandmed ja teisendatakse ajatemplid
    weather = readtable(fileName);
    weather.datetime = datetime(weather{:,1}, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
    weather.FullTime = weather.datetime;
     % filtreeritakse ainult valitud hooaja andmed
    weatherWeek = weather(weather.FullTime >= startDate & weather.FullTime <= endDate, :);
    n = height(weatherWeek);
    % kui valitud nädalal andmed puuduvad,liigutakse edasi
    if n == 0
        warning('Andmed puuduvad hooajaks %s (%s)', season, fileName);
        continue;
    end
     %Initsialiseeritakse  vektor prognoositavate väärtuste  salvestamiseks
    predicted = zeros(n,1);
    % iga tunni kohta arvutatakse  sisend tunnused ja prognoositakse tarbimine
    for j = 1:n
        time_now = weatherWeek.FullTime(j);

        % ekstraheeritakse ajapõhised tunnused
        h = hour(time_now);
        m = month(time_now);
        wd = weekday(time_now);
        isWeekend = ismember(wd, [1,7]);

         %teisendatakse tunnus sinusoidvormi,et säilitada perioodilisus
        hourSin = sin(2*pi*h/24);
        hourCos = cos(2*pi*h/24);
        monthSin = sin(2*pi*m/12);
        monthCos = cos(2*pi*m/12);

        % loetakse antud hetke temperatuur
        temp_now = weatherWeek.temp(j);
        if isnan(temp_now)
            predicted(j) = NaN;
            continue;
        end

           %määratakse ainult  TIM positsiooni väärtus (hüpoteetilise hoone pindala)
        soc = 0;
        tim = newArea; %hüpoteetilise hoone pindala=tim pindala
        d04 = 0;
        %Koostatakse sisendvektor ühe tunni kohta
        X = [soc, tim, d04, hourSin, hourCos, ...
             monthSin, monthCos, double(isWeekend), temp_now];
        % normaliseeritakse sisendandmed eelnevalt salvestatud Xmin/Xmax alusel
        Xnorm = 2 * (X - Xmin) ./ (Xmax - Xmin) - 1;
         %Võrgu väljundi arvutamine (ennustatud tarbimine kWh-des)
        y_pred = net(Xnorm');

        %salvestatakse prognositud  väärtus
        predicted(j) = y_pred;
    end

    % joonistatakse hooaja  tarbimisprognoosi graafik
    subplot(2,2,i);
    plot(predicted, 'b', 'LineWidth', 1.5);
    title([season ' (pindala: ' num2str(newArea) ' m²)']);
    xlabel('Tund');
    ylabel('Prognoos (kWh)');
    grid on;
end
%Lisatakse kõigile graafikutele ühine pealkiri
sgtitle('Prognoos hüpoteetilisele hoonele neljal aastaajal (mudel: absoluutväärtus)');
