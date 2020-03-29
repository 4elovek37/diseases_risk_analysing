from django.core.management.base import BaseCommand, CommandError
from django.core.management import call_command
from analyzer.models import InternalsDataHandlingTask
from datetime import date


class Command(BaseCommand):
    help = 'Initiates handling of all scheduled tasks'

    def handle(self, *args, **options):
        today_date = date.today()

        tasks = InternalsDataHandlingTask.objects.all()
        for task in tasks:
            try:
                if task.last_update is None or (today_date - task.last_update).days >= task.frequency_days:
                    self.stdout.write("calling %s" % task.task_name)
                    call_command(task.command_name)
                    task.last_update = today_date
                    task.save()
            except Exception as e:
                self.stdout.write(self.style.WARNING('%s has thrown %s' % (task.task_name, e)))

        self.stdout.write('handle_tasks finished')