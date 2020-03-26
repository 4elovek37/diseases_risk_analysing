from django.core.management.base import BaseCommand, CommandError
from django.core.management import call_command
from analyzer.models import InternalsDataHandlingTask


class Command(BaseCommand):
    help = 'Initiates handling of all scheduled tasks'

    def handle(self, *args, **options):
        tasks = InternalsDataHandlingTask.objects.all()

        for task in tasks:
            try:
                call_command(task.command_name)
            except Exception as e:
                self.stdout.write(self.style.WARNING('%s has thrown %s' % (task.task_name, e)))

        self.stdout.write('handle_tasks finished')