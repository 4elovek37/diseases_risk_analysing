from django.shortcuts import render
from django.http import HttpResponse
from django.http import QueryDict
from analyzer.models import Country, Disease, DiseaseSeason, DiseaseStats, ComorbidConditionCfr
#import numpy as np
from .forms import EstimateRisksForm
from .disease_models.covid_19_model import Covid19Model
import datetime

covid_model = Covid19Model()


def index(request):
    if request.method == 'GET':
        world_top = covid_model.calc_world_ranks()
        return render(request, 'index.html', context={'CFR_top': world_top.cfr_top,
                                                      'growth_top': world_top.growth_top,
                                                      'confirmed_top': world_top.confirmed_top})
    else:
        return HttpResponse("Request method is not a GET")


def country_basic_stat(request):
    if request.method == 'GET':
        country_a_2_code = request.GET['countryCode']

        confirmed = 0
        deaths = 0
        recovered = 0
        cfr = '-'

        if country_a_2_code == '00':
            country_a_2_code = 'World'
            confirmed, deaths, recovered = covid_model.get_world_sum()

            if deaths > 0 and confirmed > 0:
                cfr = (deaths / confirmed) * 100
        else:
            confirmed, deaths, recovered, cfr, name = covid_model.prerender_country_last_state(country_a_2_code)
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


def get_modal_report(request):
    if request.method == 'GET':
        #form_data = QueryDict(request.GET['form'].encode('ASCII'))

        return render(request, "modal_report.html")
    else:
        return HttpResponse("Request method is not a GET")


def get_estimate_risk_form(request):
    covid = Disease.objects.get(icd_10_code='U07.1')
    comorbid_list = ComorbidConditionCfr.objects.filter(disease=covid)

    comorbid_names = list()
    for comorbid in comorbid_list:
        comorbid_names.append((comorbid.comorbid_disease.disease_id, comorbid.comorbid_disease.name))

    if request.method == 'GET':
        if len(request.GET['form']) == 0:
            form = EstimateRisksForm()
            form.fields['comorbid'].choices = comorbid_names
            form.fields['social_activity_level'].initial = ('mid')
            form.fields['start_date'].initial = datetime.date.today
            form.fields['end_date'].initial = datetime.date.today
        else:
            form_data = QueryDict(request.GET['form'].encode('ASCII'))
            form = EstimateRisksForm()
            form.fields['country_2_a_code'].initial = request.GET['country_code']
            form.fields['comorbid'].choices = comorbid_names
            if 'comorbid' in form_data:
                form.fields['comorbid'].initial = form_data.getlist('comorbid')

            form.fields['start_date'].initial = form_data['start_date']
            form.fields['end_date'].initial = form_data['end_date']
            form.fields['age'].initial = form_data['age']
            form.fields['social_activity_level'].initial = form_data['social_activity_level']

        allow_submit = covid_model.check_if_country_code_acceptable(request.GET['country_code'])
        return render(request, 'estimate_risks_form.html', context={'form': form,
                                                                    'allow_submit': allow_submit})
    else:
        return HttpResponse("Request method is not a GET")


def _approximate_covid_confirmed_function(country_a_2_code):
    country = Country.objects.get(iso_a_2_code=country_a_2_code.upper())
    season = DiseaseSeason.objects.get(disease=Disease.objects.get(icd_10_code='U07.1'), start_date='2019-11-17')
    confirmed_list = list()
    for stat in DiseaseStats.objects.filter(disease_season=season, country=country).order_by("-stats_date")[:10]:
        confirmed_list.insert(0, stat.confirmed)