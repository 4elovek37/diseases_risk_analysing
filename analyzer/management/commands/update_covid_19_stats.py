from django.core.management.base import BaseCommand, CommandError
from analyzer.models import Country, Disease, DiseaseSeason, DiseaseStats
import wget
import os
import json
import gzip
import shutil
from datetime import date


class CountryDailyStats:
    def __init__(self, date_iso):
        self.date = date.fromisoformat(date_iso)
        self.confirmed = 0
        self.deaths = 0
        self.recovered = None


class CountryStatsFromJson:
    def __init__(self,):
        self.countries_dict = dict()


class Command(BaseCommand):
    help = 'Initiates updating of covid_19 stats in Disease_stats table'
    #https://github.com/cipriancraciun/covid19-datasets

    def __init__(self):
        BaseCommand.__init__(self)
        #'https://raw.githubusercontent.com/cipriancraciun/covid19-datasets/master/exports/jhu/v1/values.json'
        self.url = 'https://github.com/cipriancraciun/covid19-datasets/raw/master/exports/jhu/v1/daily/values.json.gz'
        self.zip_path = './analyzer/management/commands/update_covid_19_stats/dataset.gz'
        self.json_path = './analyzer/management/commands/update_covid_19_stats/dataset.json'

    def handle(self, *args, **options):
        try:
            directory = os.path.dirname(self.json_path)
            if not os.path.exists(directory):
                os.makedirs(directory)

            wget.download(self.url, self.zip_path)
            with gzip.open(self.zip_path, 'rb') as f_in:
                with open(self.json_path, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)

            stats_from_json = self.process_json(self.json_path)
            self.stdout.write(self.update_db(stats_from_json))
        except:
            self.clear_temp_data()
            raise

        self.clear_temp_data()
        return self.style.SUCCESS('update_covid_19_stats finished OK')

    @staticmethod
    def process_json(json_file_path):
        stats_from_json = CountryStatsFromJson()

        with open(json_file_path, "r") as read_file:
            data = json.load(read_file)
            for ds_row in data:
                if ds_row['location']['type'] == 'total-country' and 'absolute' in ds_row['values']:
                    country_code = ds_row['location']['country_code']
                    if country_code not in stats_from_json.countries_dict:
                        stats_from_json.countries_dict[country_code] = list()

                    daily_stats = CountryDailyStats(ds_row['date']['date'])
                    daily_stats.confirmed = ds_row['values']['absolute']['confirmed']
                    if 'deaths' in ds_row['values']['absolute']:
                        daily_stats.deaths = ds_row['values']['absolute']['deaths']
                    if 'recovered' in ds_row['values']['absolute']:
                        daily_stats.recovered = ds_row['values']['absolute']['recovered']
                    stats_from_json.countries_dict[country_code].append(daily_stats)

        return stats_from_json

    @staticmethod
    def update_db(stats):
        inserted = 0
        updated = 0
        season = DiseaseSeason.objects.get(disease=Disease.objects.get(icd_10_code='U07.1'), start_date='2019-11-17')

        countries = Country.objects.all()
        for country in countries:
            country_stats = stats.countries_dict.get(country.iso_a_2_code)
            if country_stats is None:
                continue

            for daily_stats in country_stats:
                obj, created = DiseaseStats.objects.update_or_create(disease_season=season,
                                                                     country=country,
                                                                     stats_date=daily_stats.date,
                                                                     defaults={'recovered': daily_stats.recovered,
                                                                               'confirmed': daily_stats.confirmed,
                                                                               'deaths': daily_stats.deaths})
                if created:
                    inserted += 1
                else:
                    updated += 1

        return 'update_covid_19_stats: inserted = %i, updated = %i' % (inserted, updated)

    def clear_temp_data(self):
        if os.path.exists(self.json_path):
            os.remove(self.json_path)

        if os.path.exists(self.zip_path):
            os.remove(self.zip_path)
