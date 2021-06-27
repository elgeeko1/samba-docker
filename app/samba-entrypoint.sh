#!/bin/bash

set -e

SMB_USERS_PATH="${SMB_USERS_PATH:-"/opt/samba/smb-users"}"

# samba_add_user( username, password, [uid, group, gid] )
samba_add_user() {
  local username=${1}
  local password="${2}"
  local uid=${3:-""}
  local group=${4:-""}
  local gid=${5:-""}

  echo Adding samba user ${username}

  # add unix group if doesn't exist
  if [ ! -z "${group}" ] && ! grep -q "^${group}:" /etc/group; then
    addgroup ${gid:+--gid ${gid}} ${group}
  fi

  # add unix user if doens't exist
  if ! grep -q "^${username}:" /etc/passwd; then
    adduser ${username} ${uid:+--uid ${uid}} ${group:+--gid ${gid}} --gecos "" --disabled-login --disabled-password --no-create-home --shell /sbin/nologin
  fi

  # add the samba user and set password
  echo -e "${password}\n${password}" | smbpasswd -s -a ${username}
}

# add samba users by reading them in from a file
# samba_add_user_file (path to user file)
# file format:
#  username password [uid group gid]
samba_add_user_file() {
  local user_file=${1}
  if [ ! -f ${user_file} ]; then
    echo "Error: unable to parse user file ${user_file}"
    exit 1
  fi
  echo Parsing samba user file ${user_file}

  # parse user lines and add each user to samba
  while read -r line || [ -n "${line}" ]
  do
    # eliminate comments and whitespace
    line=$(echo -n "${line}" | awk '{sub(/#.*$/,"")}1' | xargs)
    if [ ! -z "${line}" ]; then
      read -a linearray <<< "${line}"
      if [ ${#linearray[@]} -lt 2 ]; then
        echo "Error parsing smb-users: too few arguments."
        echo "line: ${line}"
        echo "expected format: username password [uid group gid]"
        exit 1
      fi
      samba_add_user ${linearray[0]} ${linearray[1]} ${linearray[2]} ${linearray[3]} ${linearray[4]}
    fi
  done < "${user_file}"
}

# parse user file if it exists
if [ -f ${SMB_USERS_PATH} ]; then
  samba_add_user_file ${SMB_USERS_PATH}
fi

# print paramaters to stdout for logging
samba-tool testparm --suppress-prompt

# start netbios as daemon in background so logs will print to stdout
nmbd -i &

# start samba
smbd --foreground --log-stdout --no-process-group
