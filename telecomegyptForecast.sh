#!/bin/bash
#

# tools required
JQ=`which jq`

if [[ -z "${JQ}" ]]; then
  echo "ERROR: jq is not installed."
  exit -1
fi

while getopts ":d:c:" opt; do
  case $opt in
    c) CACHE_DIR="${OPTARG}" ;;
    d) DATATYPE="${OPTARG}" ;;
    \?) echo "Invalid option -${OPTARG}" >&2 ;;
  esac
done

if [[ -z "${CONFIG}" ]]; then
  CONFIG="config.json"
fi

CACHE_DIR=${CACHE_DIR:-$(cat ${CONFIG} | jq '.cache_dir' -r)}
Fetch_EVERY_MINUTE=${Fetch_EVERY_MINUTE:-$(cat ${CONFIG} | jq '.fetch_every_minute' -r)}
PHONE_NUMBER=${PHONE_NUMBER:-$(cat ${CONFIG} | jq '.phone_number' -r)}
PASSWORD=${PASSWORD:-$(cat ${CONFIG} | jq '.password' -r)}

function get_cache_path() {
  echo ${CACHE_DIR}/output.cache
}

#######################################
# Check the cache file and determine
# if it needs to be updated or not
# Returns:
#   0 or 1
#######################################
function cache_needs_refresh() {
  cache_path=$(get_cache_path)
  now=$(date +%s)

  # if the cache does not exist, refresh it
  if [[ ! -f "${cache_path}" ]]; then
    return 1
  fi

  last_modification_date=$(stat -c %Y ${cache_path})
  seconds=$(expr ${now} - ${last_modification_date})
  interval=$((${Fetch_EVERY_MINUTE} * 60))
  echo ${interval}
  if [[ "${seconds}" -gt ${interval} ]]; then
    return 1
  else
    return 0
  fi
}

function fetch_telecomegypt() {
  cache_needs_refresh
  refresh=$?
  command=`ispapi telecomegypt -u ${PHONE_NUMBER} -p ${PASSWORD}`
  cache_path=$(get_cache_path)
  if [[ ! -f "${cache_path}" ]] || [[ "${refresh}" -eq 1 ]]; then
    echo "$command" > ${cache_path}.$$
    echo refresh
    # only update the file if we successfully retrieved the JSON
    num_of_lines=$(cat "${cache_path}.$$" | wc -c) #print the byte count of the file
    if [[ "${num_of_lines}" -gt 5 ]]; then
      mv "${cache_path}.$$" ${cache_path}
    else
      rm -f ${cache_path}.$$
    fi
  fi
}


function create_cache() {
  if [[ ! -d "${CACHE_DIR}" ]]; then
    mkdir -p ${CACHE_DIR}
  fi
}

function return_field() {

  if [[ -z "${DATATYPE}" ]]; then
    echo "ERROR: missing datatype. Please provide it via the -d option."
  fi

  cache_path=$(get_cache_path)

  case ${DATATYPE} in
    quota)
      data=$(awk -F',' '{print $1}' ${CACHE_DIR}/output.cache)
      ;;
    percent)
      data=$(awk -F',' '{printf "%.2f\n", $2}' ${CACHE_DIR}/output.cache)
      ;;
    due)
      data=$(awk -F',' '{print $3}' ${CACHE_DIR}/output.cache)
      ;;
    *)
      data="N/A"
      ;;
    esac

  echo $data
}

create_cache
fetch_telecomegypt
return_field
