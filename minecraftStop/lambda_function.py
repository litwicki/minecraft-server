import boto3
from datetime import datetime
from pytz import timezone
pst = timezone('America/Los_Angeles')
time = datetime.now(pst)
region = 'us-east-1'
instances = ['i-0b96576b705bda04b']
ec2 = boto3.client('ec2', region_name=region)


def lambda_handler(event, context):
    ec2.stop_instances(InstanceIds=instances)
    print('minecraft.litwicki.app ' + str(instances) +
          ' shutdown at: ' + time.strftime("%Y-%m-%d %H:%M"))
