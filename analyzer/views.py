from django.shortcuts import render
from django.http import HttpResponse
from analyzer.models import Country, Disease, DiseaseSeason, DiseaseStats
import operator
import statistics


class CountryActualState:
    def __init__(self, country_name):
        self.country_name = country_name
        self.CFR = None
        self.confirmed = 0
        self.deaths = 0
        self.recovered = None
        #self.growth_gradient = list()
        self.avg_growth = 0


class CountriesWorldTop:
    def __init__(self):
        self.cfr_top = list()
        self.growth_top = list()
        self.confirmed_top = list()


# Create your views here.
def index(request):
    world_top = _calc_covid_world_ranks()
    return render(request, 'index.html', context={'CFR_top': world_top.cfr_top,
                                                  'growth_top': world_top.growth_top,
                                                  'confirmed_top': world_top.confirmed_top})


def country_basic_stat(request):
    if request.method == 'GET':
        country_a_2_code = request.GET['countryCode']

        confirmed = 0
        deaths = 0
        recovered = 0
        cfr = '-'

        if country_a_2_code == '00':
            country_a_2_code = 'World'
            confirmed, deaths, recovered = _get_covid_world_sum()

            if deaths > 0 and confirmed > 0:
                cfr = (deaths / confirmed) * 100
        else:
            confirmed, deaths, recovered, cfr, name = _prerender_covid_country_last_state(country_a_2_code)
            country_a_2_code = name
        if cfr != '-':
            cfr = round(cfr, 2)
        return render(request, 'country_basic_stat.html', context={'region_name': country_a_2_code,
                                                                   'confirmed': confirmed,
                                                                   'deaths': deaths,
                                                                   'recovered': recovered,
                                                                   'cfr': cfr})
    else:
        return HttpResponse("Request method is not a GET")


def _get_covid_world_sum():
    confirmed = 0
    deaths = 0
    recovered = 0

    countries = Country.objects.all()
    for country in countries:
        state = _get_covid_country_last_state(country)
        if state is None:
            continue

        confirmed += state.confirmed
        deaths += state.deaths
        if state.recovered is not None:
            recovered += state.recovered

    return confirmed, deaths, recovered


def _prerender_covid_country_last_state(country_a_2_code):
    confirmed = '-'
    deaths = '-'
    recovered = '-'
    cfr = '-'
    name = '-'

    country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
    if country:
        state = _get_covid_country_last_state(country)
        if state is not None:
            name = country.name
            confirmed = state.confirmed
            deaths = state.deaths

            if state.recovered is not None:
                recovered = state.recovered

            if state.CFR is not None:
                cfr = state.CFR

    return confirmed, deaths, recovered, cfr, name


def _get_covid_country_last_state(country):
    season = DiseaseSeason.objects.get(disease=Disease.objects.get(icd_10_code='U07.1'), start_date='2019-11-17')
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


def _calc_covid_world_ranks():
    world_top = CountriesWorldTop()
    countries_list, avg_confirmed = _get_covid_world_stats()
    reliable_countries_list = list(filter(lambda x: x.confirmed >= (avg_confirmed / 10), countries_list))

    world_top.cfr_top = \
        sorted(list(filter(lambda x: x.CFR is not None, reliable_countries_list)), key=operator.attrgetter('CFR'))[-3:]
    world_top.cfr_top.reverse()

    world_top.growth_top = sorted(reliable_countries_list, key=operator.attrgetter('avg_growth'))[-3:]
    world_top.growth_top.reverse()

    world_top.confirmed_top = sorted(countries_list, key=operator.attrgetter('confirmed'))[-3:]
    world_top.confirmed_top.reverse()

    return world_top


def _get_covid_world_stats():
    dataset_len = 10
    countries_list = list()
    avg_confirmed = 0
    season = DiseaseSeason.objects.get(disease=Disease.objects.get(icd_10_code='U07.1'), start_date='2019-11-17')

    countries = Country.objects.all()
    for country in countries:
        stats_ordered = DiseaseStats.objects.filter(disease_season=season, country=country).order_by("-stats_date")[:dataset_len]

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
