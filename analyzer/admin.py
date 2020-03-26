from django.contrib import admin

# Register your models here.
from .models import Country, Disease, ComorbidConditionCfr, AgeGroupCfr, PopulationStats, DiseaseSeason, DiseaseStats, \
    InternalsDataHandlingTask, ContactsEstimation

admin.site.register(Country)
admin.site.register(Disease)
admin.site.register(ComorbidConditionCfr)
admin.site.register(AgeGroupCfr)
admin.site.register(PopulationStats)
admin.site.register(DiseaseSeason)
admin.site.register(DiseaseStats)
admin.site.register(InternalsDataHandlingTask)
admin.site.register(ContactsEstimation)
