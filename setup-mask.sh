#!/bin/bash
#
# setup_mask.sh
# Created: Paulo Victor Maluf - 09/2019
# Updated for Hispanic Countries by: Javier Barthe - 07/2021
#
#   No utiliza ningun parametro, todo es tomado desde CFG File
#   Ejemplo de Ejecución: ./setup-mask.sh
# Changelog:
#
# Date       Author              Description
# ---------- ------------------- ----------------------------------------------------
#  07/2021    Javier Barthe       Primera versión con CFG File. Sin parametros.
#====================================================================================

################################
# CARGA VARIABLES DE CFG       #
################################
while read line
do
  var=$(echo $line | awk -F= '{print $1}')
  value=$(echo $line | awk -F= '{print $2}')
  export "$var"="$value"
done < <(cat ./setup.cfg |grep -v "#")
################################
# CONFIGURA CURL Y URL A HTTPS #
################################
case $HTTPS in
  "TRUE")
   CURL="curl -k"
   MASKING_ENGINE="https://${MASKING_ENGINE}/masking/api"
    ;;
  "FALSE")
   CURL="curl"
   MASKING_ENGINE="http://${MASKING_ENGINE}/masking/api"
    ;;
esac
################################
# FUNCIONES                    #
################################
help()
{
  head -10 $0 | tail -31
  exit
}

log (){
  echo -ne "[`date '+%d%m%Y %T'`] $1" | tee -a ${LAST}
}

# Check if $1 is equal to 0. If so print out message specified in $2 and exit.
check_empty() {
    if [ $1 -eq 0 ]; then
        echo $2
        exit 1
    fi
}

# Check if $1 is an object and if it has an 'errorMessage' specified. If so, print the object and exit.
check_error() {
    # ${JQ} returns a literal null so we have to check againt that...
    if [ "$(echo "$1" | ${JQ} -r 'if type=="object" then .errorMessage else "null" end')" != 'null' ]; then
        echo $1
        exit 1
    fi
}

