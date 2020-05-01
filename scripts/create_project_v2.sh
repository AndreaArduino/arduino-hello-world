#!/bin/bash

##Parameters definition
PROJECT="hello-world" #project name
AWS_REGION="eu-west-1" #AWS region for resources creation
SCRIPT_PATH=$(realpath $0) #Get absolute path of the script
SCRIPT_DIR=$(dirname ${SCRIPT_PATH}) #Get directory of the script
BASE_DIR=$(dirname ${SCRIPT_DIR}) #Get directory of the git repo
VPC_STACK_NAME=${PROJECT}"-vpc" #name of the AWS CloudFormation stack for VPC
INFRA_STACK_NAME=${PROJECT}"-infra" #name of the AWS CloudFormation stack for infra
VPC_CF_TEMPLATE=${BASE_DIR}"/cloudformation/vpc.json" #name of the pre-compiled AWS CloudFormation template for VPC stack
INFRA_CF_TEMPLATE=${BASE_DIR}"/cloudformation/infra.json" #name of the pre-compiled AWS CloudFormation template for infra stack
SSL_CERT_PUB=${BASE_DIR}"/ssl/arduino-hello-world-com.crt" #name of the SSL self signed certificate file - public key
SSL_CERT_KEY=${BASE_DIR}"/ssl/arduino-hello-world-com.key" #name of the SSL self signed certificate file - private key
AWS_PROFILE=${PROJECT}"-project" #AWS IAM profile to be used for creating resources on AWS



##User input
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
echo "AWS IAM User - creation of local profile to be used with AWS CLI"
echo -e "${RED}IAM User must be granted administrator privileges before the invokation of the script"
echo -e "${NC}Press \"yes\" to continue, \"no\" to abort [yes/no]: "
read CONFIRM
if [[ "${CONFIRM}" == "yes" ]]; then
    echo -e "${NC}Enter AWS IAM User Access Key and Secret Key"
    echo "Access Key:"
    read AWS_ACCESS_KEY
    echo "Enter Secret Key:"
    read AWS_SECRET_KEY
elif [[ "${CONFIRM}" == "no" ]] ; then
    echo -e "${RED}Aborting. Please create AWS IAM User with administrator privileges and run me again."
    exit 1
else
    echo -e "${RED}Value not valid. Aborting script."
    exit 1
fi



##AWS IAM User - local profile creation
echo -e "${AWS_ACCESS_KEY}\n${AWS_SECRET_KEY}\n${AWS_REGION}\n\n" > ${BASE_DIR}/profile.txt #save IAM User credentials on temporary file
aws configure --profile ${AWS_PROFILE} < ${BASE_DIR}/profile.txt #read credentials from file and create AWS profile - it will be used in all subsequent AWS API calls
RET=$? #get status of previous command to check it
rm -f ${BASE_DIR}/profile.txt #remove temporary file
if [ ${RET} -ne 0 ]; then
    echo -e "${RED}AWS local profile creation failed. Aborting."
    exit 1
fi



##Create AWS Stacks

#VPC
aws cloudformation create-stack --stack-name ${VPC_STACK_NAME} --template-body file://${VPC_CF_TEMPLATE} --parameters ParameterKey=Project,ParameterValue=${PROJECT} --profile ${AWS_PROFILE} --region ${AWS_REGION}
RET=$? #get status of previous command to check it
if [ ${RET} -ne 0 ]; then
    echo -e "${RED}AWS CloudFormation stack ${VPC_STACK_NAME} stack creation failed. Aborting."
    exit 1
fi



#Wait until AWS CloudFormation VPC stack is completed
MAX_RETRY=400 #define max time to wait - associated with sleep time SLEEP_TIME - for AWS CloudFormation stack to be created
SLEEP_TIME=3 #define max time to wait - associated with max retry MAX_RETRY - for AWS CloudFormation stack to be created
RETRY_COUNTER=0 #counter for tracking time to wait for AWS CloudFormation stack to be created
VPC_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --output json | grep "StackStatus" | awk -F '"' '{print $4}')
while [[ "${VPC_STACK_STATUS}" != "CREATE_COMPLETE" ]] && [[ ${RETRY_COUNTER} -lt ${MAX_RETRY} ]]
do
    VPC_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --output json | grep "StackStatus" | awk -F '"' '{print $4}')
    case ${VPC_STACK_STATUS} in
        CREATE_FAILED)
            echo -e "${RED}AWS CloudFormation stack ${VPC_STACK_NAME} stack creation failed. Aborting and cleaning resources."
            aws cloudformation delete-stack --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
            exit 1
            ;;
        ROLLBACK_COMPLETE)
            echo -e "${RED}AWS CloudFormation stack ${VPC_STACK_NAME} stack creation failed. Aborting and cleaning resources."
            aws cloudformation delete-stack --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
            exit 1
            ;;
        ROLLBACK_FAILED)
            echo -e "${RED}AWS CloudFormation stack ${VPC_STACK_NAME} stack creation failed. Aborting and cleaning resources."
            aws cloudformation delete-stack --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
            exit 1
            ;;
        ROLLBACK_IN_PROGRESS)
            echo -e "${RED}AWS CloudFormation stack ${VPC_STACK_NAME} stack creation failed. Aborting and cleaning resources."
            aws cloudformation delete-stack --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
            exit 1
            ;;
        CREATE_IN_PROGRESS)
            echo -e "${NC}AWS CloudFormation stack ${VPC_STACK_NAME} still creating..."
            RETRY_COUNTER=$((RETRY_COUNTER+1))
            sleep ${SLEEP_TIME}
            ;;
        CREATE_COMPLETE)
            echo -e "${GREEN}AWS CloudFormation stack ${VPC_STACK_NAME} created."
            ;;
    esac
