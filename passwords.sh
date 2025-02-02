#!/bin/bash
#
# passwords.sh - Stores passwords in an encrypted file with VeraCrypt and manages access to it.
#
# Site: https://github.com/Matheus-git/password-manager
# Author: Matheus Silva Sores <mathiew0@gmail.com>
#
#
# This program is a password manager using Veracrypt to encrypt the data.
# Therefore, the first command needs to be --create-volume to create the volume that will be used by Veracrypt.
# IMPORTANT: be careful when executing it, as it will overwrite the file; it is recommended to run it only once.
#
# The password is never displayed at any moment and is directly sent to the clipboard in some cases.
# All access to the txt file containing the passwords is done in RAM, which means nothing is saved to disk.
# The program decrypts the volume quickly to gain access and re-encrypts it again when finished, even in cases of error.
#
# IMPORTANT: the program must be run with sudo
#
#
# License: GPL.
#

HELP_MESSAGE="
    Usage: $0 [-h]

    --help                  Displays help screen
    --list                  List credentials
    --create-volume         Creates the volume that will be used to store the passwords
    --generate-pass         Copies a randomly generated password to the clipboard
    --add                   Adds credentials
    --remove                Removes credential with the given ID (shown in the listing)
    --get-pass              Copies the password of the credential with the specified ID to the clipboard
"

# Feel free to edit these variables 
FILE_PATH="passwords.txt"               # Name of the file saved inside the volume
VOLUME_PASSWORD="0z&NYKQck,Zh#PtNUe4O"  # Password for mounting the volume
VOLUME_MOUNT_PATH=/media/veracrypt      # Where the volume will be mounted
VOLUME_PATH="passwords.hc"              # Path of the file used as the volume
VOLUME_SLOT=1                           # Volume slot

# Generates a random text
generate_random_text(){
    < /dev/urandom tr -dc 'A-Za-z0-9_@#%&*+=!?~$^{}[]<>|:;,.'
}

# Creates the volume according to the file specified in $VOLUME_PATH
create_volume(){
    random=$(mktemp)
    echo $( generate_random_text | head -c 350) > $random

    veracrypt -t -c "$VOLUME_PATH" --volume-type 'normal' --size=1M --encryption AES-Twofish \
        --hash SHA-256 --filesystem fat --pim 0 --keyfiles "" --random-source $random -p $VOLUME_PASSWORD > /dev/null
}

# Mount (encrypts) the volume, last action of the program
mount_volume(){
    output_file=$(mktemp)
    veracrypt -t -l 1> "$output_file" 1> "$output_file" 2>/dev/null
    if test -s "$output_file"; then
        max_current_slot=$(tail -n 1 "$output_file" | cut -d":" -f1)
        VOLUME_SLOT=$(($max_current_slot + 1)) 
    fi

    error_file=$(mktemp)
    veracrypt -t "$VOLUME_PATH" $VOLUME_MOUNT_PATH -p $VOLUME_PASSWORD --non-interactive --pim 0 --keyfiles "" --protect-hidden no \
        --slot $VOLUME_SLOT 1> "$output_file" 2> "$error_file"

    if test -s "$error_file"; then
        echo "Error mouting volume"
        exit 1
    fi

    touch "$VOLUME_MOUNT_PATH/$FILE_PATH"
}

# Desmonta ( criptografa ) o volume, última ação do programa
dismount_volume(){
    veracrypt -t -d "$VOLUME_PATH" --slot $VOLUME_SLOT 
}

# Generates a random password
generate_password(){
    password="$(generate_random_text | head -c 20)"
    echo "$password" | xclip -selection clipboard
    echo -e "The generated password has been copied to the clipboard"
}

# Retrieves the password for a credential by its ID shown in the listing
get_password(){
    local password="$(awk -v n="$1" 'NR==n {print $2}' $VOLUME_MOUNT_PATH/$FILE_PATH)"
    if test -z $password; 
    then
       echo "Credentials with id '$1' not found"
       exit 1
    fi

    echo "$password" | xclip -selection clipboard
    echo "Password of '$(awk -v n="$1" 'NR==n {print $1}' "$VOLUME_MOUNT_PATH/$FILE_PATH")' copied to the clipboard and will be deleted from it after 30 seconds"
    (sleep 30 && echo -n | xclip -selection clipboard) &
}

# Lists the credentials
list_credentials(){ 
    if [ ! -s "$VOLUME_MOUNT_PATH/$FILE_PATH" ]; then
        echo List of credentials:
        awk '{printf "\nID: %d\nE-mail: %s\nPassword: ******\nDescription: %s\n\n----------------\n", NR, $1, $3}' "$VOLUME_MOUNT_PATH/$FILE_PATH"
    else
        echo "No credentials saved"
    fi
}

# Adds credentials
add_credentials(){
    echo -n "E-mail: "
    read -r email
    echo -n "Password (press ENTER to generate randomly): "
    read -s -r password
    echo -e -n -r "\nDescription: "
    read description

    if test -z "$password"
    then
        password="$(generate_random_text | head -c 20)"
    fi

    echo -e "$email\t$password\t$description" >> "$VOLUME_MOUNT_PATH/$FILE_PATH"
    echo Credentials successfully added!
}

# Removes credentials
remove_credentials(){
    awk -v n="$1" 'NR!=n' "$VOLUME_MOUNT_PATH/$FILE_PATH" > "$VOLUME_MOUNT_PATH/$FILE_PATH.tmp"
    mv "$VOLUME_MOUNT_PATH/$FILE_PATH.tmp" "$VOLUME_MOUNT_PATH/$FILE_PATH"
    echo Credentials successfully deleted!
}

run(){
    case "$1" in
        "" | --list          )
            list_credentials
            exit 1
        ;;
        --generate-pass       )
            generate_password
            exit 0
        ;;
        --add       )
            add_credentials
            exit 0
        ;;
        --get-pass    )
            shift
            get_password "$1"
            exit 0
        ;;
        --remove    )
            shift;
            remove_credentials "$1"
            exit 0
        ;;
        *           )
            echo Invalid option: "$1"
            exit 1
        ;;
    esac
}

if [ "$1" == "--help" ]; then
    echo "$HELP_MESSAGE"
    exit 0
fi

# Creates the volume and accesses the program
if [ "$1" == "--create-volume" ]; then
    create_volume
    echo "Volume successfully created in $FILE_PATH"
    exit 0
fi

# Always the last action executed, even if the program ends with an error
trap 'dismount_volume' EXIT

mount_volume
run "$@"