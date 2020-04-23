from django.core.management.base import BaseCommand, CommandError
from analyzer.models import Country, PopulationStats
import os
import wget
from zipfile import ZipFile
import untangle


class PopulationStatsFromXml:
    def __init__(self):
        self.countries_dict = dict()


class Command(BaseCommand):
    help = 'Initiates updating of population stats table'

    def __init__(self):
        BaseCommand.__init__(self)
        self.url = 'http://api.worldbank.org/v2/en/indicator/SP.POP.TOTL?downloadformat=xml'
        self.zip_path = './analyzer/management/commands/update_population_stats/dataset.zip'

    def handle(self, *args, **options):
        try:
            directory = os.path.dirname(self.zip_path)
            if not os.path.exists(directory):
                os.makedirs(directory)

            wget.download(self.url, self.zip_path)
            with ZipFile(self.zip_path) as zip_data:
                with zip_data.open(zip_data.namelist()[0]) as xml_data:
                    parsed_stats = self.process_xml(xml_data.read())
                    self.stdout.write(self.update_db(parsed_stats))
        except:
            self.clear_temp_data()
            raise

        self.clear_temp_data()
        return self.style.SUCCESS('update_population_stats finished OK')

    @staticmethod
    def process_xml(xml):
        stats_from_xml = PopulationStatsFromXml()

        xml_str = xml.decode("utf-8")
        doc = untangle.parse(xml_str)

        for record in doc.get_elements('Root')[0].data.get_elements('record'):
            country_code = ''
            year = 0
            value = 0
            for field in record.get_elements('field'):
                attr_type = field.get_attribute('name')
                if attr_type == 'Country or Area':
                    country_code = field.get_attribute('key')
                elif attr_type == 'Year':
                    year = field.cdata
                elif attr_type == 'Value':
                    value = field.cdata

            if value == '':
                continue

            if country_code not in stats_from_xml.countries_dict:
                stats_from_xml.countries_dict[country_code] = {year: value}
            else:
                stats_from_xml.countries_dict[country_code][year] = value

        return stats_from_xml

    @staticmethod
    def update_db(stats):
        # TODO: store all available data when storage is not limited
        store_only_fresh = True

        inserted = 0
        updated = 0
        countries = Country.objects.all()

        for country in countries:
            country_stats = stats.countries_dict.get(country.iso_a_3_code)
            if country_stats is None:
                continue

            if store_only_fresh:
                years_list = sorted(list(country_stats))[-1:] # get only the last year
            else:
                years_list = list(country_stats)

            for year in years_list:
                value = country_stats[year]

                obj, created = PopulationStats.objects.update_or_create(country=country, year=year,
                                                                        defaults={'population': value})
                if created:
                    inserted += 1
                else:
                    updated += 1

        return 'update_population_stats: inserted = %i, updated = %i' % (inserted, updated)

    def clear_temp_data(self):
        if os.path.exists(self.zip_path):
            os.remove(self.zip_path)
