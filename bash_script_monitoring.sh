#!/bin/bash
# Fonction de verification d'erreur lors de l'execution de script, avec remontee d'erreur dans zabbix
# Copyright (c) 2005-2016 Santeramo Luc (luc.santeramo at yahoo dot com)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Revues.org, hereby disclaims all copyright interest in the script
#  "bash script monitoring" written by Luc Santeramo.
# 
# Semantia, hereby disclaims all copyright interest in the script
#  "bash script monitoring" written by Luc Santeramo.
# 
# Bureau de Recherches Geologiques et Minieres (BRGM), hereby disclaims all copyright
# interest in the script  "bash script monitoring" written by Luc Santeramo.
# 
# v1.0 : Luc Santeramo (luc.santeramo@revues.org)
# v1.1 : Luc Santeramo (luc.santeramo@semantia.com) : gestion des erreurs par trap plutot qu'appel d'une fonction apres chaque commande
# v1.2 : Luc Santeramo (l.santeramo@brgm.fr) 20150416 : 
#	- suppression fonction error_check
#	- grosses adaptations pour interfacage avec zabbix
# v1.3 : Luc Santeramo (l.santeramo@brgm.fr) 20160305 :
#	- start writing/translating in english
#	- configuration section split in a separate file
#	- rewrite to let choice of monitoring tool (zabbix only for the moment)
# TODO : 
# - traduire en anglais
# - ecrire fonction affichant cle zabbix d'un script pour simplifier mise en place

# Configuration file
CONFFILE="/etc/bash_script_monitoring/bash_script_monitoring.conf"

# Configuration file loading
if [ -e "${CONFFILE}" ]
then
	. "${CONFFILE}"
else
	echo "Configuration file ${CONFFILE} not found"
	exit
fi

#########################################

# Check file presence
for file in ${BSMZABBIX_SENDER_CONF} ${BSMMAIL} ${BSMZABBIX_SENDER}
do
	if [ ! -e "${file}" ] 
	then
		echo "${file} does not exist"
		exit
	fi
done

# Check log dir
if [ ! -w "${BSMLOGDIR}" ] 
then
	echo "${BSMLOGDIR} does not exist or is not writeable by $(whoami)" 
	exit
fi

# Command line to report script execution status regarding monitoring tool used
case ${BSMMONITORING_TOOL} in
	"zabbix" )
		execution_status_report_ok="custom_zabbix_sender -o ${BSMZABBIX_OK}"
		execution_status_report_nok="custom_zabbix_sender -o ${BSMZABBIX_NOK}"
		;;
	* )
		echo "Monitoring tool ${BSMMONITORING_TOOL} unknown"
		;;
esac

### custom_zabbix_sender
# Envoie d'une valeur de retour specifiée en parametre au serveur de supervision
# parametres :
# - o (obligatoire) : valeur a envoyer (0 = OK ; 1 = ERREUR)
# - k (facultatif) : cle pour laquelle la valeur doit etre affectée. Si non précisé, la clé est créée : user.-chemin-du-script.nom_du_script.params
# Attention les caracteres utilises dans le nom du script doivent respecter le standard zabbix : https://www.zabbix.com/documentation/2.0/manual/config/items/item/key
function custom_zabbix_sender
{
	# verification parametres 
	usage() { echo "custom_zabbix_sender -o <0|1> [-k <cle>]"  1>&2; exit; }
	OPTIND=1
	while getopts "o:k:" opt
	do
		#echo "-$opt-${OPTARG}"
        	case "${opt}" in

		o)
			o="${OPTARG}" ;;
		k)
			k="${OPTARG}" ;;
		*)
                	usage;;
        	esac
	done

	[ -z "$o" ] && usage

	# creation de la cle si elle n'est pas en parametre : user.-chemin-du-script.nom_du_script(.params)
	if [ -z "$k" ] 
	then
		SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[1]}" )" && pwd )"
		SCRIPTNAME="$(basename "$0")"
		k="$(whoami).${SCRIPTDIR//\//-}.${SCRIPTNAME}"
		[[ "${SCRIPT_PARAMS}x" == "x" ]] || k="${k}.${SCRIPT_PARAMS// /-}"
	fi
	
	# envoie des infos à zabbix
	ZBXCMD="${BSMZABBIX_SENDER} -c ${BSMZABBIX_SENDER_CONF} -k ${k} -o ${o}"
	if ! ${ZBXCMD}
	then
		# L'envoie s'est mal passé, on tente d'envoyer un mail pour compenser
		echo "cmd : ${ZBXCMD}" | ${BSMMAIL} -s "Erreur utilisation zabbix_sender sur $(hostname)" "${BSMMAILDEST}" > /dev/null 2>&1
	fi	
}

