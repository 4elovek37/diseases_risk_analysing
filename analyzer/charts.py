import pygal
import datetime

class DiseaseConfirmedAndCarriersChart:
    def __init__(self):
        self.chart = pygal.DateLine(legend_at_bottom=True, legend_at_bottom_columns=2)
        #self.chart.title = 'Confirmed cases'

    def generate(self, confirmed_daily_stats, carriers_daily_stats):
        serie_confirmed = list()
        serie_carriers = list()

        for stat in confirmed_daily_stats:
            serie_confirmed.append((stat.date, stat.val))

        for stat in carriers_daily_stats:
            serie_carriers.append((stat.date, stat.val))
        self.chart.add('Confirmed, people', serie_confirmed)
        self.chart.add('Carriers, people', serie_carriers)

        return self.chart.render(is_unicode=True)


class MedicalSituationChart:
    def __init__(self,):
        self.chart = pygal.DateLine(secondary_range=(0, 100), legend_at_bottom=True, legend_at_bottom_columns=4)

    def generate(self, active_patients, cfr, beds_cnt, nurses_cnt):
        if beds_cnt is None and nurses_cnt is None:
            return None

        serie_beds = list()
        serie_nurses = list()
        serie_patients = list()
        serie_cfr = list()

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
            self.chart.add('Beds, units', serie_beds, show_dots=False)
        if show_nurses:
            self.chart.add('Nurses, people', serie_nurses, show_dots=False)

        for cfr_stat in cfr:
            serie_cfr.append((cfr_stat.date, cfr_stat.val * 100))

        self.chart.add('CFR, percents', serie_cfr, show_dots=False, secondary=True)
        self.chart.value_formatter = lambda x: "%i" % x

        return self.chart.render(is_unicode=True)
