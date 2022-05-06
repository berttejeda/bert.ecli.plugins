import argparse
import boto3

def parse_args():
    parser = argparse.ArgumentParser(description="List ec2 Instances by naming pattern")
    parser.add_argument('--aws-profile-name','-p', required=True)
    parser.add_argument('--aws-region','-r', default='us-east-1', required=False)
    parser.add_argument('--ec2-naming-pattern','-n', required=True)
    parser.add_argument('--verbose','-v', action='store_true', default=False)
    return parser.parse_known_args()

# CLI Args
args, unknown= parse_args()

ec2_instance_name_values = args.ec2_naming_pattern.split('|')
aws_profile_name = args.aws_profile_name
aws_region = args.aws_region

boto3.setup_default_session(profile_name=aws_profile_name)
ec2 = boto3.resource('ec2', region_name=aws_region)
filters = [{'Name':'tag:Name', 'Values':ec2_instance_name_values}]
instances = ec2.instances.filter(Filters=filters)

for instance in instances:
  instance_name = [t.get('Value') for t in instance.tags if t.get('Key') == 'Name'][0]
  print(f"Name: {instance_name}, Id: {instance.id}, State: {instance.state['Name']}")

ec2_snapshots = ec2.describe_snapshots()['Snapshots']
for snap in ec2_snapshots:
 print(snap)