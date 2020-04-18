import pygal
import datetime

class DiseaseConfirmedAndCarriersChart():
    def __init__(self, **kwargs):
        self.chart = pygal.DateLine(**kwargs)
        #self.chart.title = 'Confirmed cases'

    def generate(self, confirmed_daily_stats, carriers_daily_stats):
        serie_confirmed = list()
        serie_carriers = list()
        for stat in confirmed_daily_stats:
            serie_confirmed.append((stat.date, stat.val))
        for stat in carriers_daily_stats:
            serie_carriers.append((stat.date, stat.val))
        self.chart.add('Confirmed', serie_confirmed)
        self.chart.add('Carriers', serie_carriers)
        return self.chart.render(is_unicode=True)