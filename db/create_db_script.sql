DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

------------------------------
----Country
------------------------------
CREATE TABLE Country
(
    Country_id serial NOT NULL,
    Name VARCHAR(50) NOT NULL,
    Code CHAR(3) NOT NULL,
    UNIQUE (Name), 
    UNIQUE (Code),
    PRIMARY KEY (Country_id)
);
------------------------------
----
------------------------------

------------------------------
----Disease
------------------------------
CREATE TABLE Disease
(
    Disease_id serial NOT NULL,
    Name VARCHAR(50) NOT NULL,
    ICD_10_Code CHAR(5),
    SAR_estimation float CHECK,
    UNIQUE(Name),
    PRIMARY KEY(Disease_id)
);

CREATE OR REPLACE FUNCTION on_before_disease_changed() RETURNS trigger AS $on_before_disease_changed$
    BEGIN
        IF (TG_OP = 'DELETE') THEN
            RETURN OLD;
        END IF;

        IF NEW.ICD_10_Code != NULL 
            AND (SELECT * FROM Disease WHERE ICD_10_Code IS NOT NULL AND ICD_10_Code=NEW.ICD_10_Code) != NULL THEN
            RAISE EXCEPTION '% cannot have 2 diseases with the same code ', NEW.ICD_10_Code;
        END IF;

        RETURN NEW;
    END;
$on_before_disease_changed$ LANGUAGE plpgsql;
CREATE TRIGGER on_before_disease_changed BEFORE UPDATE ON Disease
    FOR EACH ROW EXECUTE PROCEDURE on_before_disease_changed();
------------------------------
----
------------------------------
------------------------------
----Comorbid_condition_CFR
------------------------------
CREATE TABLE Comorbid_condition_CFR
(
    Comorbid_condition_CFR_id serial NOT NULL,
    Disease_id integer NOT NULL,
    Comorbid_disease_id integer NOT NULL,
    CFR float NOT NULL CHECK(CFR > 0),
    CHECK(Disease_id != Comorbid_disease_id),
    UNIQUE(Disease_id, Comorbid_disease_id),
    FOREIGN KEY(Disease_id) REFERENCES Disease(Disease_id) ON DELETE RESTRICT,
    FOREIGN KEY(Comorbid_disease_id) REFERENCES Disease(Disease_id) ON DELETE RESTRICT,
    PRIMARY KEY(Comorbid_condition_CFR_id)
);
------------------------------
----
------------------------------
------------------------------
----Age_group_CFR
------------------------------
CREATE TABLE Age_group_CFR
(
    Age_group_CFR_id serial NOT NULL,
    Disease_id integer NOT NULL,
    Age_limit smallint NOT NULL,
    CFR float NOT NULL,
    UNIQUE(Disease_id, Age_limit),
    FOREIGN KEY(Disease_id) REFERENCES Disease(Disease_id) ON DELETE RESTRICT,
    PRIMARY KEY(Age_group_CFR_id)
);
------------------------------
----
------------------------------
------------------------------
----Population_stats
------------------------------
CREATE TABLE Population_stats
(
    Population_stats_id serial NOT NULL,
    Country_id integer NOT NULL,
    Year integer NOT NULL,
    Population bigint NOT NULL,
    UNIQUE(Country_id, Year),
    FOREIGN KEY(Country_id) REFERENCES Country ON DELETE RESTRICT,
    PRIMARY KEY(Population_stats_id)
);
------------------------------
----
------------------------------

------------------------------
----Disease_season
------------------------------
CREATE TABLE Disease_season
(
    Disease_season_id serial NOT NULL,
    Disease_id integer NOT NULL,
    Start_date DATE NOT NULL,
    End_date DATE,
    UNIQUE(Disease_id, Start_date),
    FOREIGN KEY(Disease_id) REFERENCES Disease ON DELETE RESTRICT,
    PRIMARY KEY(Disease_season_id)
);