### custom_zabbix_error_reset
# Repositionne la valeur 0 pour la cle specifie. Utile après la resolution d'un probleme ou apres une phase de debug
# parametres :
# - k (obligatoire) : nom de la cle a remettre a 0. (format : user.-chemin-du-script.nom_du_script)
function custom_zabbix_error_reset
{
	# verification parametres 
	usage() { echo "custom_zabbix_error_reset -k <cle>"  1>&2; exit; }

	OPTIND=1
	while getopts "k:" opt
	do
		#echo "-$opt-${OPTARG}"
        	case "${opt}" in
		k)
			k="${OPTARG}" ;;
		*)
                	usage;;
        	esac
	done

	[ -z "$k" ] && usage

	# envoie des infos à zabbix
	${BSMZABBIX_SENDER} -c "${BSMZABBIX_SENDER_CONF}" -k "${k}" -o "${BSMZABBIX_OK}"
}

### error_check_trap
# Fonction de traitement des erreurs
# Ajoute par defaut le message d'erreur a la fin du fichier de log dans ${BSMLOGDIR}/$(basename $0)_error.log
# parametres :
# - s : s'il est activé, stoppe l'execution du script après une erreur
# - c : nom de la variable compteur d'erreur global : CPT_ERR (sans le $). doit etre definie si -s n'est pas positionné
# - p (facultatif) : toujours "$_" et toujours le dernier parametre. Correspond au dernier parametre traité sur la commande ayant généré l'erreur.
#		Si ce parametre n'est pas passé, on ne sait pas quel est le parametre potentiellement responsable de l'erreur ( à défaut d'un $BASH_COMMAND "broken")
#
# utilisation : ajouter "trap 'error_check_trap -s | -c CPT_ERR [ -p $_ ]' ERR ; set -o errtrace ; export SCRIPT_PARAMS="$*"; CPT_ERR=0" en debut de script, apres avoir sourcé ce script
function error_check_trap
{
	local RETVAL=$?
	local SCRIPTNAME=${BASH_SOURCE[1]}
	local LINE=${BASH_LINENO[0]}
	local COMPTEUR_ERREUR
	local opt

	# verification parametres 
	usage() { echo "error_check_trap: [ -s ]  [ -c CPT_ERR ] [ -p \$_ ] "  1>&2; exit; }

	# Reinitialisation de l'indice des arguments en cas d'appel a getops imbrique
	OPTIND=1
	while getopts "c:ps" opt
	do
		#echo "getopts a trouvé l'option $opt"
        	case "${opt}" in
		p)
			p="${*:$OPTIND}" ; break ;; # break obligatoire pour ne pas analyser des options presentes après -p
		c)
			c="${OPTARG}" ;;
		s)
			s="true" ;;
		*)
                	usage ;;
        	esac
	done
	[[ -z "$s" ]] && [[ -z "$c" ]] && echo "-c doit etre positionne si -s ne l'est pas"

	# Fichier de log
	LOGFILE="${BSMLOGDIR}/$(basename "$0")${SCRIPT_PARAMS// /-}_error.log"

	# Creation du message d'erreur
	ERRMSG="ERREUR : script ${SCRIPTNAME}, lancé avec parametres -${SCRIPT_PARAMS:-none}-, interrompue a la ligne ${LINE}, code erreur ${RETVAL}"
	# on ajoute dans un fichier log
	DATE=$(date "+%F %X")
	echo "${DATE}: ${ERRMSG}, parametres de la commande en erreur : ${p}" | tee "${LOGFILE}"
	
	# Envoie message a zabbix
	custom_zabbix_sender -o "${BSMZABBIX_NOK}"
	
	# Incrementation du compteur d'erreur si -s n'est pas positionné
	if [ "$s" == "true" ] 
	then
		exit ${RETVAL}
	else
		COMPTEUR_ERREUR=${!c}    
		((COMPTEUR_ERREUR=COMPTEUR_ERREUR+1))
		eval "${c}"="${COMPTEUR_ERREUR}"
	fi
}

### ignore_trap
# sauvegarde et ignore la definition d'un trap. s'utilise avant un restore_trap
# parametre :
# - nom du trap (voir liste avec trap -l)
function ignore_trap
{
	local TRAPTOIGNORE="$1"
	# TODO : test si trap deja ignoree
	# probleme avec -z "$(echo $IGNORED_TRAP_${TRAPTOIGNORE})"
	TMPFILE=/tmp/trap_sav_$$
	trap > ${TMPFILE}
	while read line
	do
		SIG=$(echo "$line" | egrep -o "([[:upper:]])*$")
		CMD=$(echo "$line" | egrep -o "'(.*)'")
		if [ "${SIG}" == "${TRAPTOIGNORE}" ]
		then
			# sauvegarde du trap
			eval IGNORED_TRAP_${SIG}="${CMD}"
			# suppression du trap
			trap ${SIG}
		fi
	done < ${TMPFILE}
	rm ${TMPFILE}
}

### restore_trap
# restaure la definition d'un trap telle qu'elle etait avant l'execution d'ignore_trap
# parametre :
# - nom du trap (voir liste avec trap -l)
function restore_trap
{
	# TODO : gestion du trap non ignoree
	local TRAPTORESTORE="$1"
	trap -- "$(eval echo $IGNORED_TRAP_${TRAPTORESTORE})" ${TRAPTORESTORE}
	unset $(echo IGNORED_TRAP_${TRAPTORESTORE})
}
