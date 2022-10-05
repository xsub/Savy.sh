_LIB_VERSION="0.314"

# args:
# debug_message [debug_level]
# info:
# debug_level set to 0 - display always
DBG() {
 dbg_level=$2
 [ -z $dbg_level ] && dbg_level=1
 [ $_DEBUG_LEVEL -ne 0 ] && \
    [ $dbg_level -le $_DEBUG_LEVEL ] && \
        echo "DBG: $1"
}

# debug with second arguments being an array of strings.
# reversed arguments
# debug_level, debug_message
DBG_R ()
{
    dbg_level=$1
    shift
    [ $dbg_level -le $_DEBUG_LEVEL ] && \
    echo "DBG[]: $*"
}



# args:
# error_message [error_code]
# info:
# if error_code is set to -1, don't exit just print error
# default error code is 64
ERR() {
    echo "$0: ERROR: $1"
    [ -z $2 ] || [ $2 -eq -1 ] && return
    [ -z $2 ] && exit 64
    exit $2
}

echo "SAVY LIB VERSION $_LIB_VERSION"


import_conf_old() {
    declare -n _var_list=$1
    _file=$2
    echo "Processing config file: ${_file}: "
    _var_list+=(`cat ${_file} | grep '=' | cut -f1 -d '=' | tr '\n' ' '`)
    echo "\-> Importing variables(s)..."
    echo "|-> Imported variables (list):"
    echo "/-> List: ${_var_list[@]}."
    [ -f ${_file} ] && . ${_file} || { echo "Error ${_file} not found"; exit 1; }
    echo "Variable(s) import: OK"
}

import_conf() {
    declare -n _var_list=$1
    _file=$2
    if [ -f ${_file} ]
    then
        echo "Processing config file: ${_file}: "
        _var_list+=(`cat ${_file} | grep -v '#'| grep '=' | cut -f1 -d '=' | \
sed 's/declare\ -\?[Aa]\ //g' | tr '\n' ' '`)
        echo "\-> Importing variables(s)..."
        echo "|-> Imported variables (list):"
        echo "/-> List: ${_var_list[@]}."
        source $_file || ERR "$_file not found" 6
        echo "Variable(s) import: OK"
    else
        ERR "File $_file, not found."
    fi
}

eval_var_by_name() {
    _var_name=$1
    declare -n ret=$2
    ret=$(eval "echo \$$_var_name ")
}

print_imported() {
    _var_list=$@
    DBG "_var_list: ${_var_list[@]}" 3
    echo "Variable dump:"
    num=1
    for var in ${_var_list[@]}
    do
        echo -en "\t$num) "
        echo $var=$(eval "echo \${$var[@]}")
        num=$((num+1))
    done
}

select_from_arr() {
    declare -n ret=$1
    shift
    _opts_array=($@)
    DBG "_opts_array $_opts_array" 3
    _eval_arr=()
    for _item in "${_opts_array[@]}"
    do
        eval_var_by_name {$_item} _eval_item
        DBG "_eval_item=$_eval_item" 3
        _eval_arr+=("${_eval_item}")
    done

    select _item in "${_eval_arr[@]}"
    do
        #echo "ITEM: ${_item}"
        echo "Do you want to select: ${_item} -> ($REPLY) (Confirm with Ctrl+D or select again)"
        #: #NOP
    done
    ret="${_item}"
}


