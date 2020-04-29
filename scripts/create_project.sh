#!/bin/bash

##User input
#echo "Enter AWS IAM User Access Key and Secret Key - IAM User should be granted administrator privileges"
#echo "Access Key:"
#read AWS_ACCESS_KEY
#echo "Secret Key:"
#read AWS_SECRET_KEY

##Parameters definition
AWS_PROFILE="hello-world-project" #AWS IAM profile to be used for creating resources on AWS. AWS IAM User should be granted administrator permissions
AWS_REGION="eu-west-1"
#echo -e "${AWS_ACCESS_KEY}\n${AWS_SECRET_KEY}\n${AWS_REGION}\n\n" > profile.txt
#aws configure --profile ${AWS_PROFILE} < profile.txt
#rm -f profile.txt
DOMAIN_NAME="hello-world.com" #FQDN for the application
DATE=$(date +%D-%H:%M:%S) #to be used for AWS Route53 Hosted Zone creation


#create AWS Route53 Hosted Zone
HOSTED_ZONE=$(aws route53 create-hosted-zone --name ${DOMAIN_NAME} --caller-reference ${DATE} --profile ${AWS_PROFILE} --output json)
HOSTED_ZONE_ID=$(echo "${HOSTED_ZONE}" | grep "\"Id\": \"/hostedzone/" | awk -F '/' '{print $3}' | awk -F '"' '{print $1}')
echo ${HOSTED_ZONE_ID}
