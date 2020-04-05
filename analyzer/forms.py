from django import forms
from django.core.exceptions import ValidationError
import datetime
from functools import partial
DateInput = partial(forms.DateInput, {'class': 'datepicker'})
DATE_INPUT_FORMATS = ['%Y-%m-%d']
ACTIVITY_LEVELS = [
    ('min', 'Minimal'),
    ('mid', 'Middle'),
    ('max', 'Intensive'),
    ]


class EstimateRisksForm(forms.Form):
    country_2_a_code = forms.CharField(widget=forms.HiddenInput())
    start_date = forms.DateField(input_formats=DATE_INPUT_FORMATS, widget=DateInput())
    end_date = forms.DateField(input_formats=DATE_INPUT_FORMATS, widget=DateInput())
    age = forms.IntegerField(max_value=120, min_value=1)
    comorbid = forms.MultipleChoiceField(widget=forms.CheckboxSelectMultiple)
    social_activity_level = forms.CharField(widget=forms.RadioSelect(choices=ACTIVITY_LEVELS))
