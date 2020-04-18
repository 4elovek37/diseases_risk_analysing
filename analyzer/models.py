# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.db import models


class Country(models.Model):
    country_id = models.AutoField(primary_key=True)
    name = models.CharField(unique=True, max_length=50)
    iso_a_3_code = models.CharField(unique=True, max_length=3)
    iso_a_2_code = models.CharField(unique=True, max_length=2)

    def __str__(self):
        return '%s, %s' % (self.name, self.iso_a_3_code)

    class Meta:
        managed = False
        db_table = 'country'


class Disease(models.Model):
    disease_id = models.AutoField(primary_key=True)
    name = models.CharField(unique=True, max_length=50)
    icd_10_code = models.CharField(max_length=5, blank=True, null=True)
    sar_estimation = models.FloatField(blank=True, null=True)

    def __str__(self):
        return '%s' % self.name

    class Meta:
        managed = True
        db_table = 'disease'


class ComorbidConditionCfr(models.Model):
    comorbid_condition_cfr_id = models.AutoField(primary_key=True)
    disease = models.ForeignKey('Disease', models.PROTECT)
    comorbid_disease = models.ForeignKey('Disease', models.PROTECT, related_name='+')
    cfr = models.FloatField()

    class Meta:
        managed = True
        db_table = 'comorbid_condition_cfr'
        unique_together = (('disease', 'comorbid_disease'),)


class AgeGroupCfr(models.Model):
    age_group_cfr_id = models.AutoField(primary_key=True)
    disease = models.ForeignKey('Disease', models.PROTECT)
    age_limit = models.SmallIntegerField()
    cfr = models.FloatField()

    class Meta:
        managed = True
        db_table = 'age_group_cfr'
        unique_together = (('disease', 'age_limit'),)


class ContactsEstimation(models.Model):
    age_limit = models.SmallIntegerField(primary_key=True)
    estimation = models.SmallIntegerField()

    class Meta:
        managed = True
        db_table = 'contacts_estimation'


class DiseaseSeason(models.Model):
    disease_season_id = models.AutoField(primary_key=True)
    disease = models.ForeignKey(Disease, models.PROTECT)
    start_date = models.DateField()
    end_date = models.DateField(blank=True, null=True)

    class Meta:
        managed = True
        db_table = 'disease_season'
        unique_together = (('disease', 'start_date'),)


class DiseaseStats(models.Model):
    disease_stats_id = models.BigAutoField(primary_key=True)
    disease_season = models.ForeignKey(DiseaseSeason, models.PROTECT)
    country = models.ForeignKey(Country, models.PROTECT)
    stats_date = models.DateField()
    confirmed = models.IntegerField()
    recovered = models.IntegerField(null=True)
    deaths = models.IntegerField()

    class Meta:
        managed = True
        db_table = 'disease_stats'
        unique_together = (('disease_season', 'country', 'stats_date'),)


class InternalsDataHandlingTask(models.Model):
    internals_data_handling_task_id = models.SmallAutoField(primary_key=True)
    task_name = models.CharField(unique=True, max_length=50)
    frequency_days = models.IntegerField()
    last_update = models.DateField(blank=True, null=True)
    enabled_flag = models.BooleanField()
    command_name = models.CharField(max_length=50)

    class Meta:
        managed = True
        db_table = 'internals_data_handling_task'


class PopulationStats(models.Model):
    population_stats_id = models.AutoField(primary_key=True)
    country = models.ForeignKey(Country, models.PROTECT)
    year = models.IntegerField()
    population = models.BigIntegerField()

    class Meta:
        managed = True
        db_table = 'population_stats'
        unique_together = (('country', 'year'),)


class BedStats(models.Model):
    bed_stats_id = models.AutoField(primary_key=True)
    country = models.ForeignKey(Country, models.PROTECT)
    year = models.IntegerField()
    beds_per_k = models.FloatField()

    class Meta:
        managed = True
        db_table = 'bed_stats'
        unique_together = (('country', 'year'),)


class NurseStats(models.Model):
    nurse_stats_id = models.AutoField(primary_key=True)
    country = models.ForeignKey(Country, models.PROTECT)
    year = models.IntegerField()
    nurses_per_k = models.FloatField()

    class Meta:
        managed = True
        db_table = 'nurse_stats'
        unique_together = (('country', 'year'),)
