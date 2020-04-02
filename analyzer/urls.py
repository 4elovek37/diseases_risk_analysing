from django.urls import path
from django.conf.urls import include, url
from . import views


urlpatterns = [
    url(r'^$', views.index, name='index'),
    url('^get_country_basic_stat$', views.country_basic_stat, name='country_basic_stat'),
]