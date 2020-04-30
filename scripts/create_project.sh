#!/bin/bash

##User input
#echo "Enter AWS IAM User Access Key and Secret Key - IAM User must be granted administrator privileges"
#echo "Access Key:"
#read AWS_ACCESS_KEY
#echo "Secret Key:"
#read AWS_SECRET_KEY

##Parameters definition
AWS_PROFILE="hello-world-project" #AWS IAM profile to be used for creating resources on AWS. AWS IAM User must be granted administrator permissions
AWS_REGION="eu-west-1"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" #get directory of the script
#echo -e "${AWS_ACCESS_KEY}\n${AWS_SECRET_KEY}\n${AWS_REGION}\n\n" > ${DIR}/profile.txt
#aws configure --profile ${AWS_PROFILE} < ${DIR}/profile.txt
#rm -f ${DIR}/profile.txt
DOMAIN_NAME="arduino-hello-world.com" #FQDN for the application
DATE=$(date +%D-%H:%M:%S) #to be used for AWS Route53 Hosted Zone creation
PROJECT="hello-world" #project name passed as parameter to AWS Cloudformation template
VPC_STACK_NAME=${PROJECT}"-vpc"
INFRA_STACK_NAME=${PROJECT}"-infra"
BASE_DIR=$(realpath $0)
BASE_DIR=$(dirname $BASE_DIR)
BASE_DIR=$(dirname $BASE_DIR)
VPC_CF_TEMPLATE=${BASE_DIR}"/cloudformation/vpc.json"
INFRA_CF_TEMPLATE=${BASE_DIR}"/cloudformation/infra.json"

##create AWS Route53 Hosted Zone
HOSTED_ZONE=$(aws route53 create-hosted-zone --name ${DOMAIN_NAME} --caller-reference ${DATE} --profile ${AWS_PROFILE} --output json)
HOSTED_ZONE_ID=$(echo "${HOSTED_ZONE}" | grep "\"Id\": \"/hostedzone/" | awk -F '/' '{print $3}' | awk -F '"' '{print $1}')
echo ${HOSTED_ZONE_ID}

##Create ACM SSL certificate
#CERT_ARN=$(aws acm request-certificate --domain-name ${DOMAIN_NAME} --validation-method DNS --region ${AWS_REGION} --profile ${AWS_PROFILE} | awk -F '"' '{print $4}')
#echo ${CERT_ARN}

##Validate ACM SSL certificate
#sleep 5 #wait 5 seconds to guarantee ACM certificate creation process is completed
#get DNS cofiguration for validation
#VALIDATION_NAME=$(aws acm describe-certificate --certificate-arn ${CERT_ARN} --profile ${AWS_PROFILE} --output json | grep "\"Name\":" | awk -F '"' '{print $4}')
#VALIDATION_VALUE=$(aws acm describe-certificate --certificate-arn ${CERT_ARN} --profile ${AWS_PROFILE} --output json | grep "\"Value\":" | awk -F '"' '{print $4}')
#echo ${VALIDATION_NAME}
#echo ${VALIDATION_VALUE}
#Add DNS configuration to AWS Route53
#aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch '{"Comment":"AWS ACM SSL certificate validation","Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"'${VALIDATION_NAME}'","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"'${VALIDATION_VALUE}'"}]}}]}' --profile ${AWS_PROFILE}
#ACM_VALIDATION_STATUS=$(aws acm describe-certificate --certificate-arn  ${CERT_ARN} --profile ${AWS_PROFILE} --output json | grep ValidationStatus | awk -F '"' '{print $4}')

#aws acm wait certificate-validated --certificate-arn ${CERT_ARN} --profile ${AWS_PROFILE}

#while [[ "${ACM_VALIDATION_STATUS}" == "PENDING_VALIDATION" ]];
#do
#    echo "ACM SSL certificate is still pending validation. Waiting..."
#    ACM_VALIDATION_STATUS=$(aws acm describe-certificate --certificate-arn  ${CERT_ARN} --profile ${AWS_PROFILE} --output json | grep ValidationStatus | awk -F '"' '{print $4}')
#    sleep 3
#done

##Create AWS Stacks
#VPC
aws cloudformation create-stack --stack-name ${VPC_STACK_NAME} --template-body file://${VPC_CF_TEMPLATE} --parameters ParameterKey=Project,ParameterValue=${PROJECT} --profile ${AWS_PROFILE} --region ${AWS_REGION}
VPC_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --output json | grep "StackStatus" | awk -F '"' '{print $4}')

while [[ "$VPC_STACK_STATUS" != "CREATE_COMPLETE" ]];
do
    echo "AWS CloudFormation stack ${VPC_STACK_NAME} still creating..."
    VPC_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --output json | grep "StackStatus" | awk -F '"' '{print $4}')
    sleep 3
done
echo "AWS CloudFormation stack ${VPC_STACK_NAME} created."

#Infra
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com --profile ${AWS_PROFILE} #this command is needed in order to create the ECS service-linked IAM Role required by ECS Service to manage AWS Load Balancer
aws cloudformation create-stack --stack-name ${INFRA_STACK_NAME} --template-body file://${INFRA_CF_TEMPLATE} --parameters ParameterKey=Project,ParameterValue=${PROJECT} ParameterKey=Route53HostedZoneID,ParameterValue=${HOSTED_ZONE_ID} --profile ${AWS_PROFILE} --region ${AWS_REGION} --capabilities CAPABILITY_NAMED_IAM