done
if [ ${RETRY_COUNTER} -eq ${MAX_RETRY} ]; then
    echo -e "${RED}AWS CloudFormation stack ${VPC_STACK_NAME} stack creation failed. Aborting and cleaning resources."
    aws cloudformation delete-stack --stack-name ${VPC_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
    exit 1
fi



#Infra
CERT_ARN=$(aws acm import-certificate --certificate file://${SSL_CERT_PUB} --private-key file://${SSL_CERT_KEY} --profile ${AWS_PROFILE} --region ${AWS_REGION} --output json | awk -F '"' '{print $4}') #import self signed SSL certificate - stored under ssl directive - into AWS ACM
aws iam list-roles --profile ${AWS_PROFILE} --output json | grep RoleName | grep AWSServiceRoleForECS #check if ECS service-linked IAM Role already exists
RET=$?
if [ ${RET} -ne 0 ]; then #if it does not exists create it
    aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com --profile ${AWS_PROFILE} #create the ECS service-linked IAM Role required by ECS Service to manage AWS Load Balancer
fi
aws cloudformation create-stack --stack-name ${INFRA_STACK_NAME} --template-body file://${INFRA_CF_TEMPLATE} --parameters ParameterKey=Project,ParameterValue=${PROJECT} ParameterKey=SSLCertificateALB,ParameterValue="'${CERT_ARN}'" --profile ${AWS_PROFILE} --region ${AWS_REGION} --capabilities CAPABILITY_NAMED_IAM
RET=$? #get status of previous command to check it
if [ ${RET} -ne 0 ]; then
    echo -e "${RED}AWS CloudFormation stack ${INFRA_STACK_NAME} stack creation failed. Aborting."
    exit 1
fi



#Wait until AWS CloudFormation infra stack is completed
MAX_RETRY=400 #define max time to wait - associated with sleep time SLEEP_TIME - for AWS CloudFormation stack to be created
SLEEP_TIME=3 #define max time to wait - associated with max retry MAX_RETRY - for AWS CloudFormation stack to be created
RETRY_COUNTER=0 #counter for tracking time to wait for AWS CloudFormation stack to be created
INFRA_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${INFRA_STACK_NAME} --profile ${AWS_PROFILE} --output json | grep "StackStatus" | awk -F '"' '{print $4}')
while [[ "${INFRA_STACK_STATUS}" != "CREATE_COMPLETE" ]] && [[ ${RETRY_COUNTER} -lt ${MAX_RETRY} ]]
do
    INFRA_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${INFRA_STACK_NAME} --profile ${AWS_PROFILE} --output json | grep "StackStatus" | awk -F '"' '{print $4}')
    case ${INFRA_STACK_STATUS} in
        CREATE_FAILED)
            echo -e "${RED}AWS CloudFormation stack ${INFRA_STACK_NAME} stack creation failed. Aborting and cleaning resources."
            aws cloudformation delete-stack --stack-name ${INFRA_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
            exit 1
            ;;
        ROLLBACK_COMPLETE)
            echo -e "${RED}AWS CloudFormation stack ${INFRA_STACK_NAME} stack creation failed. Aborting and cleaning resources."
            aws cloudformation delete-stack --stack-name ${INFRA_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
            exit 1
            ;;
        ROLLBACK_FAILED)
            echo -e "${RED}AWS CloudFormation stack ${INFRA_STACK_NAME} stack creation failed. Aborting and cleaning resources."
            aws cloudformation delete-stack --stack-name ${INFRA_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
            exit 1
            ;;
        ROLLBACK_IN_PROGRESS)
            echo -e "${RED}AWS CloudFormation stack ${INFRA_STACK_NAME} stack creation failed. Aborting and cleaning resources."
            aws cloudformation delete-stack --stack-name ${INFRA_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
            exit 1
            ;;
        CREATE_IN_PROGRESS)
            echo -e "${NC}AWS CloudFormation stack ${INFRA_STACK_NAME} still creating..."
            RETRY_COUNTER=$((RETRY_COUNTER+1))
            sleep ${SLEEP_TIME}
            ;;
        CREATE_COMPLETE)
            echo -e "${GREEN}AWS CloudFormation stack ${INFRA_STACK_NAME} created."
            ;;
    esac
done
if [ ${RETRY_COUNTER} -eq ${MAX_RETRY} ]; then
    echo -e "${RED}AWS CloudFormation stack ${INFRA_STACK_NAME} stack creation failed. Aborting and cleaning resources."
    aws cloudformation delete-stack --stack-name ${INFRA_STACK_NAME} --profile ${AWS_PROFILE} --region ${AWS_REGION}
    exit 1
fi



##Output ELB DNS
ELB_DNS=$(aws elbv2 describe-load-balancers --names ${PROJECT}"-alb" --profile ${AWS_PROFILE} --region ${AWS_REGION} --output json | grep DNSName | awk -F '"' '{print $4}')
echo -e "${GREEN}You can test the application at the following urls via browser or curl command:"
echo -e "${GREEN}https://${ELB_DNS}/hello"
echo -e "${GREEN}http://${ELB_DNS}/hello"
echo -e "${GREEN}curl -L -k https://${ELB_DNS}/hello -vvv"
echo -e "${GREEN}curl -L -k http://${ELB_DNS}/hello -vvv"
