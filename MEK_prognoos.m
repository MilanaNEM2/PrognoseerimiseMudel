clc; clear;
% laaditakse varem treenitud mudel, mis ennustab protsentuaalset muutust
load('trainedModel_percentDelta.mat', 'net');

%loetakse MEK hoone  tegelik tarbimisandmete tabel
mek = readtable('Data_MEK.csv', 'Delimiter', ';');
mek.Timestamp = datetime(mek.Timestamp, 'InputFormat', 'dd.MM.yyyy HH:mm');
mek.MEK = str2double(strrep(string(mek.MEK), ',', '.'));
% määratakse testimiseks  kasutatavad aastaajad ja  vastavad ilmastikuandmed
seasons = {
    'Talv',  datetime(2023,12,4),  datetime(2023,12,16,23,0,0), 'Tallinn 2023-12-01 to 2023-12-31.csv';
    'Kevad', datetime(2023,3,13),  datetime(2023,3,19,23,0,0),  'Tallinn 2023-03-01 to 2023-04-30.csv';
    'Suvi',  datetime(2023,7,30),  datetime(2023,8,5,23,0,0),   'Tallinn 2023-07-01 to 2023-08-31.csv';
    'Sügis', datetime(2023,10,23), datetime(2023,10,29,23,0,0), 'Tallinn 2023-10-01 to 2023-10-31.csv';
};
% alustatakse jooniste loomist kõigi nelja hooaja jaoks
figure;
for i = 1:size(seasons,1)
      % määratakse hooaja nimi, algus- ja lõppkuupäev ning ilmafail
    seasonName = seasons{i,1};
    startDate  = seasons{i,2};
    endDate    = seasons{i,3};
    weatherFile = seasons{i,4};
 % loetakse vastava nädala ilmaandmed
    weather = readtable(weatherFile);
    weather.datetime = datetime(weather{:,1}, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
    weather.temp = str2double(strrep(string(weather.temp), ',', '.'));
    % luuakse ajatemplid valitud nädala ja eelnenud nädalate jaoks
    t_now = startDate:hours(1):endDate;
    t_prev = t_now - days(7);

    predicted = [];% prognoositud väärtused
    actual = []; % tegelikud mõõdetud  väärtused
   % tsükkel kõikide tundide läbimiseks
    for j = 1:length(t_now)
        time_now = t_now(j);
        time_prev = t_prev(j);
    %välistatakse nädalavahetused
        if ismember(weekday(time_now), [1, 7]) 
            continue;
        end
    %Leitakse ridade  indeksid MEK tabelist ja  ilmaandmetest
        row_now = mek.Timestamp == time_now;
        row_prev = mek.Timestamp == time_prev;
        temp_now = weather.temp(weather.datetime == time_now);
        temp_prev = weather.temp(weather.datetime == time_prev);
    % kontrollitakse,  kas kõik vajalikud aandmed on olemas
        if any(row_now) && any(row_prev) && ~isempty(temp_now) && ~isempty(temp_prev)
            y_now = mek.MEK(row_now);
            y_prev = mek.MEK(row_prev);
         % kui väärtused on tõesed ja eelmise nädala väärtus> 0
            if ~isnan(y_now(1)) && ~isnan(y_prev(1)) && y_prev(1) > 0
                 % ajast sõltuvate tunnuste arvutamine
                h = hour(time_now);
                m = month(time_now);
                wd = weekday(time_now);%kasutame hiljem ka kui tunnus
               %sinusoidid kellaajast ja kuust
                hourSin = sin(2*pi*h/24);
                hourCos = cos(2*pi*h/24);
                monthSin = sin(2*pi*m/12);
                monthCos = cos(2*pi*m/12);
        %Määratakse ainult TIM pindala, kuna see on MEK-sarnane
                soc = 0; tim = 4434; d04 = 0; % TIM - see on MEK pindala
                % koostatakse sisendvektor X
                X = [soc, tim, d04, hourSin, hourCos, monthSin, monthCos, wd, temp_now(1), temp_prev(1)];
                X([1:3,4:5,6:7,9:10]) = normalize(X([1:3,4:5,6:7,9:10]), 'range', [-1 1]); %normaliseeritakse kõik tunnused peale nädalapäeva (wd on kategooriline)

                try
                    %Võrgu ennustus (protsentuaalne muutus)
                    delta_pct = net(X');
                      %prognositakse tegelik tarbimine
                    y_pred = y_prev(1) * (1 + delta_pct / 100);
                     %salvestatakse tulemused
                    predicted(end+1) = y_pred;
                    actual(end+1) = y_now(1);
                catch
                    %kui ennustamine  ebaõnnestub, jätkatakse järgmisetsükliga
                    continue;
                end
            end
        end
    end

    %  joonistatakse graafik  ühe hooaja kohta
    subplot(2,2,i);
    plot(actual, 'k', 'LineWidth', 1.5); hold on;
    plot(predicted, 'b', 'LineWidth', 1.5);
    title([seasonName ' – MEK']);
    xlabel('Tund'); ylabel('Tarbimine (kWh)');
    legend('Tegelik', 'Prognoos');
    grid on;

    % arvutatakse vea mõõdikud
    err = actual - predicted;
    mae = mean(abs(err));               % keskmine  absoluutviga
    rmse = sqrt(mean(err.^2));              % keskmine ruutviga
    r2 = 1 - sum(err.^2) / sum((actual - mean(actual)).^2); % määramiskordaja

    % trükitakse tulemused  käsureale
   fprintf('\n[%s] täpsuse hinnangud:\n', seasonName);
  fprintf('MAE: %.2f kWh | RMSE: %.2f kWh | R^2 : %.4f\n', mae, rmse, r2);
end

%Lisatakse ühine pealkiri kõigile alamjoonistele
sgtitle('MEK – prognoositud vs tegelik tarbimine ( ilma nädalavahetusteta)');