from subprocess import call
from apscheduler.schedulers.blocking import BlockingScheduler

sched = BlockingScheduler()

@sched.scheduled_job('interval', secondes=10)
def timed_job():
    print('This job is run every 10 secondes.')


@sched.scheduled_job('cron', hour=1)
def scheduled_job():
    call(['python', 'manage.py', 'handle_tasks'])


sched.start()
