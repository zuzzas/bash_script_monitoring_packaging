# bash_script_monitoring.sh library README file
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
# BRGM, hereby disclaims all copyright interest in the script
#  "bash script monitoring" written by Luc Santeramo.
#
# v1.0 : Luc Santeramo - 2016-05-03



******** What is it for ? ********

"bash_script_monitoring.sh" is a library designed to monitor (all?) your bash script execution (tested on GNU/Linux et Solaris) with you monitoring tool (work only with Zabbix for the moment, but is ready to be adapted for other tools).



******** What's inside ? *********

It's "just" a script using the power of "trap ERR"



******** How to use it ? *********

Use is very simple since you don't need to rewrite all your scripts. You just need to :
- Copy library "bash_script_monitoring.sh" in directory /usr/share/bash_script_monitoring/
- Create configuration file /etc/bash_script_monitoring/bash_script_monitoring.conf using provided exemple configuration file
- Create dir /var/log/bash_script_monitoring to store automaticly generated error logs
- Add following line at the top of the script to be monitored
- Adapt SCRIPTDIR variable (4th line) if needed, and -s/-c selector (5th line) : "-s" to stop on error, "-C CPT_ERR" to continue on error 

################### Error management environnement ###########################################
# Dont forget to set "-s" or "-c CPT_ERR" on error_check_trap below
# See definition of "error_check_trap" in bash_script_monitoring.sh for parameters description 
SCRIPTDIR="/usr/share/bash_script_monitoring" ; source ${SCRIPTDIR}/bash_script_monitoring.sh
trap 'error_check_trap -s -p $_' ERR ; set -o errtrace ; export SCRIPT_PARAMS="$*";CPT_ERR=0
################### End of error management environnement ####################################

- Add following lines to the bottom of the script to be monitored

################### Error management environnement ###########################################
# Script execution without error -> monitoring tool is notified
[[ $CPT_ERR -eq 0 ]] && ${execution_status_report_ok}
################### End of error management environnement ####################################

Specific for zabbix monitoring :
- Add in a model a new element with the key user.-path-to-ecript.script_name.scriptparams
- Add a trigger when this new element raise a problem (=1 by default)

Common for all monitoring tools :
- Run your script (maybe with "bash -vx" the first time, so you will see integration problem or the key generated for zabbix)
- And it's done



******** What to expect ? ********

- When a command in your script fails, the script stops or continues, regarding selected behavior (-s or -c), and the monitoring tool is informed (element change to 1 in zabbix).
You can find more information about the error (timestamp, parameters of script and failing command, error line) in /var/log/bash_script_monitoring.
- If all commands in the script run ok, the monitoring tools is informed at the end of the execution (element changed to 0 in zabbix)
During script execution, if you need to alert the monitoring tool, simply run ${execution_status_report_ok} or ${execution_status_report_nok}
