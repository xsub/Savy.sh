#!/usr/bin/env bash

_SCRIPT_VERSION="0.25 `date -r $0`"

# runtime variables
_DEBUG_LEVEL=1 # 0 - debug out off

# constants / TODO: move to SAVY_CONSTS.conf
SSH_MAX_RETRIES=3
ERROR_SSH_CONNECTION=3

# config
CNF_file="SAVY_GENERAL.conf"
SRC_file="SAVY_SOURCES.conf"

# Load Savy lib
. savy-lib.sh

# internal variables: program arguments
_USE_DB=0

#PRE-pre-main: arguments processing
proc_args() {
    #EXEC_ARGS=()
    while [[ $# -gt 0 ]]; do
      case $1 in
        -d|--use-existing-databases)
         _USE_DB=1
         shift
         shift
         ;;
        -u|--update-after-partial-transfer)
          SEARCHPATH="$2"
          shift # past argument
          shift # past value
          ;;
        -|--help)
            ERR "TBD"
        ;;
        -v|--version)
            echo "$0: $_SCRIPT_VERSION"
            exit 0
        ;;
        -*|--*)
        ERR "Unknown option $1" 1
        ;;
        #*)
        #EXEC_ARGS+=("$1")
        #shift # past argument
        #;;
    esac
done
#set -- "${EXEC_ARGS[@]]}" # restore positional parameters
}

proc_args $*

#pre-main :)
echo "Testin/priting associative array of access methods..."
declare -A ACCESS_methods_hash=([local]=localfs [remote1st]=scp [remote2nd]=sfp [remote3rd]=ftp)
declare -a _keys=()
readarray -t _keys < <(printf '%s\n' "${!ACCESS_methods_hash[@]}" | sort)

for key in ${_keys[@]}
do
    echo -n "access method (type, name): $key, "
    echo "value: ${ACCESS_methods_hash[$key]}"
done
#
#main
#
import_conf VAR_list ${SRC_file}
print_imported ${VAR_list[@]}

import_conf ACCESS_methods ${CNF_file}
print_imported ${ACCESS_methods[@]}

echo "Select source:"
select_from_arr _source ${VAR_list[@]}

echo "Selected source: ${_source}"

# This supports "....^...." source format
##_user_host=${_source%^*}
##_host_dir_type=${_source#*^}

# This supports "....^....^...." source format
#_daterange_prefix=`echo $_source | cut -d "^" -f 1`
#_user_host=`echo $_source | cut -d "^" -f 2`
#_host_dir_type=`echo $_source | cut -d "^" -f 3`

