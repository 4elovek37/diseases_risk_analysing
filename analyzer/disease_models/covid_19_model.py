from .disease_model import DiseaseModel
from analyzer.models import Disease, DiseaseSeason


class Covid19Model(DiseaseModel):
    def __init__(self):
        super(Covid19Model, self).__init__()

        self.season = DiseaseSeason.objects.get(disease=Disease.objects.get(icd_10_code='U07.1'),
                                                start_date='2019-11-17')

    def _get_season(self):
        return self.season

