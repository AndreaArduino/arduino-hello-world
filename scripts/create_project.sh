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
#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" #get directory of the script
#echo -e "${AWS_ACCESS_KEY}\n${AWS_SECRET_KEY}\n${AWS_REGION}\n\n" > ${DIR}/profile.txt
#aws configure --profile ${AWS_PROFILE} < ${DIR}/profile.txt
#rm -f ${DIR}/profile.txt
DOMAIN_NAME="hello-world.com" #FQDN for the application
DATE=$(date +%D-%H:%M:%S) #to be used for AWS Route53 Hosted Zone creation

##create AWS Route53 Hosted Zone
HOSTED_ZONE=$(aws route53 create-hosted-zone --name ${DOMAIN_NAME} --caller-reference ${DATE} --profile ${AWS_PROFILE} --output json)
HOSTED_ZONE_ID=$(echo "${HOSTED_ZONE}" | grep "\"Id\": \"/hostedzone/" | awk -F '/' '{print $3}' | awk -F '"' '{print $1}')
echo ${HOSTED_ZONE_ID}

##Create ACM SSL certificate
CERT_ARN=$(aws acm request-certificate --domain-name ${DOMAIN_NAME} --validation-method DNS --region ${AWS_REGION} --profile ${AWS_PROFILE} | awk -F '"' '{print $4}')
echo ${CERT_ARN}

##Validate ACM SSL certificate
sleep 5 #wait 5 seconds to guarantee ACM certificate creation process is completed
#get DNS cofiguration for validation
VALIDATION_NAME=$(aws acm describe-certificate --certificate-arn ${CERT_ARN} --profile ${AWS_PROFILE} --output json | grep "\"Name\":" | awk -F '"' '{print $4}')
VALIDATION_VALUE=$(aws acm describe-certificate --certificate-arn ${CERT_ARN} --profile ${AWS_PROFILE} --output json | grep "\"Value\":" | awk -F '"' '{print $4}')
echo ${VALIDATION_NAME}
echo ${VALIDATION_VALUE}
#Add DNS configuration to AWS Route53
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch '{"Comment":"AWS ACM SSL certificate validation","Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"'${VALIDATION_NAME}'","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"'${VALIDATION_VALUE}'"}]}}]}' --profile ${AWS_PROFILE}
ACM_VALIDATION_STATUS=$(aws acm describe-certificate --certificate-arn  ${CERT_ARN} --profile ${AWS_PROFILE} --output json | grep ValidationStatus | awk -F '"' '{print $4}')

#aws acm wait certificate-validated --certificate-arn ${CERT_ARN} --profile ${AWS_PROFILE}

while [[ "$ACM_VALIDATION_STATUS" == "PENDING_VALIDATION" ]];
do
    echo "ACM SSL certificate is still pending validation. Waiting..."
    ACM_VALIDATION_STATUS=$(aws acm describe-certificate --certificate-arn  ${CERT_ARN} --profile ${AWS_PROFILE} --output json | grep ValidationStatus | awk -F '"' '{print $4}')
    sleep 3
done
