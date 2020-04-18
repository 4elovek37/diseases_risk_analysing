import pygal
import datetime

class DiseaseConfirmedAndCarriersChart:
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


class MedicalSituationChart:
    def __init__(self, **kwargs):
        self.chart = pygal.DateLine(**kwargs)

    def generate(self, active_patients, beds_cnt, nurses_cnt):
        if beds_cnt is None and nurses_cnt is None:
            return None

        serie_beds = list()
        serie_nurses = list()
        serie_patients = list()

        if beds_cnt is not None:
            show_beds = True
        else:
            show_beds = False

        if nurses_cnt is not None:
            show_nurses = True
        else:
            show_nurses = False

        for stat in active_patients:
            serie_patients.append((stat.date, stat.val))
            if show_beds:
                serie_beds.append((stat.date, beds_cnt))
            if show_nurses:
                serie_nurses.append((stat.date, nurses_cnt))

        self.chart.add('Active patients', serie_patients, show_dots=False)

        if show_beds:
            self.chart.add('Beds', serie_beds, show_dots=False)
        if show_nurses:
            self.chart.add('Nurses', serie_nurses, show_dots=False)
        return self.chart.render(is_unicode=True)
