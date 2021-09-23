//DELPHIX AUTOMATION
import groovy.json.JsonSlurperClassic

String curl = "C://curl//curl.exe"

ArrayList dbase=["cob_ahorros_his", "adminproceso","cob_ahorros","cob_ahorros_his","cob_atc","cob_atm","cob_bcradgi","cob_bcradgi_his","cob_cartera","cob_cartera_his","cob_comext","cob_concent","cob_concent_his","cob_conta","cob_conta_his","cob_credito","cob_credito_his","cob_cuentas","cob_cuentas_his","cob_custodia","cob_datanet","cob_distrib","cob_externos","cob_jubi","cob_jubi_his","cob_mcambios","cob_pfijo","cob_reca","cob_reca_his","cob_remesas","cob_remesas_his","cob_rewards","cob_riesgo","cob_seguros","cob_tramites","cobis","db_delphix","firmas"]

String token
def conector

def obtenerToken(def USERDB, def USERPASS, String curl) {
    def authtoken
    def proc
    dir('tempJson'){
        writeFile file: 'jsonAuth.json', text: """{
  "username": "${USERDB}",
  "password": "${USERPASS}"
}"""
        String procString = """@$curl -s -X POST -H "Content-Type: application/json" -H "Accept: application/json" -d @jsonAuth.json http://10.99.73.119/masking/api/login"""
        echo(procString)
        proc = bat(returnStdout: true, script: procString, returnStatus: false)
        def outputJson = new groovy.json.JsonSlurperClassic().parseText("$proc")
        authtoken = (outputJson.Authorization).toString()
        deleteDir()
    }
    return authtoken
}

def CallApiDelphix(String apiToken, String apiData, String apiOption, String curl){
    String proc
    dir('tempJson'){
        echo 'Ingreso callApiDelphix'
        writeFile file: 'jsonData.json', text: "${apiData}"
        echo 'File ready'
        String procString = """@$curl -s -X POST --header "Content-Type: application/json" --header "Authorization: ${apiToken}" -d @jsonData.json http://10.99.73.119/masking/api/database-${apiOption}"""
        echo(procString)
        proc = (bat(returnStdout: true, script: procString, returnStatus: false)).toString()
        echo proc
        deleteDir()
    }
    return proc
}

def generarConector(def USERDB, def USERPASS, def baseName, def apiToken, def curl) {
    String apiData = """{
  "connectorName": "CON-${baseName}",
  "databaseType": "SYBASE",
  "environmentId": 3,
  "databaseName": "${baseName}",
  "host": "bhhdasbue006",
  "port": 7100,
  "schemaName": "dbo",
  "username": "${USERDB}",
  "password": "Hola2019*",
  "kerberosAuth": false,
  "enableLogger": false
}"""

    echo 'Termino apiData'
    String respuesta=CallApiDelphix(apiToken, apiData, "connectors", curl)
    def outputJson = new groovy.json.JsonSlurperClassic().parseText("$respuesta")
    def connectorId = outputJson.databaseConnectorId.toString()
    echo"Connector creado para base: $baseName \nConnectorID: $connectorId "

    String data = """{
  "rulesetName": "RB_$baseName",
  "databaseConnectorId": ${connectorId}
}"""
    respuesta=CallApiDelphix(apiToken, data, 'rulesets', curl)
    return respuesta

}

node(){
    stage('Obtengo token'){
        withCredentials([usernamePassword(credentialsId: 'DELPHIXID', passwordVariable: 'DELPASS', usernameVariable: 'DELUSER')]){
            token=obtenerToken(DELUSER, DELPASS, curl)
        }
    }
    stage('Genero Conector/Ruleset'){
        withCredentials([usernamePassword(credentialsId: 'SYBDESA', passwordVariable: 'PASSBD', usernameVariable: 'USERBD')]){
            dbase.each{ String base ->
                echo "Base: $base"
                conector=generarConector(USERBD, PASSBD, base, token, curl)
                echo"$conector"
            }
        }
    }
}