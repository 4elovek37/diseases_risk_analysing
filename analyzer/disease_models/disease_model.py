from ..views_misc import CountryActualState
from ..views_misc import CountriesWorldTop
from ..views_misc import DailyStat
from analyzer.models import Country, DiseaseStats, PopulationStats, ContactsEstimation, AgeGroupCfr, ComorbidConditionCfr
import operator
import statistics
import numpy as np
import datetime
import math
from enum import Enum


class DiseaseModel:
    def _get_season(self):
        raise NotImplementedError("_get_season must be overridden")

    def _get_carrier_window(self):
        return NotImplementedError("_get_carrier_window must be overridden")

    def _get_carrier_multiplier(self):
        return 1

    def _get_sar_estimation(self):
        return NotImplementedError("_get_sar_estimation must be overridden")

    def _get_disease(self):
        return NotImplementedError("_get_disease must be overridden")

    class _CombinatoricsCalculator:
        def calc_probability(self, one_obj_probability,
                             attempts_cnt, objects_of_interest_cnt, total_objects_cnt):
            one_obj_probability_inv = 1 - one_obj_probability
            not_interesting_objs_cnt = total_objects_cnt - objects_of_interest_cnt
            probability_inv = 0.
            for i in range(0, min(attempts_cnt, objects_of_interest_cnt)):
                probability_inv += pow(one_obj_probability_inv, i) * self._calc_c(objects_of_interest_cnt, i) * \
                self._calc_c(not_interesting_objs_cnt, attempts_cnt - i) / self._calc_c(total_objects_cnt, attempts_cnt)

            return 1. - probability_inv

        @staticmethod
        def _calc_c(n, k):

            upper = 1
            for i in range(n - k + 1, n + 1):
                upper *= i
            return upper / math.factorial(k)

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

            if not (x_np > 0).all() or not (y_np > 0).all():
                self._method = self.ExtrapolationMethod.LIN
                return

            self.log_fit = np.polyfit(np.log(x_np), y, 1)
            self.exp_fit = np.polyfit(x, np.log(y_np), 1, w=np.sqrt(y_np))

            lin_squares = 0
            log_squares = 0
            exp_squares = 0

            for i in range(len(x) - 10, len(x)):
                if i < 0:
                    continue
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
            #print(self._method)

        def calc_val(self, x):
            if self._method == self.ExtrapolationMethod.LIN:
                return self._calc_val_lin(x)
            elif self._method == self.ExtrapolationMethod.EXP:
                return self._calc_val_exp(x)
            else:
                return self._calc_val_log(x)

    def get_active_patients_and_cfr_graph(self, country_a_2_code):
        active_patients_graph = list()
        cfr_graph = list()
        country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
        last_recovered = 0
        for stat in DiseaseStats.objects.filter(disease_season=self._get_season(), country=country).order_by("stats_date"):
            if stat.recovered:
                last_recovered = stat.recovered
            active_patients_graph.append(DailyStat(stat.stats_date, stat.confirmed - stat.deaths - last_recovered))
            if stat.deaths > 0 and stat.confirmed > 0:
                cfr_graph.append(DailyStat(stat.stats_date, (stat.deaths / stat.confirmed)))

        return active_patients_graph, cfr_graph

    def extrapolate_confirmed_cases(self, country_a_2_code):
        confirmed_cases_graph = list()
        country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
        season = self._get_season()
        real_stats = DiseaseStats.objects.filter(disease_season=season, country=country).order_by("stats_date")
        extrapolation_x = list()
        extrapolation_y = list()
        for stat in real_stats:
            confirmed_cases_graph.append(DailyStat(stat.stats_date, stat.confirmed))
            extrapolation_y.append(stat.confirmed)
            extrapolation_x.append(len(extrapolation_x) + 1)

        extrapolator = self._Extrapolator()
        extrapolator.fit_data(extrapolation_x, extrapolation_y)

        last_date = confirmed_cases_graph[len(confirmed_cases_graph)-1].date
        last_x = extrapolation_x[len(extrapolation_x)-1]
        for i in range(1, 11):
            extrapolation_date = last_date + datetime.timedelta(days=i)
            confirmed_est = int(extrapolator.calc_val(last_x + i))
            confirmed_cases_graph.append(DailyStat(extrapolation_date, confirmed_est))

        return confirmed_cases_graph

    def estimate_carriers(self, confirmed_cases_graph):
        carrier_cases_graph = list()

        extrapolation_x = list()
        diffs = list()
        for i in range(1, len(confirmed_cases_graph)):
            curr_diff = confirmed_cases_graph[i].val - confirmed_cases_graph[i-1].val
            diffs.append(curr_diff)
            extrapolation_x.append(len(extrapolation_x) + 1)

        extrapolator = self._Extrapolator()
        extrapolator.fit_data(extrapolation_x, diffs)

        extrapolation_x.insert(0, 0)
        diffs.insert(0, 0)

        last_x = extrapolation_x[len(extrapolation_x) - 1]
        for i in range(1, self._get_carrier_window()):
            diff_est = int(extrapolator.calc_val(last_x + i))
            diffs.append(diff_est)

        curr_sum_window = 0
        for i in range(0, self._get_carrier_window() - 1):
            curr_sum_window += diffs[i]

        for i in range(0, len(confirmed_cases_graph)):
            if i - 1 >= 0:
                curr_sum_window -= diffs[i-1]
            curr_sum_window += diffs[i+self._get_carrier_window()-1]
            carrier_est = int(curr_sum_window * self._get_carrier_multiplier())
            carrier_cases_graph.append(DailyStat(confirmed_cases_graph[i].date, carrier_est))

        return carrier_cases_graph

    def estimate_probability_of_getting(self, age, activity_level, country_a_2_code, carriers_graph, confirmed_graph,
                                        first_day, days_cnt):
        country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
        population = PopulationStats.objects.filter(country=country).order_by('-year')[0].population
        sar_est = self._get_sar_estimation()
        contacts = 0
        for contact_stat in ContactsEstimation.objects.all().order_by('age_limit'):
            if contacts == 0 or contact_stat.age_limit <= age:
                contacts = contact_stat.estimation
            else:
                break
        if activity_level == 'min':
            contacts = round(contacts * (2./3))
        elif activity_level == 'max':
            contacts = round(contacts * (3./2))

        combinatorics = self._CombinatoricsCalculator()
        prob_of_not = 1.
        first_day_idx = next((idx for idx, stat in enumerate(carriers_graph) if stat.date == first_day), None)
        if not first_day_idx:
            return None

        for i in range(first_day_idx, first_day_idx + days_cnt):
            prob_of_not *= (1. - combinatorics.calc_probability(sar_est / 100.,
                                                                contacts,
                                                                carriers_graph[i].val,
                                                                population - confirmed_graph[i].val))
        return 1. - prob_of_not

    def estimate_probability_of_death(self, age, comorbid_list, country_a_2_code):
        disease = self._get_disease()
        country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
        # avg by ages and for given age
        cfr_by_age = 0
        age_groups_cnt = 0
        avg_cfr_by_age = 0
        for age_stat in AgeGroupCfr.objects.filter(disease=disease).order_by('age_limit'):
            if cfr_by_age == 0 or age_stat.age_limit <= age:
                cfr_by_age = age_stat.cfr
            age_groups_cnt += 1
            avg_cfr_by_age += age_stat.cfr

        cfr_by_age /= 100.
        avg_cfr_by_age = float(avg_cfr_by_age) / age_groups_cnt / 100.

        # by comorbid
        cfr_by_comorbid = None
        if len(comorbid_list) > 0:
            cfr_by_comorbid_inv = 1.
            for comorbid_id in comorbid_list:
                comorbid_stat = ComorbidConditionCfr.objects.get(disease=disease, comorbid_disease_id=comorbid_id)
                cfr_by_comorbid_inv *= (1 - comorbid_stat.cfr / 100.)
            cfr_by_comorbid = 1 - cfr_by_comorbid_inv

        # country coefficient
        last_country_state = self._get_country_last_state(country)
        if last_country_state.CFR is not None:
            mult = (last_country_state.CFR / 100.) / avg_cfr_by_age #norm by avg
            if cfr_by_comorbid is not None:
                cfr_by_comorbid *= mult
            else:
                cfr_by_age *= mult

        if cfr_by_comorbid is not None:
            return min(cfr_by_comorbid, 1.)
        else:
            return min(cfr_by_age, 1.)

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
        last_date = datetime.date.min

        countries = Country.objects.all()
        for country in countries:
            state = self._get_country_last_state(country)
            if state is None:
                continue

            confirmed += state.confirmed
            deaths += state.deaths
            if state.recovered is not None:
                recovered += state.recovered
            if state.date > last_date:
                last_date = state.date

        return confirmed, deaths, recovered, last_date

    def prerender_country_last_state(self, country_a_2_code):
        confirmed = '-'
        deaths = '-'
        recovered = '-'
        cfr = '-'
        name = '-'
        date = '-'

        country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
        if country:
            state = self._get_country_last_state(country)
            if state is not None:
                name = country.name
                confirmed = state.confirmed
                deaths = state.deaths
                date = state.date

                if state.recovered is not None:
                    recovered = state.recovered

                if state.CFR is not None:
                    cfr = state.CFR

        return confirmed, deaths, recovered, cfr, name, date

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

        country_state = CountryActualState(country.name, last_state[0].stats_date)
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

            country_state = CountryActualState(country.name, stats_ordered[0].stats_date)

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
