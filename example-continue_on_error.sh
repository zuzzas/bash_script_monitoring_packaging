#!/bin/bash -vx
# Simple script to test bash script execution monitoring, without stop in case of error detection -> report to monitoring tool is done at the end
# Copyright (c) 2016 Santeramo Luc (l.santeramo@brgm.fr)
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
# Bureau de Recherches Geologiques et Minieres (BRGM), hereby disclaims all copyright
# interest in the script  "bash script monitoring" written by Luc Santeramo.
#
# OS : tested on Solaris 11.1 and Centos
# v1.0 : Luc Santeramo - 2016-05-03

### Environnement de remontee des erreurs 
# Penser à positionner "-s" ou "-c CPT_ERR" sur error_check_trap
# Voir la définition de la fonction "error_check_trap" dans supervision_for_bash.sh pour une description des parametres
SCRIPTDIR="/usr/share/bash_script_monitoring" ; source ${SCRIPTDIR}/bash_script_monitoring.sh
trap 'error_check_trap -c CPT_ERR -p $_' ERR ; set -o errtrace ; export SCRIPT_PARAMS="$*";CPT_ERR=0
### Fin Environnement de remontee des erreurs

echo "Begin..."
ls /nonexistant_dir
echo "middle.."
ls /nonexistant_dir2
echo "End"

### Environnement de remontee des erreurs
# Execution du script sans erreur -> on informe la supervision
[[ $CPT_ERR -eq 0 ]] && ${execution_status_report_ok}
### Fin Environnement de remontee des erreurs