CREATE OR REPLACE FUNCTION on_before_disease_season_changed() RETURNS trigger AS $on_before_disease_season_changed$
    DECLARE 
    season Disease_season%rowtype;
    BEGIN
        IF (TG_OP = 'DELETE') THEN
            RETURN OLD;
        END IF;

        IF NEW.End_date != NULL AND NEW.End_date < NEW.Start_date THEN
            RAISE EXCEPTION '% cannot have End date that is earlier than Start date', NEW.Disease_id;
        END IF;

        FOR season IN SELECT * FROM Disease_season WHERE Disease_id=NEW.Disease_id
        LOOP
            IF NEW.Start_date < season.Start_date AND (NEW.End_date = NULL OR NEW.End_date > season.Start_date) THEN
                RAISE EXCEPTION '% inconsistents dates, new is before old and interescts it', NEW.Disease_id;
            ELSIF NEW.Start_date > season.Start_date THEN
                IF season.End_date = NULL THEN
                    RAISE EXCEPTION '% inconsistents dates, new is after old and but old is not closed', NEW.Disease_id;
                ELSIF season.End_date > NEW.Start_date THEN
                    RAISE EXCEPTION '% inconsistents dates, new is after old and but intersects is', NEW.Disease_id;
                END IF;
            END IF; 
        END LOOP;

        RETURN NEW;
    END;
$on_before_disease_season_changed$ LANGUAGE plpgsql;
CREATE TRIGGER on_before_disease_season_changed BEFORE UPDATE ON Disease_season
    FOR EACH ROW EXECUTE PROCEDURE on_before_disease_season_changed();
------------------------------
----
------------------------------

