from subprocess import call
from apscheduler.schedulers.blocking import BlockingScheduler

sched = BlockingScheduler()


@sched.scheduled_job('cron', hour=1)
def scheduled_job():
    print('Calling handle_tasks...')
    call(['python', './manage.py', 'handle_tasks'])
    print('Calling handle_tasks done')


sched.start()
