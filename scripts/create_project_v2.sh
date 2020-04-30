#!/bin/bash

##User input
echo "Enter AWS IAM User Access Key and Secret Key - IAM User must be granted administrator privileges before the invokation of the script"
echo "Access Key:"
read AWS_ACCESS_KEY
echo "Secret Key:"
read AWS_SECRET_KEY

##Parameters definition
AWS_PROFILE="hello-world-project" #AWS IAM profile to be used for creating resources on AWS. AWS IAM User must be granted administrator privileges before the invokation of the script
AWS_REGION="eu-west-1" #AWS region for resources creation
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" #get directory of the script
echo -e "${AWS_ACCESS_KEY}\n${AWS_SECRET_KEY}\n${AWS_REGION}\n\n" > ${DIR}/profile.txt #save IAM User credentials on temporary file
aws configure --profile ${AWS_PROFILE} < ${DIR}/profile.txt #read credentials from file and create AWS profile - it will be used in all subsequent AWS API calls
rm -f ${DIR}/profile.txt #remove temporary file
PROJECT="hello-world" #project name passed as parameter to AWS Cloudformation template
VPC_STACK_NAME=${PROJECT}"-vpc" #name of the AWS CloudFormation stack for VPC
INFRA_STACK_NAME=${PROJECT}"-infra" #name of the AWS CloudFormation stack for infra
#Get base dir of the git repo
BASE_DIR=$(realpath $0)
BASE_DIR=$(dirname $BASE_DIR)
BASE_DIR=$(dirname $BASE_DIR)
VPC_CF_TEMPLATE=${BASE_DIR}"/cloudformation/vpc.json" #name of the pre-compiled AWS CloudFormation template for VPC stack
INFRA_CF_TEMPLATE=${BASE_DIR}"/cloudformation/infra.json" #name of the pre-compiled AWS CloudFormation template for infra stack
SSL_CERT_PUB=${BASE_DIR}"/ssl/arduino-hello-world-com.crt" #name of the SSL self signed certificate file - public key
SSL_CERT_KEY=${BASE_DIR}"/ssl/arduino-hello-world-com.key" #name of the SSL self signed certificate file - private key

##Create AWS Stacks
#VPC
aws cloudformation create-stack --stack-name ${VPC_STACK_NAME} --template-body file://${VPC_CF_TEMPLATE} --parameters ParameterKey=Project,ParameterValue=${PROJECT} --profile ${AWS_PROFILE} --region ${AWS_REGION}
VPC_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --output json | grep "StackStatus" | awk -F '"' '{print $4}')

#Wait until AWS CloudFormation VPC stack is completed
while [[ "$VPC_STACK_STATUS" != "CREATE_COMPLETE" ]];
do
    echo "AWS CloudFormation stack ${VPC_STACK_NAME} still creating..."
    VPC_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --output json | grep "StackStatus" | awk -F '"' '{print $4}')
    sleep 3
done
echo "AWS CloudFormation stack ${VPC_STACK_NAME} created."

#Infra
CERT_ARN=$(aws acm import-certificate --certificate file://${SSL_CERT_PUB} --private-key file://${SSL_CERT_KEY} --profile ${AWS_PROFILE} --region ${AWS_REGION} --output json | awk -F '"' '{print $4}') #import self signed SSL certificate - stored under ssl directive - into AWS ACM
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com --profile ${AWS_PROFILE} #this command is needed in order to create the ECS service-linked IAM Role required by ECS Service to manage AWS Load Balancer
aws cloudformation create-stack --stack-name ${INFRA_STACK_NAME} --template-body file://${INFRA_CF_TEMPLATE} --parameters ParameterKey=Project,ParameterValue=${PROJECT} ParameterKey=SSLCertificateALB,ParameterValue="'${CERT_ARN}'" --profile ${AWS_PROFILE} --region ${AWS_REGION} --capabilities CAPABILITY_NAMED_IAM
