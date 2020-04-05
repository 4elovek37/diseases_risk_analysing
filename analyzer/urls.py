from django.urls import path
from django.conf.urls import include, url
from . import views


urlpatterns = [
    url(r'^$', views.index, name='index'),
    url('^get_country_basic_stat$', views.country_basic_stat, name='country_basic_stat'),
    url('^get_estimate_risk_form$', views.get_estimate_risk_form, name='get_estimate_risk_form'),
    url('^get_modal_report$', views.get_modal_report, name='get_modal_report'),
]