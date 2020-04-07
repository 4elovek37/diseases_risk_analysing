from ..views_misc import CountryActualState
from ..views_misc import CountriesWorldTop
from analyzer.models import Country, DiseaseStats
import operator
import statistics


class DiseaseModel:
    def extrapolate_confirmed_cases(self, country_a_2_code):
        raise NotImplementedError("extrapolate_confirmed_cases must be overridden")

    def _get_season(self):
        raise NotImplementedError("_get_season must be overridden")

    def calc_world_ranks(self):
        world_top = CountriesWorldTop()

        countries_list, avg_confirmed = self._get_world_stats()
        reliable_countries_list = list(filter(lambda x: x.confirmed >= (avg_confirmed / 10), countries_list))

        world_top.cfr_top = \
            sorted(list(filter(lambda x: x.CFR is not None, reliable_countries_list)),
                   key=operator.attrgetter('CFR'))[-3:]
        world_top.cfr_top.reverse()

        world_top.growth_top = sorted(reliable_countries_list, key=operator.attrgetter('avg_growth'))[-3:]
        world_top.growth_top.reverse()

        world_top.confirmed_top = sorted(countries_list, key=operator.attrgetter('confirmed'))[-3:]
        world_top.confirmed_top.reverse()

        return world_top

    def get_world_sum(self):
        confirmed = 0
        deaths = 0
        recovered = 0

        countries = Country.objects.all()
        for country in countries:
            state = self._get_country_last_state(country)
            if state is None:
                continue

            confirmed += state.confirmed
            deaths += state.deaths
            if state.recovered is not None:
                recovered += state.recovered

        return confirmed, deaths, recovered

    def prerender_country_last_state(self, country_a_2_code):
        confirmed = '-'
        deaths = '-'
        recovered = '-'
        cfr = '-'
        name = '-'

        country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
        if country:
            state = self._get_country_last_state(country)
            if state is not None:
                name = country.name
                confirmed = state.confirmed
                deaths = state.deaths

                if state.recovered is not None:
                    recovered = state.recovered

                if state.CFR is not None:
                    cfr = state.CFR

        return confirmed, deaths, recovered, cfr, name

    def check_if_country_code_acceptable(self, country_a_2_code):
        try:
            country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
        except Country.DoesNotExist:
            return False

        season = self._get_season()
        if DiseaseStats.objects.filter(disease_season=season, country=country).count() < 10:
            return False

        return True

    def _get_country_last_state(self, country):
        season = self._get_season()
        last_state = DiseaseStats.objects.filter(disease_season=season, country=country).order_by("-stats_date")[:1]
        if not last_state:
            return None

        country_state = CountryActualState(country.name)
        country_state.confirmed = last_state[0].confirmed
        country_state.deaths = last_state[0].deaths
        country_state.recovered = last_state[0].recovered

        if country_state.deaths > 0 and country_state.confirmed > 0:
            country_state.CFR = (country_state.deaths / country_state.confirmed) * 100

        return country_state

    def _get_world_stats(self):
        dataset_len = 10
        countries_list = list()
        avg_confirmed = 0
        season = self._get_season()

        countries = Country.objects.all()
        for country in countries:
            stats_ordered = DiseaseStats.objects.filter(disease_season=season, country=country).order_by("-stats_date")[
                            :dataset_len]

            if not stats_ordered:
                continue

            country_state = CountryActualState(country.name)

            prev_confirmed = -1
            growth_gradient = list()
            for stats in stats_ordered:
                if prev_confirmed >= 0:
                    growth_gradient.append(prev_confirmed - stats.confirmed)
                prev_confirmed = stats.confirmed

            country_state.confirmed = stats_ordered[0].confirmed
            avg_confirmed += country_state.confirmed
            if stats_ordered[0].deaths > 0:
                country_state.CFR = round((stats_ordered[0].deaths / country_state.confirmed) * 100, 2)

            if len(growth_gradient) > 0:
                country_state.avg_growth = int(statistics.mean(growth_gradient))
            countries_list.append(country_state)

        return countries_list, avg_confirmed / len(countries_list)