# Delphix Hispanic Masking

## Masking

### masking_setup.sh
```sh
# masking_setup.sh
# Created: Paulo Victor Maluf - 09/2019
# Updated to work with Hispanic Expressions: Javier Barthe - 04/2021
#
# Parameters:
#
#   masking_setup.sh --help
#
#    Parameter             Short Description                                                        Default
#    --------------------- ----- ------------------------------------------------------------------ --------------
#    --profile-name           -p Profile name
#    --expressions-file       -e CSV file like ExpressionName;DomainName;level;Regex                expressions.cfg
#    --domains-file           -d CSV file like Domain Name;Classification;Algorithm                 domains.cfg
#    --masking-engine         -m Masking Engine Address
#    --help                   -h help
#
#   Ex.: ./setup-mask.sh -p LPDP -f ./expressions.cfg -d domains.cfg -m 192.168.0.174
```
