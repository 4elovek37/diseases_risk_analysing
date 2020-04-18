DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

------------------------------
----Country
------------------------------
CREATE TABLE Country
(
    Country_id smallserial NOT NULL,
    Name VARCHAR(50) NOT NULL,
    ISO_A_3_CODE CHAR(3) NOT NULL,
    ISO_A_2_CODE CHAR(2) NOT NULL,
    UNIQUE(Name), 
    UNIQUE(ISO_A_3_CODE),
    UNIQUE(ISO_A_2_CODE),
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
    Country_id smallint NOT NULL,
    Year integer NOT NULL,
    Population bigint NOT NULL CHECK(Population > 0),
    UNIQUE(Country_id, Year),
    FOREIGN KEY(Country_id) REFERENCES Country ON DELETE RESTRICT,
    PRIMARY KEY(Population_stats_id)
);
------------------------------
----
------------------------------
------------------------------
----Bed_stats
------------------------------
CREATE TABLE Bed_stats
(
    Bed_stats_id serial NOT NULL,
    Country_id smallint NOT NULL,
    Year integer NOT NULL,
    Beds_per_k float NOT NULL CHECK(Beds_per_k > 0),
    UNIQUE(Country_id, Year),
    FOREIGN KEY(Country_id) REFERENCES Country ON DELETE RESTRICT,
    PRIMARY KEY(Bed_stats_id)
);
------------------------------
----
------------------------------
------------------------------
----Nurse_stats
------------------------------
CREATE TABLE Nurse_stats
(
    Nurse_stats_id serial NOT NULL,
    Country_id smallint NOT NULL,
    Year integer NOT NULL,
    Nurses_per_k float NOT NULL CHECK(Nurses_per_k > 0),
    UNIQUE(Country_id, Year),
    FOREIGN KEY(Country_id) REFERENCES Country ON DELETE RESTRICT,
    PRIMARY KEY(Nurse_stats_id)
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
    Country_id smallint NOT NULL,
    Stats_date DATE NOT NULL,
    Confirmed integer NOT NULL,
    Recovered integer,
    Deaths integer NOT NULL,
    UNIQUE(Disease_season_id, Country_id, Stats_date),
    FOREIGN KEY(Disease_season_id) REFERENCES Disease_season ON DELETE RESTRICT,
    FOREIGN KEY(Country_id) REFERENCES Country ON DELETE RESTRICT,
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
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Aruba',	'ABW', 'AW');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Afghanistan', 'AFG', 'AF');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Angola', 'AGO', 'AO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Albania', 'ALB', 'AL');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Andorra', 'AND', 'AD');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('United Arab Emirates', 'ARE', 'AE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Argentina', 'ARG', 'AR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Armenia', 'ARM', 'AM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('American Samoa', 'ASM', 'AS');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Antigua and Barbuda', 'ATG', 'AG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Australia', 'AUS', 'AU');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Austria', 'AUT', 'AT');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Azerbaijan', 'AZE', 'AZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Burundi', 'BDI', 'BI');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Belgium', 'BEL', 'BE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Benin', 'BEN', 'BJ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Burkina Faso', 'BFA', 'BF');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Bangladesh', 'BGD', 'BD');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Bulgaria', 'BGR', 'BG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Bahrain', 'BHR', 'BH');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Bahamas, The', 'BHS', 'BS');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Bosnia and Herzegovina', 'BIH', 'BA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Belarus', 'BLR', 'BY');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Belize', 'BLZ', 'BZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Bermuda', 'BMU', 'BM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Bolivia', 'BOL', 'BO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Brazil', 'BRA', 'BR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Barbados', 'BRB', 'BB');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Brunei Darussalam', 'BRN', 'BN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Bhutan', 'BTN', 'BT');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Botswana', 'BWA', 'BW');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Central African Republic', 'CAF', 'CF');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Canada', 'CAN', 'CA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Switzerland', 'CHE', 'CH');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Chile', 'CHL', 'CL');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('China', 'CHN', 'CN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Cote d''Ivoire', 'CIV', 'CI');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Cameroon', 'CMR', 'CM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Congo, Dem. Rep.', 'COD', 'CD');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Congo, Rep.', 'COG', 'CG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Colombia', 'COL', 'CO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Comoros', 'COM', 'KM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Cabo Verde', 'CPV', 'CV');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Costa Rica', 'CRI', 'CR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Cuba', 'CUB', 'CU');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Cayman Islands', 'CYM', 'KY');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Cyprus', 'CYP', 'CY');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Czech Republic', 'CZE', 'CZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Germany', 'DEU', 'DE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Djibouti', 'DJI', 'DJ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Dominica', 'DMA', 'DM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Denmark', 'DNK', '');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Dominican Republic', 'DOM', 'DK');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Algeria', 'DZA', 'DZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Ecuador', 'ECU', 'EC');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Egypt, Arab Rep.', 'EGY', 'EG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Eritrea', 'ERI', 'ER');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Spain', 'ESP', 'ES');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Estonia', 'EST', 'EE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Ethiopia', 'ETH', 'ET');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Finland', 'FIN', 'FI');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Fiji', 'FJI', 'FJ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('France', 'FRA', 'FR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Faroe Islands', 'FRO', 'FO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Micronesia, Fed. Sts.', 'FSM', 'FM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Gabon', 'GAB', 'GA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('United Kingdom', 'GBR', 'GB');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Georgia', 'GEO', 'GE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Ghana', 'GHA', 'GH');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Gibraltar', 'GIB', 'GI');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Guinea', 'GIN', 'GN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Gambia, The', 'GMB', 'GM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Guinea-Bissau', 'GNB', 'GW');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Equatorial Guinea', 'GNQ', 'GQ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Greece', 'GRC', 'GR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Grenada', 'GRD', 'GD');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Greenland', 'GRL', 'GL');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Guatemala', 'GTM', 'GT');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Guam', 'GUM', 'GU');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Guyana', 'GUY', 'GY');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Hong Kong SAR, China', 'HKG', 'HK');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Honduras', 'HND', 'HN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Croatia', 'HRV', 'HR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Haiti', 'HTI', 'HT');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Hungary', 'HUN', 'HU');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Indonesia', 'IDN', 'ID');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('India', 'IND', 'IN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Ireland', 'IRL', 'IE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Iran, Islamic Rep.', 'IRN', 'IR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Iraq', 'IRQ', 'IQ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Iceland', 'ISL', 'IS');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Israel', 'ISR', 'IL');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Italy', 'ITA', 'IT');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Jamaica', 'JAM', 'JM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Jordan', 'JOR', 'JO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Japan', 'JPN', 'JP');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Kazakhstan', 'KAZ', 'KZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Kenya', 'KEN', 'KE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Kyrgyz Republic', 'KGZ', 'KG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Cambodia', 'KHM', 'KH');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Kiribati', 'KIR', 'KI');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('St. Kitts and Nevis', 'KNA', 'KN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Korea, Rep.', 'KOR', 'KR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Kuwait', 'KWT', 'KW');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Lao PDR', 'LAO', 'LA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Lebanon', 'LBN', 'LB');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Liberia', 'LBR', 'LR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Libya', 'LBY', 'LY');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('St. Lucia', 'LCA', 'LC');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Liechtenstein', 'LIE', 'LI');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Sri Lanka', 'LKA', 'LK');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Lesotho', 'LSO', 'LS');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Lithuania', 'LTU', 'LT');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Luxembourg', 'LUX', 'LU');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Latvia', 'LVA', 'LV');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Macao SAR, China', 'MAC', 'MO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('St. Martin (French part)', 'MAF', 'MF');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Morocco', 'MAR', 'MA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Monaco', 'MCO', 'MC');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Moldova', 'MDA', 'MD');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Madagascar', 'MDG', 'MG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Maldives', 'MDV', 'MV');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Mexico', 'MEX', 'MX');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Marshall Islands', 'MHL', 'MH');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('North Macedonia', 'MKD', 'MK');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Mali', 'MLI', 'ML');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Malta', 'MLT', 'MT');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Myanmar', 'MMR', 'MM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Montenegro', 'MNE', 'ME');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Mongolia', 'MNG', 'MN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Northern Mariana Islands', 'MNP', 'MP');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Mozambique', 'MOZ', 'MZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Mauritania', 'MRT', 'MR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Mauritius', 'MUS', 'MU');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Malawi', 'MWI', 'MW');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Malaysia', 'MYS', 'MY');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Namibia', 'NAM', 'NA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('New Caledonia', 'NCL', 'NC');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Niger', 'NER', 'NE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Nigeria', 'NGA', 'NG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Nicaragua', 'NIC', 'NI');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Netherlands', 'NLD', 'NL');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Norway', 'NOR', 'NO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Nepal', 'NPL', 'NP');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Nauru', 'NRU', 'NR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('New Zealand', 'NZL', 'NZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Oman', 'OMN', 'OM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Pakistan', 'PAK', 'PK');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Panama', 'PAN', 'PA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Peru', 'PER', 'PE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Philippines', 'PHL', 'PH');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Palau', 'PLW', 'PW');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Papua New Guinea', 'PNG', 'PG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Poland', 'POL', 'PL');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Puerto Rico', 'PRI', 'PR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Korea, Dem. People’s Rep.', 'PRK', 'KP');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Portugal', 'PRT', 'PT');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Paraguay', 'PRY', 'PY');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('West Bank and Gaza', 'PSE', 'PS');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('French Polynesia', 'PYF', 'PF');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Qatar', 'QAT', 'QA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Romania', 'ROU', 'RO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Russian Federation', 'RUS', 'RU');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Rwanda', 'RWA', 'RW');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Saudi Arabia', 'SAU', 'SA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Sudan', 'SDN', 'SD');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Senegal', 'SEN', 'SN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Singapore', 'SGP', 'SG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Solomon Islands', 'SLB', 'SB');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Sierra Leone', 'SLE', 'SL');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('El Salvador', 'SLV', 'SV');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('San Marino', 'SMR', 'SM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Somalia', 'SOM', 'SO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Serbia', 'SRB', 'RS');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('South Sudan', 'SSD', 'SS');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Suriname', 'SUR', 'SR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Slovak Republic', 'SVK', 'SK');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Slovenia', 'SVN', 'SI');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Sweden', 'SWE', 'SE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Eswatini', 'SWZ', 'SZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Seychelles', 'SYC', 'SC');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Syrian Arab Republic', 'SYR', 'SY');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Chad', 'TCD', 'TD');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Togo', 'TGO', 'TG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Thailand', 'THA', 'TH');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Tajikistan', 'TJK', 'TJ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Turkmenistan', 'TKM', 'TM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Timor-Leste', 'TLS', 'TL');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Tonga', 'TON', 'TO');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Trinidad and Tobago', 'TTO', 'TT');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Tunisia', 'TUN', 'TN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Turkey', 'TUR', 'TR');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Tuvalu', 'TUV', 'TV');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Tanzania', 'TZA', 'TZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Uganda', 'UGA', 'UG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Ukraine', 'UKR', 'UA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Uruguay', 'URY', 'UY');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('United States', 'USA', 'US');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Uzbekistan', 'UZB', 'UZ');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('St. Vincent and the Grenadines', 'VCT', 'VC');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Venezuela, RB', 'VEN', 'VE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('British Virgin Islands', 'VGB', 'VG');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Virgin Islands (U.S.)', 'VIR', 'VI');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Vietnam', 'VNM', 'VN');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Vanuatu', 'VUT', 'VU');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Samoa', 'WSM', 'WS');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Yemen, Rep.', 'YEM', 'YE');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('South Africa', 'ZAF', 'ZA');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Zambia', 'ZMB', 'ZM');
INSERT INTO Country(Name, ISO_A_3_CODE, ISO_A_2_CODE) Values('Zimbabwe', 'ZWE', 'ZW');
------------------------------
----
------------------------------
------------------------------
----Disease insertions
------------------------------
INSERT INTO Disease(Name, ICD_10_CODE, SAR_estimation) Values('COVID-19','U07.1',9.6);--, 3.4);
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
INSERT INTO Internals_data_handling_task(Task_name, Frequency_days, Enabled_flag, Command_name)
VALUES('Update population stats', 100, 'TRUE', 'update_population_stats');
INSERT INTO Internals_data_handling_task(Task_name, Frequency_days, Enabled_flag, Command_name)
VALUES('Update hospital beds stats', 100, 'TRUE', 'update_bed_stats');
INSERT INTO Internals_data_handling_task(Task_name, Frequency_days, Enabled_flag, Command_name)
VALUES('Update hospital nurses stats', 100, 'TRUE', 'update_nurse_stats');
INSERT INTO Internals_data_handling_task(Task_name, Frequency_days, Enabled_flag, Command_name)
VALUES('Update COVID-19 daily stats', 1, 'TRUE', 'update_covid_19_stats');
------------------------------
---- 
------------------------------