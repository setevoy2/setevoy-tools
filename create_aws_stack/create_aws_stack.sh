#!/usr/bin/env bash

# read more options: 
# http://redsymbol.net/articles/unofficial-bash-strict-mode/

# instructs bash to immediately exit if any command [1] has a non-zero exit status
set -e

# prevents errors in a pipeline from being masked
set -o pipefail

HELP="\nUsed to create AWS CLoudFormation stack. \n\nUsage: \
\n\t-p: (mandatory) AWS CLI profile name for authorization \
\n\t-s: (mandatory)CloudFormation stack name to be created/updated \
\n\t-t: (mandatory) path to a template file \
\n"

[[ $# -lt 6 ]] && { echo -e "$HELP"; exit 1; }

# define and reset all values
PROFILE_NAME=
STACK_NAME=
TEMPLATE_FILE=

# global will be set from cf_stack_check_create_or_update(), just reset/declare here
# will contain "create" or "update" to chose action
CREATE_OR_UPDATE=

# link to CloudFormation stacks
CF_URL="https://eu-west-1.console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks?filter=active&tab=events"

while getopts "p:s:t:h" opt; do
    case $opt in
		p)
			# aws profile from ~/.aws/credentials
			PROFILE_NAME=$OPTARG
			;;
        s)
            STACK_NAME=$OPTARG
            ;;
        t)
            TEMPLATE_FILE=$OPTARG
            ;;
        h) echo -e "$HELP"
            ;;  
    esac
done

# all functions

cf_template_validate () {

    local profile=$1
    local template=$2
    aws cloudformation --profile $profile validate-template --template-body file://$template
}

cf_stack_check_create_or_update () {

    local profile=$1
    aws cloudformation --profile $profile describe-stacks --query 'Stacks[*].StackName' --output text
}

cf_stack_exec_create_or_update () {

    local profile=$1
    local stack_name=$2
    local template=$3
    local create_or_update=$4

	aws cloudformation --profile $profile $create_or_update-stack --stack-name $stack_name --template-body file://$template
}

# execution starts here

echo -e "\nValidating template $TEMPLATE_FILE...\n"
if cf_template_validate $PROFILE_NAME $TEMPLATE_FILE; then
    echo -e "\nTemplate OK"
else
    echo -e "\nERROR: can not validate template, fix erros and try again. Exit.\n"
    exit 1
fi

# cf_stack_check_create_or_update() will return all stacks in a AWS account as TEXT
# test[] below will check with regex =~ if the $STACK_NAME present in the output from the cf_stack_check_create_or_update()
echo -e "\nChecking if stack $STACK_NAME already present..."
if  [[ $(cf_stack_check_create_or_update $PROFILE_NAME) =~ $STACK_NAME ]]; then
    echo -e "\nStack $STACK_NAME found, preparing Stack Update.\n"
    CREATE_OR_UPDATE="update"
else
    echo -e "\nStack $STACK_NAME not found, running Stack Create.\n"
    CREATE_OR_UPDATE="create"
fi

echo -e "Starting AWS CloudFormation stack creation using:\n
AWS profile: $PROFILE_NAME
stack name: $STACK_NAME
template: $TEMPLATE_FILE
Stack exist: $([ $CREATE_OR_UPDATE = "create" ] && echo "False" || echo "True")
\n"

read -p "Are you sure to proceed? [y/n] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# this will execute command like:
# aws cloudformation --profile awscliprofilename create-stack --stack-name cfstackname --template-body file://template.json --parameters ParameterKey=AllowLocation,ParameterValue=0.0.0.0/0

# see arguments list for the cf_stack_exec_create_or_update() function:
#
#    local profile=$1
#    local stack_name=$2
#    local template=$3
#    local create_or_update=$4
#

echo -e "\nRunning create or update stack $STACK_NAME..."
if [[ $(cf_stack_exec_create_or_update $PROFILE_NAME $STACK_NAME $TEMPLATE_FILE $CREATE_OR_UPDATE) ]]; then
    echo -e "\nStack creation started. Use $CF_URL to check its status.\n"
else
    echo -e "\nSomething went wrong, use $CF_URL to check it for errors.\n"
fi
