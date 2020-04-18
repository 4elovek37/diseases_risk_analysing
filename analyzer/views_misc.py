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


class DailyStat:
    def __init__(self, date, val):
        self.date = date
        self.val = val
