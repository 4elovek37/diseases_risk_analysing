from .disease_model import DiseaseModel
from analyzer.models import Disease, DiseaseSeason


class Covid19Model(DiseaseModel):
    def __init__(self):
        super(Covid19Model, self).__init__()
        self.disease = Disease.objects.get(icd_10_code='U07.1')
        self.season = DiseaseSeason.objects.get(disease=self.disease,
                                                start_date='2019-11-17')

    def _get_season(self):
        return self.season

    def _get_carrier_window(self):
        return 5

    def _get_carrier_multiplier(self):
        return 1.25

    def _get_sar_estimation(self):
        return self.disease.sar_estimation

    def _get_disease(self):
        return self.disease