# Login and set the correct $AUTH_HEADER.
login() {
echo "* Accediendo al Masking Engine (login)..."
LOGIN_RESPONSE=$($CURL -s -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- $MASKING_ENGINE/login <<EOF
{
    "username": "$USERNAME",
    "password": "$PASSWORD"
}
EOF
)
    check_error "$LOGIN_RESPONSE"
    TOKEN=$(echo $LOGIN_RESPONSE | ${JQ} -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
}

create_application(){
APPLICATIONNAME=${1}

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/applications <<EOF
{
  "applicationName": "${APPLICATIONNAME}"
}
EOF
}
# create environment for app 1 only, if needed for another specific app the app id needs to be sent on body for that first is needed to look for the app id or get_appid
create_environment(){
ENVIRONMENTNAME=${1}

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/environments <<EOF
{
  "environmentName": "${ENVIRONMENTNAME}",
  "applicationId": "1",
  "purpose": "MASK"
}
EOF
}

get_environmentid(){
ENVIRONMENTNAME=${1}
RESPONSE=$($CURL -s -X GET -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' ${MASKING_ENGINE}/environments)
check_error ${RESPONSE}

ENVIRONMENTID=$(echo ${RESPONSE} | ${JQ} -r ".responseList[] | select(.environmentName == \"${ENVIRONMENTNAME}\") | .environmentId")

echo ${ENVIRONMENTID}
}

add_expression(){
DOMAIN=${1}
EXPRESSNAME=${2}
REGEXP=${3}
DATALEVEL=${4}

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/profile-expressions <<EOF
{
  "domainName": "${DOMAIN}",
  "expressionName": "${EXPRESSNAME}",
  "regularExpression": "${REGEXP}",
  "dataLevelProfiling": ${DATALEVEL}
}
EOF
}

add_domain(){
NEW_DOMAIN=${1}
CLASSIFICATION=${2}
ALGORITHM=${3}

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/domains <<EOF
{
  "domainName": "${NEW_DOMAIN}",
  "classification": "${CLASSIFICATION}",
  "defaultAlgorithmCode": "${ALGORITHM}"
}
EOF
}

add_profileset(){
PROFILENAME=${1}
EXPRESSID=${2}

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/profile-sets <<EOF
{
  "profileSetName": "${PROFILENAME}",
  "profileExpressionIds": [ ${EXPRESSID} ]
}
EOF
}

create_connection(){
CONNECTORNAME=${1}
DATABASETYPE=${2}
ENVIRONMENTID=${3}
HOST=${4}
PORT=${5}
SID=${6}
USERNAME=${7}
PASSWORD=${8}
SCHEMANAME=${9}

[ "${DATABASETYPE}." == "ORACLE." ] && SID="\"sid\": \"${SID}\"," || SID="\"databaseName\": \"${SID}\","

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/database-connectors <<EOF
{
  "connectorName": "${CONNECTORNAME}",
  "databaseType": "${DATABASETYPE}",
  "environmentId": ${ENVIRONMENTID},
  "host": "${HOST}",
  "password": "${PASSWORD}",
  "port": ${PORT},
  "schemaName": "${SCHEMANAME}",
  ${SID}
  "username": "${USERNAME}"
}
EOF
}

get_connectorid(){
CONNECTORNAME=${1}
CONNECTORLIST=$($CURL -s -X GET -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' ${MASKING_ENGINE}/database-connectors)
CONNECTORID=$(echo ${CONNECTORLIST} | ${JQ} -r ".responseList[] | select(.connectorName == \"${CONNECTORNAME}\") | .databaseConnectorId")
echo ${CONNECTORID}
}

create_ruleset(){
RULESETNAME=${1}
DATABASECONNECTORID=${2}

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/database-rulesets <<EOF
{
  "rulesetName": "${RULESETNAME}",
  "databaseConnectorId": ${DATABASECONNECTORID}
}
EOF
}

get_rulesetid(){
  RULESETNAME=${1}
  RET=$($CURL -s -X GET -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' ${MASKING_ENGINE}/database-rulesets)
  check_error ${RET}
  RESULTSETID=$(echo ${RET} | ${JQ} -r ".responseList[] | select(.rulesetName == \"${RULESETNAME}\") | .databaseRulesetId")
  echo ${RESULTSETID}
}

create_tablemetadata(){
TABLENAME=${1}
RULESETID=${2}
DATABASETYPE=${3}

[ "${DATABASETYPE}." == "ORACLE." ] && ROWID="\"keyColumn\": \"ROWID\","

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/table-metadata <<EOF
{
  "tableName": "${TABLENAME}",
  ${ROWID}
  "rulesetId": ${RULESETID}
}
EOF
}

get_tables(){
  CONNECTORID=${1}
  RET=$($CURL -s -X GET -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' ${MASKING_ENGINE}/database-connectors/${CONNECTORID}/fetch)
  check_error ${RET}
  TABLES=$(echo ${RET} | ${JQ} ".[]" | xargs)
  echo ${TABLES}
}

get_profilesetid(){
PROFILESETNAME=${1}

RESPONSE=$($CURL -s -X GET -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' ${MASKING_ENGINE}/profile-sets)
check_error ${RESPONSE}
PROFILESETID=$(echo ${RESPONSE} | ${JQ} -r ".responseList[] | select(.profileSetName == \"${PROFILESETNAME}\") | .profileSetId")

echo ${PROFILESETID}
}

create_profilejob(){
PROFILEJOBNAME=${1}
PROFILESETID=${2}
RULESETID=${3}

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/profile-jobs <<EOF
{
  "jobName": "${PROFILEJOBNAME}",
  "profileSetId": ${PROFILESETID},
  "rulesetId": ${RULESETID},
  "feedbackSize": 50000,
  "minMemory": 1024,
  "maxMemory": 4096,
  "numInputStreams": 5
}
EOF
}

create_maskjob(){
MASKJOBNAME=${1}
RULESETID=${2}

$CURL -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/masking-jobs <<EOF
{
  "jobName": "${MASKJOBNAME}",
  "rulesetId": ${RULESETID},
  "feedbackSize": 100000,
  "onTheFlyMasking": false,
  "databaseMaskingOptions": {
    "batchUpdate": true,
    "commitSize": 50000,
    "dropConstraints": false,
    "minMemory": 1024,
    "maxMemory": 4096,
    "numInputStreams": 5
  }
}
EOF
}

################################
# ARGPARSER                    #
################################
# Verifica se foi passado algum parametro
[ $1 =="-h" ] || { help ; exit 1 ; }

# Verifica se o ${JQ} esta instalado
if [ "$(uname -s)." == "Linux." ] 
  then 
    JQ="./bin/jq"
elif [ "$(uname -s)." == "Darwin." ] 
  then
    JQ="./bin/jq-osx"
fi
    
[ -x "${JQ}" ] || { echo "jq not found. Please install 'jq' package and try again." ; exit 1 ; }

# Tratamento dos Parametros
#for arg
#do
#    delim=""
#    case "$arg" in
#    #translate --gnu-long-options to -g (short options)
#      --profile-name)         args="${args}-p ";;
#      --application-name)     args="${args}-a ";;
#      --environment-name)     args="${args}-e ";;
#      --expressions-file)     args="${args}-f ";;
#      --domains-file)         args="${args}-d ";;
#      --connection-file)      args="${args}-c ";;
#      --ruleset-file)         args="${args}-r ";;
#      --masking-engine)       args="${args}-m ";;
#      --help)                 args="${args}-h ";;
#      #pass through anything else
#      *) [[ "${arg:0:1}" == "-" ]] || delim="\""
#         args="${args}${delim}${arg}${delim} ";;
#    esac
#done
#
#eval set -- $args
#
#while getopts ":hp:e:d:m:c:r:a:f:" PARAMETRO
#do
#    case $PARAMETRO in
#        h) help;;
#        p) PROFILENAME=${OPTARG[@]};;
#        a) APPLICATIONNAME=${OPTARG[@]};;
#        e) ENVIRONMENTNAME=${OPTARG[@]};;
#        f) EXPRESSFILE=${OPTARG[@]};;
#        d) DOMAINSFILE=${OPTARG[@]};;
#        c) CONNECTIONFILE=${OPTARG[@]};;
#        r) RULESETFILE=${OPTARG[@]};;
#        m) MASKING_ENGINE=${OPTARG[@]};;
#        :) echo "Option -$OPTARG requires an argument."; exit 1;;
#        *) echo $OPTARG is an unrecognized option ; echo $USAGE; exit 1;;
#    esac
#done

################################
# MAIN                         #
################################
if [ ${MASKING_ENGINE} ]
then
    # Login on Masking Engine
    login

    if [ ${APPLICATIONNAME} ]
    then
        # Create masking application
        log "Creando Aplicación ${APPLICATIONNAME}...\n"
        ret=$(create_application ${APPLICATIONNAME})
    fi

    if [ ${ENVIRONMENTNAME} ]
    then
        # Create masking environment 
        log "Creando Entorno ${ENVIRONMENTNAME}...\n"
        ret=$(create_environment ${ENVIRONMENTNAME})
    fi
    
    if [ ${EXPRESSFILE} ] && [ ${DOMAINSFILE} ] && [ $PAIS = "TODOS" ]
    then
        # Create Domains 
        log "Creando Dominio ${NEW_DOMAIN}...\n"
        while IFS=\; read -r NEW_DOMAIN CLASSIFICATION ALGORITHM
        do
          if [[ ! ${NEW_DOMAIN} =~ "#" ]]
            then
              ret=$(add_domain ${NEW_DOMAIN} ${CLASSIFICATION} ${ALGORITHM})
          fi
        done < ${DOMAINSFILE}

        # Create Expressions 
        log "Creando Expresiones: \n"
        while IFS=\; read -r EXPRESSNAME DOMAIN DATALEVEL REGEXP
        do
          if [[ ! ${EXPRESSNAME} =~ "#" ]]
          then
              log "* ${EXPRESSNAME}\n" 0
              ret=$(add_expression ${DOMAIN} ${EXPRESSNAME} ${REGEXP} ${DATALEVEL} | tee -a $$.tmp)
          fi
        done < ${EXPRESSFILE}
      
        # Get Created Expression Ids
        # 7 - Creditcard
        # 8 - Creditcard
        # 11 - Email
        # 22 - Creditcard Data
        # 23 - Email Data
        # 49 - Ip Address Data
        # 50 - Ip Address
        EXPRESSID=$(egrep -o '"profileExpressionId":[0-9]+' $$.tmp | cut -d: -f2 | xargs | sed 's/ /,/g')
        EXPRESSID="7,8,11,22,23,49,50,${EXPRESSID}"
        
        # Add ProfileSet
        log "Agregando Expresiones ids ${EXPRESSID} en ${PROFILENAME}...\n"
        ret=$(add_profileset "${PROFILENAME}" "${EXPRESSID}")

        # remove tmpfile
        rm -f $$.tmp
    fi
fi   
#  if [ ${CONNECTIONFILE} ] && [ ${ENVIRONMENTNAME} ] && [ ${PROFILENAME} ]
#     then 
#       # Create connection environment
#       log "Getting environment id for ${ENVIRONMENTNAME}...\n"
#       ENVIRONMENTID=$(get_environmentid ${ENVIRONMENTNAME})
#
#       while IFS=\; read -r CONNECTORNAME DATABASETYPE HOST PORT SID USERNAME PASSWORD SCHEMANAME
#       do
#         if [[ ! ${CONNECTORNAME} =~ "#" ]]
#           then
#             log "Creando connection ${CONNECTORNAME} for environment ${ENVIRONMENTNAME}...\n"
#             ret=$(create_connection ${CONNECTORNAME} ${DATABASETYPE} ${ENVIRONMENTID} ${HOST} ${PORT} ${SID} ${USERNAME} ${PASSWORD} ${SCHEMANAME})
#             check_error ${ret}
#
#             log "Getting connector id for ${CONNECTORNAME}...\n"
#             CONNECTORID=$(get_connectorid ${CONNECTORNAME})
#
#             # Create RuleSet 
#             RULESETNAME="RS_${CONNECTORNAME}"
#             log "Creando ruleset ${RULESETNAME}...\n"
#             ret=$(create_ruleset ${RULESETNAME} ${CONNECTORID})
#             check_error ${ret}
#
#             log "Getting ruleset id for ${RULESETNAME}\n"
#             RULESETID=$(get_rulesetid ${RULESETNAME})
#
#             log "Getting tables from ${CONNECTORNAME} schema...\n"
#             TABLES=$(get_tables ${CONNECTORID})
#
#             log "Creando metadata for table:\n"
#             for TABLE in ${TABLES}
#             do
#               log "* ${TABLE}\n"
#               ret=$(create_tablemetadata ${TABLE} ${RULESETID} ${DATABASETYPE})
#               check_error ${ret}
#             done
#
#             # Create Job Profile
#             log "Getting profileset id ...\n"
#             PROFILESETID=$(get_profilesetid ${PROFILENAME})
#           
#             log "Creando profile job PR_JOB_${CONNECTORNAME}...\n"
#             ret=$(create_profilejob "PR_JOB_${CONNECTORNAME}" ${PROFILESETID} ${RULESETID})
#             check_error ${ret}
#
#             # Create Masking Job
#             log "Creando masking job MSK_JOB_${CONNECTORNAME}...\n"
#             ret=$(create_maskjob "MSK_JOB_${CONNECTORNAME}" ${RULESETID})
#             check_error ${ret}
#         fi
#       done < ${CONNECTIONFILE}
#   fi