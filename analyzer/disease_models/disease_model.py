from ..views_misc import CountryActualState
from ..views_misc import CountriesWorldTop
from ..views_misc import ConfirmedDailyStat
from analyzer.models import Country, DiseaseStats
import operator
import statistics
import numpy as np
import datetime
from enum import Enum


class DiseaseModel:
    class _Extrapolator:
        class ExtrapolationMethod(Enum):
            LIN = 1,
            LOG = 2,
            EXP = 3

        def __init__(self):
            self._method = self.ExtrapolationMethod.LIN
            self.line_f = None
            self.log_fit = None
            self.exp_fit = None

        def _calc_val_lin(self, x):
            return self.line_f(x)

        def _calc_val_log(self, x):
            return self.log_fit[0] * x - self.log_fit[1]

        def _calc_val_exp(self, x):
            return np.exp(self.exp_fit[1]) * np.exp(self.exp_fit[0] * x)

        def fit_data(self, x, y):
            self.line_f = np.poly1d(np.polyfit(x[-10:], y[-10:], 1))
            x_np = np.array(x)
            y_np = np.array(y)
            self.log_fit = np.polyfit(np.log(x_np), y, 1)
            self.exp_fit = np.polyfit(x, np.log(y_np), 1, w=np.sqrt(y_np))

            lin_squares = 0
            log_squares = 0
            exp_squares = 0

            for i in range(len(x) - 10, len(x)):
                line_est = self._calc_val_lin(x[i])
                log_est = self._calc_val_log(x[i])
                exp_est = self._calc_val_exp(x[i])
                real_val = y[i]
                lin_squares += pow(real_val - line_est, 2)
                log_squares += pow(real_val - log_est, 2)
                exp_squares += pow(real_val - exp_est, 2)

            if lin_squares <= log_squares and lin_squares <= exp_squares:
                self._method = self.ExtrapolationMethod.LIN
            elif log_squares <= lin_squares and log_squares <= exp_squares:
                self._method = self.ExtrapolationMethod.LOG
            else:
                self._method = self.ExtrapolationMethod.EXP
            print(self._method)

        def calc_val(self, x):
            if self._method == self.ExtrapolationMethod.LIN:
                return self._calc_val_lin(x)
            elif self._method == self.ExtrapolationMethod.EXP:
                return self._calc_val_exp(x)
            else:
                return self._calc_val_log(x)

    def extrapolate_confirmed_cases(self, country_a_2_code):
        confirmed_cases_graph = list()

        country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
        season = self._get_season()
        real_stats = DiseaseStats.objects.filter(disease_season=season, country=country).order_by("stats_date")
        extrapolation_x = list()
        extrapolation_y = list()
        for stat in real_stats:
            confirmed_cases_graph.append(ConfirmedDailyStat(stat.stats_date, stat.confirmed))
            extrapolation_y.append(stat.confirmed)
            extrapolation_x.append(len(extrapolation_x) + 1)

        extrapolator = self._Extrapolator()
        extrapolator.fit_data(extrapolation_x, extrapolation_y)

        last_date = confirmed_cases_graph[len(confirmed_cases_graph)-1].date
        last_x = extrapolation_x[len(extrapolation_x)-1]
        for i in range(1, 11):
            extrapolation_date = last_date + datetime.timedelta(days=i)
            extrapolation_x = last_x + i
            confirmed_est = int(extrapolator.calc_val(extrapolation_x))
            confirmed_cases_graph.append(ConfirmedDailyStat(extrapolation_date, confirmed_est))

        return confirmed_cases_graph

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