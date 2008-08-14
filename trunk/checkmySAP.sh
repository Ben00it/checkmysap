#!/bin/bash
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.

  ###################################
  # Load environnement
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${BBHOME}/ext/checkmySAP/lib

  ###################################
  # Vars
  PATHTOPLUGIN="${BBHOME}/ext/checkmySAP"
  INIFILEPATH="${PATHTOPLUGIN}/checkmySAP.ini" # Path to the .ini file
  RFCPINGCMD="${PATHTOPLUGIN}/bin/rfcping"  # Path to the rfcping binary (Check the README)
  LGTSTCMD="${PATHTOPLUGIN}/bin/lgtst"		 # Path to the lgtst binary (Check the README)
  STARTRFCCMD="${PATHTOPLUGIN}/bin/startrfc"  # Path to the startrfc binary (Check the README)
  SERVERLIST="${BBTMP}/servers_list"	# used by the startrfc command
  BBHTAG="SAP"           # What we put in bb-hosts to trigger this test
  COLUMN=${BBHTAG}       # Name of the column, often same as tag in bb-hosts


  ###################################
  # Pre-Run tests

  # Is checkmySAP.ini around ?
  if [ ! -e ${INIFILEPATH} ]; then
      echo -e "\n\r\t/!\ checkmySAP.ini is not present. It should be in ${INIFILEPATH}.\n\r"
      exit 1
  fi

  # Is rfcping is around ?
  if [ ! -x ${RFCPINGCMD} -o ! -s ${RFCPINGCMD} ]; then
      echo -e "\n\r\t/!\ rfcping binary is not present and/or is not executable. It should be in ${RFCPINGCMD}.\n\r"
      exit 1
  fi

  # Is lgtst is around ?
  if [ ! -x ${LGTSTCMD} -o ! -s ${LGTSTCMD} ]; then
      echo -e "\n\r\t/!\ lgtst binary is not present and/or is not executable. It should be in ${LGTSTCMD}.\n\r"
      exit 1
  fi

  # Is startrfc is around ?
  if [ ! -x ${STARTRFCCMD} -o ! -s ${STARTRFCCMD} ]; then
      echo -e "\n\r\t/!\ startrfc binary is not present and/or is not executable. It should be in ${STARTRFCCMD}.\n\r"
      exit 1
  fi



  ###################################
  # Functions
  function CheckReturnCode {
    if [ $1 -ne 0 ]; then
        COLOR="red"
        FINALCOLOR="red"
    else
        COLOR="green"
    fi
    echo "<p style='margin-left:auto; margin-right:auto; background-color: ${COLOR}; width: 135px;'>Error code: '$1'</p>" >> ${LOGFILES}
  }
  function WriteLog {
    BEENCHECKEDONCE="1"
    echo "<p style='margin-left:-25px; margin-bottom:-15px; margin-top:15px; background-color: #222222; border: thin solid #555555;'>Below, log with <b style='color: #0066FF;'>$1</b> on the <b style='color: #0066FF;'>$2</b> server : </p>" >> ${LOGFILES}
  }
  
  function SendResult {
    MSG=`cat ${LOGFILES}`
    # I sent back the result to the Hobbit Server
    $BB $BBDISP "status ${MACHINE}.${COLUMN} ${FINALCOLOR} `date`

    ${MSG}
    "
  }


  ###################################
  #  Main
  $BBHOME/bin/bbhostgrep $BBHTAG | while read L; do
      set $L     # To get one line of output from bbhostgrep
      HOSTIP="$1"
      MACHINEDOTS="$2"
      MACHINE=`echo $2 | $SED -e's/\./,/g'`
      LOGFILES="/tmp/checkmySAP_$$_${MACHINEDOTS}" 
      cat /dev/null > ${LOGFILES}
      MSG="$BBHTAG status for host $MACHINEDOTS"
      BEENCHECKEDONCE="0"
      FINALCOLOR="green"
     
      ###################
      # 1/ Check with rfcping
      TESTTYPE="rcfping"
      # Get information from the checkmySAP.ini file in the same directory
      LINE=`cat ${INIFILEPATH} | grep -i "^${TESTTYPE},${MACHINEDOTS}"`;
      if [ "$?" = "0" ]; then
          WriteLog $TESTTYPE ${MACHINEDOTS}
          TESTSID=$(echo $LINE | awk -F, '{print $3'});
          TESTMSHOST=$(echo $LINE | awk -F, '{print $4'});
          TESTUSER=$(echo $LINE | awk -F, '{print $5'});
          TESTPASSWD=$(echo $LINE | awk -F, '{print $6'});
          TESTCLIENT=$(echo $LINE | awk -F, '{print $7'});
          TESTGROUP=$(echo $LINE | awk -F, '{print $8'});
          #----------------------------------------------------------------------------------------
          # Command run according the pattern below :
          # fonction,machine,r3name,mshost,user,passwd,client,group
          #   1        2     3     4      5     6      7       8
          #----------------------------------------------------------------------------------------
          ${RFCPINGCMD} r3name=${TESTSID} mshost=${TESTMSHOST} user=${TESTUSER} passwd=${TESTPASSWD} client=${TESTCLIENT} group=${TESTGROUP} >> ${LOGFILES}
          CheckReturnCode $?
      fi

      ###################
      # 2/ Check with lgtst
      TESTTYPE="lgtst"
      # Get information from the checkmySAP.ini file in the same directory
      LINE=`cat ${INIFILEPATH} | grep -i "^${TESTTYPE},${MACHINEDOTS}"`;
      if [ "$?" = "0" ]; then
          WriteLog $TESTTYPE ${MACHINEDOTS}
          TESTSID=$(echo $LINE | awk -F, '{print $3'});
          TESTMSHOST=$(echo $LINE | awk -F, '{print $4'});
          TESTUSER=$(echo $LINE | awk -F, '{print $5'});
          #----------------------------------------------
          # Command run according the pattern below :
          # fonction,machine,name,mshost,msserv
          #  1     2     3     4        5
          #----------------------------------------------
          ${LGTSTCMD} name=${TESTSID} -H ${TESTMSHOST} -S ${TESTUSER} >> ${LOGFILES}
          CheckReturnCode $?
      fi




      ###################
      # 3/ Check with startrfc 
      TESTTYPE="startrfc"
      # Get information from the checkmySAP.ini file in the same directory
      LINE=`cat ${INIFILEPATH} | grep -i "^${TESTTYPE},${MACHINEDOTS}"`;
      if [ "$?" = "0" ]; then
          WriteLog $TESTTYPE ${MACHINEDOTS}
          TESTSID=$(echo $LINE | awk -F, '{print $3'});
          TESTGROUP=$(echo $LINE | awk -F, '{print $4'});
	  TESTUSER=$(echo $LINE | awk -F, '{print $5'});
	  TESTPASSWD=$(echo $LINE | awk -F, '{print $6'});
          TESTCLIENT=$(echo $LINE | awk -F, '{print $7'});
	  TESTLANGUAGE=$(echo $LINE | awk -F, '{print $8'});
	  TESTLISTESERVER=$(echo $LINE | awk -F, '{print $9'});

	  #----------------------------------------------
          # Command run according the pattern below :
          # fonction,machine,SID, Logongroup,username,password,client,language,number of line in the LOGON GROUP
          #  1        2       3       4         5         6      7        8      9
          #----------------------------------------------
          ${STARTRFCCMD} -FTH_SERVER_LIST -ESERVICES=25 -TLIST,80,w=${SERVERLIST} -balanced -3 -h${MACHINEDOTS} -s${TESTSID} -g${TESTGROUP} -u${TESTUSER} -p${TESTPASSWD} -c${TESTCLIENT} -l${TESTLANGUAGE} >> ${LOGFILES}
          RESULTCMD=$?

	  # Check whatever the answer got the right number of SAP AS/CI
          NUMBEROFRESULT=`cat ${SERVERLIST} | wc -l`
	  if [ ${NUMBEROFRESULT} -eq ${TESTLISTESERVER} ]; then
	      CheckReturnCode ${RESULTCMD}
	  else
	      echo "There is not the specified servers number (currently <u>${NUMBEROFRESULT}</u> instead of <u>${TESTLISTESERVER}</u>) in your ${TESTGROUP} logon group." >> ${LOGFILES}
	      CheckReturnCode 255
	  fi
	  echo "Server found on the ${TESTGROUP} logon group :" >> ${LOGFILES}
	  cat ${SERVERLIST} >> ${LOGFILES}
      fi


      # Test whatever  the machine has been tested at least one
      if [ ${BEENCHECKEDONCE} -eq "0" ]; then
          FINALCOLOR="yellow"
          echo "The machine <u>${MACHINEDOTS}</u> is defined in your <u>bb-hosts</u> but not even once in your <u>checkmySAP.ini</u>" >> ${LOGFILES}
      fi
      
      # Send result to the Hobbit Server
      SendResult

      # Erase old log
      rm -f ${LOGFILES}
  done

exit 0