------------------------------
----Disease_stats
------------------------------
CREATE TABLE Disease_stats
(
    Disease_stats_id bigserial NOT NULL,
    Disease_season_id integer NOT NULL,
    Stats_date DATE NOT NULL,
    Confirmed integer NOT NULL,
    Recovered integer NOT NULL,
    Deaths integer NOT NULL,
    UNIQUE(Disease_season_id, Stats_date),
    FOREIGN KEY(Disease_season_id) REFERENCES Disease_season ON DELETE RESTRICT,
    PRIMARY KEY(Disease_stats_id)
);
------------------------------
----
------------------------------
------------------------------
----Internals_data_handling
------------------------------
CREATE TABLE Internals_data_handling_task
(
    Internals_data_handling_task_id smallserial NOT NULL,
    Task_name VARCHAR(50) NOT NULL,
    Frequency_days integer NOT NULL,
    Last_update DATE,
    Enabled_flag boolean NOT NULL,
    Command_name VARCHAR(50) NOT NULL,
    UNIQUE(Task_name),
    PRIMARY KEY(Internals_data_handling_task_id)
);
------------------------------
----Contacts_estimation 
------------------------------
CREATE TABLE Contacts_estimation
(
    Age_limit smallint NOT NULL,
    Estimation smallint NOT NULL,
    PRIMARY KEY(Age_limit)
);
------------------------------------------------------
------------------------------
----Contacts_estimation insertions
------------------------------
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(5, 11);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(8, 13);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(16, 14);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(17, 20);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(19, 21);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(23, 22);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(46, 23);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(51, 22);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(60, 17);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(65, 15);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(70, 11);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(80, 10);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(90, 8);
INSERT INTO Contacts_estimation(Age_limit, Estimation) Values(120, 3);
------------------------------
----
------------------------------
------------------------------
----Country insertions
------------------------------
INSERT INTO Country(Name, Code) Values('Aruba',	'ABW');
INSERT INTO Country(Name, Code) Values('Afghanistan', 'AFG');
INSERT INTO Country(Name, Code) Values('Angola', 'AGO');
INSERT INTO Country(Name, Code) Values('Albania', 'ALB');
INSERT INTO Country(Name, Code) Values('Andorra', 'AND');
INSERT INTO Country(Name, Code) Values('United Arab Emirates', 'ARE');
INSERT INTO Country(Name, Code) Values('Argentina', 'ARG');
INSERT INTO Country(Name, Code) Values('Armenia', 'ARM');
INSERT INTO Country(Name, Code) Values('American Samoa', 'ASM');
INSERT INTO Country(Name, Code) Values('Antigua and Barbuda', 'ATG');
INSERT INTO Country(Name, Code) Values('Australia', 'AUS');
INSERT INTO Country(Name, Code) Values('Austria', 'AUT');
INSERT INTO Country(Name, Code) Values('Azerbaijan', 'AZE');
INSERT INTO Country(Name, Code) Values('Burundi', 'BDI');
INSERT INTO Country(Name, Code) Values('Belgium', 'BEL');
INSERT INTO Country(Name, Code) Values('Benin', 'BEN');
INSERT INTO Country(Name, Code) Values('Burkina Faso', 'BFA');
INSERT INTO Country(Name, Code) Values('Bangladesh', 'BGD');
INSERT INTO Country(Name, Code) Values('Bulgaria', 'BGR');
INSERT INTO Country(Name, Code) Values('Bahrain', 'BHR');
INSERT INTO Country(Name, Code) Values('Bahamas, The', 'BHS');
INSERT INTO Country(Name, Code) Values('Bosnia and Herzegovina', 'BIH');
INSERT INTO Country(Name, Code) Values('Belarus', 'BLR');
INSERT INTO Country(Name, Code) Values('Belize', 'BLZ');
INSERT INTO Country(Name, Code) Values('Bermuda', 'BMU');
INSERT INTO Country(Name, Code) Values('Bolivia', 'BOL');
INSERT INTO Country(Name, Code) Values('Brazil', 'BRA');
INSERT INTO Country(Name, Code) Values('Barbados', 'BRB');
INSERT INTO Country(Name, Code) Values('Brunei Darussalam', 'BRN');
INSERT INTO Country(Name, Code) Values('Bhutan', 'BTN');
INSERT INTO Country(Name, Code) Values('Botswana', 'BWA');
INSERT INTO Country(Name, Code) Values('Central African Republic', 'CAF');
INSERT INTO Country(Name, Code) Values('Canada', 'CAN');
INSERT INTO Country(Name, Code) Values('Switzerland', 'CHE');
INSERT INTO Country(Name, Code) Values('Channel Islands', 'CHI');
INSERT INTO Country(Name, Code) Values('Chile', 'CHL');
INSERT INTO Country(Name, Code) Values('China', 'CHN');
INSERT INTO Country(Name, Code) Values('Cote d''Ivoire', 'CIV');
INSERT INTO Country(Name, Code) Values('Cameroon', 'CMR');
INSERT INTO Country(Name, Code) Values('Congo, Dem. Rep.', 'COD');
INSERT INTO Country(Name, Code) Values('Congo, Rep.', 'COG');
INSERT INTO Country(Name, Code) Values('Colombia', 'COL');
INSERT INTO Country(Name, Code) Values('Comoros', 'COM');
INSERT INTO Country(Name, Code) Values('Cabo Verde', 'CPV');
INSERT INTO Country(Name, Code) Values('Costa Rica', 'CRI');
INSERT INTO Country(Name, Code) Values('Cuba', 'CUB');
INSERT INTO Country(Name, Code) Values('Curacao', 'CUW');
INSERT INTO Country(Name, Code) Values('Cayman Islands', 'CYM');
INSERT INTO Country(Name, Code) Values('Cyprus', 'CYP');
INSERT INTO Country(Name, Code) Values('Czech Republic', 'CZE');
INSERT INTO Country(Name, Code) Values('Germany', 'DEU');
INSERT INTO Country(Name, Code) Values('Djibouti', 'DJI');
INSERT INTO Country(Name, Code) Values('Dominica', 'DMA');
INSERT INTO Country(Name, Code) Values('Denmark', 'DNK');
INSERT INTO Country(Name, Code) Values('Dominican Republic', 'DOM');
INSERT INTO Country(Name, Code) Values('Algeria', 'DZA');
INSERT INTO Country(Name, Code) Values('Ecuador', 'ECU');
INSERT INTO Country(Name, Code) Values('Egypt, Arab Rep.', 'EGY');
INSERT INTO Country(Name, Code) Values('Eritrea', 'ERI');
INSERT INTO Country(Name, Code) Values('Spain', 'ESP');
INSERT INTO Country(Name, Code) Values('Estonia', 'EST');
INSERT INTO Country(Name, Code) Values('Ethiopia', 'ETH');
INSERT INTO Country(Name, Code) Values('Finland', 'FIN');
INSERT INTO Country(Name, Code) Values('Fiji', 'FJI');
INSERT INTO Country(Name, Code) Values('France', 'FRA');
INSERT INTO Country(Name, Code) Values('Faroe Islands', 'FRO');
INSERT INTO Country(Name, Code) Values('Micronesia, Fed. Sts.', 'FSM');
INSERT INTO Country(Name, Code) Values('Gabon', 'GAB');
INSERT INTO Country(Name, Code) Values('United Kingdom', 'GBR');
INSERT INTO Country(Name, Code) Values('Georgia', 'GEO');
INSERT INTO Country(Name, Code) Values('Ghana', 'GHA');
INSERT INTO Country(Name, Code) Values('Gibraltar', 'GIB');
INSERT INTO Country(Name, Code) Values('Guinea', 'GIN');
INSERT INTO Country(Name, Code) Values('Gambia, The', 'GMB');
INSERT INTO Country(Name, Code) Values('Guinea-Bissau', 'GNB');
INSERT INTO Country(Name, Code) Values('Equatorial Guinea', 'GNQ');
INSERT INTO Country(Name, Code) Values('Greece', 'GRC');
INSERT INTO Country(Name, Code) Values('Grenada', 'GRD');
INSERT INTO Country(Name, Code) Values('Greenland', 'GRL');
INSERT INTO Country(Name, Code) Values('Guatemala', 'GTM');
INSERT INTO Country(Name, Code) Values('Guam', 'GUM');
INSERT INTO Country(Name, Code) Values('Guyana', 'GUY');
INSERT INTO Country(Name, Code) Values('Hong Kong SAR, China', 'HKG');
INSERT INTO Country(Name, Code) Values('Honduras', 'HND');
INSERT INTO Country(Name, Code) Values('Croatia', 'HRV');
INSERT INTO Country(Name, Code) Values('Haiti', 'HTI');
INSERT INTO Country(Name, Code) Values('Hungary', 'HUN');
INSERT INTO Country(Name, Code) Values('Indonesia', 'IDN');
INSERT INTO Country(Name, Code) Values('India', 'IND');
INSERT INTO Country(Name, Code) Values('Ireland', 'IRL');
INSERT INTO Country(Name, Code) Values('Iran, Islamic Rep.', 'IRN');
INSERT INTO Country(Name, Code) Values('Iraq', 'IRQ');
INSERT INTO Country(Name, Code) Values('Iceland', 'ISL');
INSERT INTO Country(Name, Code) Values('Israel', 'ISR');
INSERT INTO Country(Name, Code) Values('Italy', 'ITA');
INSERT INTO Country(Name, Code) Values('Jamaica', 'JAM');
INSERT INTO Country(Name, Code) Values('Jordan', 'JOR');
INSERT INTO Country(Name, Code) Values('Japan', 'JPN');
INSERT INTO Country(Name, Code) Values('Kazakhstan', 'KAZ');
INSERT INTO Country(Name, Code) Values('Kenya', 'KEN');
INSERT INTO Country(Name, Code) Values('Kyrgyz Republic', 'KGZ');
INSERT INTO Country(Name, Code) Values('Cambodia', 'KHM');
INSERT INTO Country(Name, Code) Values('Kiribati', 'KIR');
INSERT INTO Country(Name, Code) Values('St. Kitts and Nevis', 'KNA');
INSERT INTO Country(Name, Code) Values('Korea, Rep.', 'KOR');
INSERT INTO Country(Name, Code) Values('Kuwait', 'KWT');
INSERT INTO Country(Name, Code) Values('Lao PDR', 'LAO');
INSERT INTO Country(Name, Code) Values('Lebanon', 'LBN');
INSERT INTO Country(Name, Code) Values('Liberia', 'LBR');
INSERT INTO Country(Name, Code) Values('Libya', 'LBY');
INSERT INTO Country(Name, Code) Values('St. Lucia', 'LCA');
INSERT INTO Country(Name, Code) Values('Liechtenstein', 'LIE');
INSERT INTO Country(Name, Code) Values('Sri Lanka', 'LKA');
INSERT INTO Country(Name, Code) Values('Lesotho', 'LSO');
INSERT INTO Country(Name, Code) Values('Lithuania', 'LTU');
INSERT INTO Country(Name, Code) Values('Luxembourg', 'LUX');
INSERT INTO Country(Name, Code) Values('Latvia', 'LVA');
INSERT INTO Country(Name, Code) Values('Macao SAR, China', 'MAC');
INSERT INTO Country(Name, Code) Values('St. Martin (French part)', 'MAF');
INSERT INTO Country(Name, Code) Values('Morocco', 'MAR');
INSERT INTO Country(Name, Code) Values('Monaco', 'MCO');
INSERT INTO Country(Name, Code) Values('Moldova', 'MDA');
INSERT INTO Country(Name, Code) Values('Madagascar', 'MDG');
INSERT INTO Country(Name, Code) Values('Maldives', 'MDV');
INSERT INTO Country(Name, Code) Values('Mexico', 'MEX');
INSERT INTO Country(Name, Code) Values('Marshall Islands', 'MHL');
INSERT INTO Country(Name, Code) Values('North Macedonia', 'MKD');
INSERT INTO Country(Name, Code) Values('Mali', 'MLI');
INSERT INTO Country(Name, Code) Values('Malta', 'MLT');
INSERT INTO Country(Name, Code) Values('Myanmar', 'MMR');
INSERT INTO Country(Name, Code) Values('Montenegro', 'MNE');
INSERT INTO Country(Name, Code) Values('Mongolia', 'MNG');
INSERT INTO Country(Name, Code) Values('Northern Mariana Islands', 'MNP');
INSERT INTO Country(Name, Code) Values('Mozambique', 'MOZ');
INSERT INTO Country(Name, Code) Values('Mauritania', 'MRT');
INSERT INTO Country(Name, Code) Values('Mauritius', 'MUS');
INSERT INTO Country(Name, Code) Values('Malawi', 'MWI');
INSERT INTO Country(Name, Code) Values('Malaysia', 'MYS');
INSERT INTO Country(Name, Code) Values('North America', 'NAC');
INSERT INTO Country(Name, Code) Values('Namibia', 'NAM');
INSERT INTO Country(Name, Code) Values('New Caledonia', 'NCL');
INSERT INTO Country(Name, Code) Values('Niger', 'NER');
INSERT INTO Country(Name, Code) Values('Nigeria', 'NGA');
INSERT INTO Country(Name, Code) Values('Nicaragua', 'NIC');
INSERT INTO Country(Name, Code) Values('Netherlands', 'NLD');
INSERT INTO Country(Name, Code) Values('Norway', 'NOR');
INSERT INTO Country(Name, Code) Values('Nepal', 'NPL');
INSERT INTO Country(Name, Code) Values('Nauru', 'NRU');
INSERT INTO Country(Name, Code) Values('New Zealand', 'NZL');
INSERT INTO Country(Name, Code) Values('Oman', 'OMN');
INSERT INTO Country(Name, Code) Values('Pakistan', 'PAK');
INSERT INTO Country(Name, Code) Values('Panama', 'PAN');
INSERT INTO Country(Name, Code) Values('Peru', 'PER');
INSERT INTO Country(Name, Code) Values('Philippines', 'PHL');
INSERT INTO Country(Name, Code) Values('Palau', 'PLW');
INSERT INTO Country(Name, Code) Values('Papua New Guinea', 'PNG');
INSERT INTO Country(Name, Code) Values('Poland', 'POL');
INSERT INTO Country(Name, Code) Values('Puerto Rico', 'PRI');
INSERT INTO Country(Name, Code) Values('Korea, Dem. People’s Rep.', 'PRK');
INSERT INTO Country(Name, Code) Values('Portugal', 'PRT');
INSERT INTO Country(Name, Code) Values('Paraguay', 'PRY');
INSERT INTO Country(Name, Code) Values('West Bank and Gaza', 'PSE');
INSERT INTO Country(Name, Code) Values('French Polynesia', 'PYF');
INSERT INTO Country(Name, Code) Values('Qatar', 'QAT');
INSERT INTO Country(Name, Code) Values('Romania', 'ROU');
INSERT INTO Country(Name, Code) Values('Russian Federation', 'RUS');
INSERT INTO Country(Name, Code) Values('Rwanda', 'RWA');
INSERT INTO Country(Name, Code) Values('Saudi Arabia', 'SAU');
INSERT INTO Country(Name, Code) Values('Sudan', 'SDN');
INSERT INTO Country(Name, Code) Values('Senegal', 'SEN');
INSERT INTO Country(Name, Code) Values('Singapore', 'SGP');
INSERT INTO Country(Name, Code) Values('Solomon Islands', 'SLB');
INSERT INTO Country(Name, Code) Values('Sierra Leone', 'SLE');
INSERT INTO Country(Name, Code) Values('El Salvador', 'SLV');
INSERT INTO Country(Name, Code) Values('San Marino', 'SMR');
INSERT INTO Country(Name, Code) Values('Somalia', 'SOM');
INSERT INTO Country(Name, Code) Values('Serbia', 'SRB');
INSERT INTO Country(Name, Code) Values('South Sudan', 'SSD');
INSERT INTO Country(Name, Code) Values('Suriname', 'SUR');
INSERT INTO Country(Name, Code) Values('Slovak Republic', 'SVK');
INSERT INTO Country(Name, Code) Values('Slovenia', 'SVN');
INSERT INTO Country(Name, Code) Values('Sweden', 'SWE');
INSERT INTO Country(Name, Code) Values('Eswatini', 'SWZ');
INSERT INTO Country(Name, Code) Values('Sint Maarten (Dutch part)', 'SXM');
INSERT INTO Country(Name, Code) Values('Seychelles', 'SYC');
INSERT INTO Country(Name, Code) Values('Syrian Arab Republic', 'SYR');
INSERT INTO Country(Name, Code) Values('Chad', 'TCD');
INSERT INTO Country(Name, Code) Values('Togo', 'TGO');
INSERT INTO Country(Name, Code) Values('Thailand', 'THA');
INSERT INTO Country(Name, Code) Values('Tajikistan', 'TJK');
INSERT INTO Country(Name, Code) Values('Turkmenistan', 'TKM');
INSERT INTO Country(Name, Code) Values('Timor-Leste', 'TLS');
INSERT INTO Country(Name, Code) Values('Tonga', 'TON');
INSERT INTO Country(Name, Code) Values('Trinidad and Tobago', 'TTO');
INSERT INTO Country(Name, Code) Values('Tunisia', 'TUN');
INSERT INTO Country(Name, Code) Values('Turkey', 'TUR');
INSERT INTO Country(Name, Code) Values('Tuvalu', 'TUV');
INSERT INTO Country(Name, Code) Values('Tanzania', 'TZA');
INSERT INTO Country(Name, Code) Values('Uganda', 'UGA');
INSERT INTO Country(Name, Code) Values('Ukraine', 'UKR');
INSERT INTO Country(Name, Code) Values('Uruguay', 'URY');
INSERT INTO Country(Name, Code) Values('United States', 'USA');
INSERT INTO Country(Name, Code) Values('Uzbekistan', 'UZB');
INSERT INTO Country(Name, Code) Values('St. Vincent and the Grenadines', 'VCT');
INSERT INTO Country(Name, Code) Values('Venezuela, RB', 'VEN');
INSERT INTO Country(Name, Code) Values('British Virgin Islands', 'VGB');
INSERT INTO Country(Name, Code) Values('Virgin Islands (U.S.)', 'VIR');
INSERT INTO Country(Name, Code) Values('Vietnam', 'VNM');
INSERT INTO Country(Name, Code) Values('Vanuatu', 'VUT');
INSERT INTO Country(Name, Code) Values('Samoa', 'WSM');
INSERT INTO Country(Name, Code) Values('Kosovo', 'XKX');
INSERT INTO Country(Name, Code) Values('Yemen, Rep.', 'YEM');
INSERT INTO Country(Name, Code) Values('South Africa', 'ZAF');
INSERT INTO Country(Name, Code) Values('Zambia', 'ZMB');
INSERT INTO Country(Name, Code) Values('Zimbabwe', 'ZWE');
------------------------------
----
------------------------------
------------------------------
----Disease insertions
------------------------------
INSERT INTO Disease(Name, ICD_10_Code, SAR_estimation) Values('COVID-19','U07.1',9.6);--, 3.4);
INSERT INTO Disease(Name) Values('Cardiovascular disease');
INSERT INTO Disease(Name) Values('Diabetes');
INSERT INTO Disease(Name) Values('Chronic respiratory disease');
INSERT INTO Disease(Name) Values('Hypertension');
INSERT INTO Disease(Name) Values('Cancer');
------------------------------
----
------------------------------
------------------------------
----Comorbid_condition_CFR insertions
------------------------------
INSERT INTO Comorbid_condition_CFR(Disease_id, Comorbid_disease_id, CFR)
VALUES(1,2, 10.5);
INSERT INTO Comorbid_condition_CFR(Disease_id, Comorbid_disease_id, CFR)
VALUES(1,3, 7.3);
INSERT INTO Comorbid_condition_CFR(Disease_id, Comorbid_disease_id, CFR)
VALUES(1,4, 6.3);
INSERT INTO Comorbid_condition_CFR(Disease_id, Comorbid_disease_id, CFR)
VALUES(1,5, 6.0);
INSERT INTO Comorbid_condition_CFR(Disease_id, Comorbid_disease_id, CFR)
VALUES(1,6, 5.6);
------------------------------
----
------------------------------
------------------------------
----Age_group_CFR insertions
------------------------------
INSERT INTO Age_group_CFR(Disease_id, Age_limit, CFR) VALUES(1, 9, 0);
INSERT INTO Age_group_CFR(Disease_id, Age_limit, CFR) VALUES(1, 19, 0.18);
INSERT INTO Age_group_CFR(Disease_id, Age_limit, CFR) VALUES(1, 49, 0.32);
INSERT INTO Age_group_CFR(Disease_id, Age_limit, CFR) VALUES(1, 59, 1.3);
INSERT INTO Age_group_CFR(Disease_id, Age_limit, CFR) VALUES(1, 69, 3.6);
INSERT INTO Age_group_CFR(Disease_id, Age_limit, CFR) VALUES(1, 79, 8.0);
INSERT INTO Age_group_CFR(Disease_id, Age_limit, CFR) VALUES(1, 120, 14.8);
------------------------------
----
------------------------------
------------------------------
----Disease_season insertions
------------------------------
INSERT INTO Disease_season(Disease_id, Start_date) VALUES(1, '11-17-2019');
------------------------------
---- 
------------------------------
------------------------------
----Internals_data_handling_task insertions
------------------------------
CREATE TABLE Internals_data_handling_task
(
    Internals_data_handling_task_id smallserial NOT NULL,
    Task_name VARCHAR(50) NOT NULL,
    Frequency_days integer NOT NULL,
    Last_update DATE,
    Enabled_flag boolean NOT NULL,
    Command_name VARCHAR(50) NOT NULL,
    UNIQUE(Task_name),
    PRIMARY KEY(Internals_data_handling_task_id)
);

INSERT INTO Internals_data_handling_task(Task_name, Frequency_days, Enabled_flag, Command_name)
VALUES('Update population stats', 100, 'TRUE', 'update_population_stats');
------------------------------
---- 
------------------------------