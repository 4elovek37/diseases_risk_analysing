from subprocess import call
from apscheduler.schedulers.blocking import BlockingScheduler

sched = BlockingScheduler()


@sched.scheduled_job('cron', hour=1)
def scheduled_job():
    call(['python', 'manage.py', 'handle_tasks'])


sched.start()
