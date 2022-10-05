#!/usr/bin/env bash

# arguments
# a single directory containing COPY, VERIFY, REMOVE scripts.
# REMOVE maybe missing.

# TODO
# if veify phase fails, retry the copy (transfer) until it is ok - this could support regenerating the COPY/VERIFY file calling --generate_filelist in --update-mode (TBD)

_DEBUG_LEVEL=1

# Load Savy lib
. savy-lib.sh

#config
CNF_file="SAVY_GENERAL.conf"
SRC_file="SAVY_SOURCES.conf"

import_conf VAR_list ${SRC_file}
#print_imported ${VAR_list[@]}

import_conf ACCESS_methods ${CNF_file}
#print_imported ${ACCESS_methods[@]}


RULES_DIR=$1
declare -A _rule_files=()

[ -z $RULES_DIR ] && ERR "no directory provided!" 1
[ -d $RULES_DIR ] || ERR "no directory $RULES_DIR" 128
echo "Checking rule files in $RULES_DIR..."
for _rule_file_type in COPY VERIFY REMOVE
do
    ls $RULES_DIR/$_rule_file_type* || ERR "no $_rule_file_type file in $RULES_DIR"
    # add to hash a file for earch _rule_file_type
    _rule_files+=([$_rule_file_type]=`ls $RULES_DIR/$_rule_file_type* | head -n1`)
done

for _rule_file_type in ${!_rule_files[@]}
do
    :
    #echo "RULE FILE: ${_rule_files[$_rule_file_type]}; TYPE: $_rule_file_type"
done

verify_file=${_rule_files[VERIFY]}
copy_file=${_rule_files[COPY]}
remove_file=${_rule_files[REMOVE]}

DBG "V: $verify_file" 2
DBG "C: $copy_file" 2
DBG "R: $remove_file" 2

# run verify first
_out=`bash $verify_file 2>&1`
_res=$?
DBG "RES: $_res" 2

if [ $_res -eq 0 ]
then
    echo "Nothing to do!"
else
    _rules_dir=${RULES_LOCAL_STORAGE_PATH#./}
    _host_and_dir=${RULES_DIR#$_rules_dir/}
    _host=${_host_and_dir%%/*}
    _dir=${_host_and_dir#*/}
    _dir="/$_dir"
    DBG $_host 2
    DBG $_dir 2

    _user=`head -n1 $copy_file | cut -f2 -d ":" | tr -d " " | cut -f 2 -d " "`
    _port=`head -n1 $copy_file | cut -f3 -d ":" | tr -d " "`

    echo -e "\n${RULES_DIR}: Found $_res files to be transferred."
    echo "There are collections to be fetched from source: $_host:$_port ($_dir)"
    echo "Commands:"
    #RSH=r-$$.sh
    RSH=r.sh
    #TODO: run copy only if files do not exist locally BUT this commented below
    # can copy files that are already there (imagine previous copy was interrupted
    # and some files were copied properly). SO, it requires REMOVING THE LINES from
    # copy_file that represent operations (copies) already executmd properly (in
    # previous runs... SO rules-runner.sh needs to run verify_file above, and
    # process the output when `ls` is giving output on missing file, keep these
    # lines, remove others... pretty easy
    ##echo "bash $verify_file || \\" | tee -a $RSH
    echo "sftp -P $_port -b $copy_file $_user@$_host" | tee $RSH
    echo "bash $verify_file && \\" | tee -a $RSH
    echo "sftp -P $_port -b $remove_file $_user@$_host" | tee -a $RSH
fi
