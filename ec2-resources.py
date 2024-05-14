#!/usr/bin/env python3

import boto3
import botocore.config
import botocore.exceptions
import concurrent.futures
import datetime

def list_ec2_instances(ec2_client):
    try:
        instances = ec2_client.describe_instances()
        for reservation in instances["Reservations"]:
            for instance in reservation["Instances"]:
                print(f"EC2 Instance ID: {instance['InstanceId']}")
                print(f"Instance Type: {instance['InstanceType']}")
                print(f"State: {instance['State']['Name']}")
                print()
    except botocore.exceptions.ClientError as e:
        print(f"Error listing EC2 instances: {e}")

def list_rds_instances(rds_client):
    try:
        instances = rds_client.describe_db_instances()
        for instance in instances["DBInstances"]:
            print(f"RDS Instance ID: {instance['DBInstanceIdentifier']}")
            print(f"DB Engine: {instance['Engine']}")
            print(f"DB Instance Class: {instance['DBInstanceClass']}")
            print()
    except botocore.exceptions.ClientError as e:
        print(f"Error listing RDS instances: {e}")

def main():
    try:
        # Initialize Boto3 session with AWS credentials
        session = boto3.Session(
            aws_access_key_id='your-access-key-id',
            aws_secret_access_key='your-secret-access-key',
            aws_session_token='your-session-token'  # Only required for temporary credentials
        )

        # Create clients for EC2 and RDS
        ec2_client = session.client("ec2")
        rds_client = session.client("rds")

        # List EC2 instances
        print("Listing EC2 Instances:")
        list_ec2_instances(ec2_client)

        # List RDS instances
        print("Listing RDS Instances:")
        list_rds_instances(rds_client)

    except botocore.exceptions.NoCredentialsError:
        print("No AWS credentials found. Please provide valid AWS credentials.")
    except botocore.exceptions.ClientError as e:
        print(f"AWS error: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()