# This supports "....^....^...." source format
_user_host=${_source%^*} # two-step: step 1
_user_host=${_user_host#*^} # two-step: step 2
_daterange_prefix=${_source%%^*}
_host_dir_type=${_source##*^}

_host_dir=${_host_dir_type%!*}
_type=${_host_dir_type#*!}

_user=${_user_host%@*}
_hostport=${_user_host#*@}
_host=${_hostport%:*}
_port=${_hostport#*:}

if [ "$_host" == "" ]
then
    _host="localhost"
fi

[ "$_hostport" == "$_port" ] && _port=22

echo "USERHOST: $_user_host"
echo "HOST_DIR: $_host_dir"
echo "HOSTPORT: $_hostport"
echo "HOST: $_host"
echo "PORT: $_port"
echo "TYPE: $_type"
echo "USER: $_user"

if [ $_USE_DB -eq 0 ]
then

    if [ "$_host" != "localhost" ]
    then
        echo "Selected source is a remote directory on host: $_host"

        # prepare the variables
        path=$_host_dir
        search_prefix=${_daterange_prefix##*:}
        date_year=${_daterange_prefix%%:*} # TODO: date_yearS<-support multiple years
        date_months=${_daterange_prefix%:*} # two-step: step 1
        date_months=${date_months#*:} # two-step: step 2
        search_pattern="$search_prefix$date_year"
        date_begin=$date_year
        date_end=`date +%Y%m%d` # TODO
        remote_cmd_ssh_invoke="ssh -i ~/.ssh/id_rsa $_user@$_host -p $_port -C "
        remote_cmd="$remote_cmd_ssh_invoke ls $path/$search_pattern*"

        # declare hashtables
        declare -A SRC_CUR_MON_COUNTS=();
        declare -A SRC_CUR_MON_FILES=();

        _use_progressbar=1 # set to anyting to be true, 0 = no value
        _ssh_errors=0 # how many SSH errors encountered
        _prev_ssh_errors=0 # temporary value
        cnt=0
        for date_month in $date_months
        do
            cnt=1;
            #TODO: below for needs to go to 31 or 30, make it depend on date_month
            for date_day in `seq 1 31`
            do
                date_pref=""
                [ $date_day -lt 10 ] && date_pref="0"
                date_scan=$date_year$date_month$date_pref$date_day
                remote_cmd="$remote_cmd_ssh_invoke ls $path/$search_prefix$date_scan* 2> _errors | cat"
                # RUN THE CMD
                remote_cmd_output=`$remote_cmd`
                _exec_err=$?
                DBG "OUT: $remote_cmd_output" 2
                # Service possible network connection error
                if [ $_exec_err -ne 0 ]
                then
                    echo "ERROR: SSH connection failed to $_user@$_host..." -1
                    ((_ssh_errors++))
                    [ $_ssh_errors -gt $SSH_MAX_RETRIES ] && \
                        ERR "ABORTING." $ERROR_SSH_CONNECTION
                else
                    remote_cmd_output_cnt=0
                    ##[ "$remote_cmd_output" != "" ] && remote_cmd_output_cnt=`echo $remote_cmd_output | grep -c $path`

                    # count how many lines are there in the shell response ($remote_cmd_output_cnt)
                    [ "$remote_cmd_output" != "" ] &&
                        for line in $remote_cmd_output
                        do
                            ((remote_cmd_output_cnt++))
                        done
                    #`cat "$remote_cmd_output" | wc -l`
                    if [ $_use_progressbar ]
                    then
                        _percent=$(expr $cnt \* 100 \/ 31)
                        _move=$(expr $cnt + 21)
                        tput cub $_move
                        printf "$date_scan %02d%%-(%02d/31)-%${cnt}s" $_percent $cnt |tr " " "*"
                    else # no progress bar
                        : # nop
                    fi
                    # process the command output
                    if [ $remote_cmd_output_cnt -gt 0 ]
                    then
                        [ $_use_progressbar ] || echo "$date_scan: $remote_cmd_output_cnt $_type files found."
                        SRC_CUR_MON_COUNTS+=([$date_scan]=$remote_cmd_output_cnt)
                        SRC_CUR_MON_FILES+=([$date_scan]="$remote_cmd_output")
                        # check if source is already mirrored on target
                        _test_path="$RULES_LOCAL_STORAGE_PATH/$_host/$_host_dir/ $date_scan"
                        if [ -d "$_test_path" ]
                        then
                            echo "$_test_path already exists on target \(locally\), contains:"
                            ls -l $_test_path
                        else
                            :
                        fi
                    else
                        [ $_use_progressbar ] || echo "$date_scan: no data found."
                    fi
                 fi
                [ $_ssh_errors -eq $_prev_ssh_errors ] && ((cnt++))
                _prev_ssh_errors=$_ssh_errors
           done
           # add new line after progress bar
           [ $_use_progressbar ] && echo
         done
    else
        echo -n "Selected source is pointing to local directory"
        if [ -d "$_source" ]
        then
            echo
        else
            echo ", but not accessible!"
        fi
    fi
else # _USE_DB = 0
    _counts_file=`ls -1tr *counts.sh | tail -n1`
    _files_file=`ls -1tr *files.sh | tail -n1`

    echo "sourcing $_counts_file"
    . $_counts_file
    echo "sourcing $_files_file"
    . $_files_file
fi

#echo ${!SRC_CUR_MON_COUNTS[@]}



_keys=${!SRC_CUR_MON_COUNTS[@]}
echo "print collections found: ${#_keys[@]}"
echo "collections: $_keys"
echo

#readarray -t _sorted_keys < <(printf '%s\n' "${!SRC_CUR_MON_FILES[@]}" | sort)
#for k in $_sorted_keys


for k in `echo ${!SRC_CUR_MON_FILES[@]}`
do
    _no_of_files=${SRC_CUR_MON_COUNTS[$k]} # TODO change explicit references to access via this variable, below
    target_path="/RAID1_HOME/_AUTOMATED_/$_host/$k/"
    _path="$RULES_LOCAL_STORAGE_PATH/$_host/$_host_dir/$k"
    if [ -d $_path ]
    then
        ERR "$_path rules local storage path already exists" 128
    else
        echo "$k: Creating directory for ${SRC_CUR_MON_COUNTS[$k]} rules local storage $_path"
        mkdir -p $_path
    fi
    #echo "$k -> ${SRC_CUR_MON_COUNTS[$k]} -> ${SRC_CUR_MON_FILES[$k]}"
    _gen_filename_copy="$_path/COPY_${SRC_CUR_MON_COUNTS[$k]}_png.sftp"
    _gen_filename_verify="$_path/VERIFY_${SRC_CUR_MON_COUNTS[$k]}_png.sh"
    _gen_filename_remove="$_path/REMOVE_${SRC_CUR_MON_COUNTS[$k]}_png.sftp"
    DBG "_gen_filename_copy $_gen_filename_copy" 2
    DBG "_gen_filename_verify $_gen_filename_verify" 2
    DBG "_gen_filename_remove $_gen_filename_remove" 2
    echo "#$k REMOVE from $_host, user: $_user port: $_port" > $_gen_filename_remove # new timestamp to remove file
    echo '!echo "THIS IS REMOVAL FILE -- PRESS ANY KEY TO CONT OR CTRL+Z AND KILL THE SFTP INSTANCE >> kill -9 $PPID <<" && read' >> $_gen_filename_remove
    echo "#$k COPY from $_host, user: $_user port: $_port" > $_gen_filename_copy # timestamp
    echo '!mkdir -p ' $target_path >> $_gen_filename_copy # mk target dir
    echo "cd $path" >> $_gen_filename_copy # cmd to source location in sftp
    echo -e "#$k VERIFY\n_cnt=0" > $_gen_filename_verify # new timestamp to verify file, and init exit code holder
    echo "cd $path" >> $_gen_filename_remove # append to remove file
    declare -a _CUR_MON_FILES=()
    for _src_full_path in `echo ${SRC_CUR_MON_FILES[$k]} | tr '\n' ' '`
    do
        _src_just_filename=${_src_full_path##*/}
        DBG "_src_full_path $_src_full_path" 2
        DBG "_src_just_filename $_src_just_filename" 2
        DBG "target_path $target_path" 2
        DBG "_src_full_path $_src_full_path" 2
        #_local_result=`ls $target_path/$_src_just_filename 2>&1 > /dev/null`
        _local_result=`ls $target_path/$_src_just_filename 2>/dev/null`
        [ "$_local_result" != "$target_path/$_src_just_filename" ] && _CUR_MON_FILES+=($_src_full_path)
    done

    _counter=0;

    DBG_R 3 "_CUR_MON_FILES ${_CUR_MON_FILES[@]}"
    #TODO: enable generation of "counter/all" string
    #_all_files_cnt=${#_CUR_MON_FILES[@]}

    for _src_full_path in ${_CUR_MON_FILES[@]}
    do
        ((_counter++))
        _src_just_filename=${_src_full_path##*/}
        DBG "$_src_just_filename" 2
        # DBG copy
        DBG "echo get $_src_full_path $target_path >> $_gen_filename_copy" 3
        # DO copy
        `echo get $_src_full_path $target_path \# $_counter >> $_gen_filename_copy`

        # DBG verify
        DBG "echo ls -l $target_path/$_src_just_filename || ((_cnt++)) >> $_gen_filename_verify" 3
        # DO verify
        `echo "ls -l $target_path/$_src_just_filename || ((_cnt++)) # $_counter" >> $_gen_filename_verify`

        # DBG remove
        DBG "echo -rm $_src_full_path >> $_gen_filename_remove" 3
        # DO remove
        `echo -rm $_src_full_path \# $_counter >> $_gen_filename_remove`
    done
        DBG "echo 'exit $_cnt' >> $_gen_filename_verify" 3
        `echo 'exit $_cnt' >> $_gen_filename_verify`

done

_TIME_STAMP=`date +%Y%m%d%H%M%S`

if [ $_USE_DB -eq 1 ]
then
    rm $_counts_file
    rm $_files_file
fi
declare -p SRC_CUR_MON_FILES > $_TIME_STAMP-files.sh
declare -p SRC_CUR_MON_COUNTS > $_TIME_STAMP-counts.sh
