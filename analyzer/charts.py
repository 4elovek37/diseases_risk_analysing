import pygal
import datetime

class DiseaseConfirmedChart():
    def __init__(self, **kwargs):
        self.chart = pygal.DateLine(**kwargs)
        #self.chart.title = 'Confirmed cases'

    def generate(self, confirmed_daily_stats):
        serie = list()

        for stat in confirmed_daily_stats:
            serie.append((stat.date, stat.confirmed))
            #self.chart.add(stat.date, stat.confirmed)#.strftime('%d/%m')
        self.chart.add('Confirmed', serie)
        self.chart.add('bla bla ', [(datetime.date.today(), 100000)])
        return self.chart.render(is_unicode=True)