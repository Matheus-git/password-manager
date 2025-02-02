#!/bin/bash
#
# passwords.sh
# Armazena senhas em um arquivo criptografado e gerencia seu acesso
#
# Author: Matheus Silva Sores
#
CONFIG="passwords.conf"
FILE_PATH="passwords.txt"
VOLUME_MOUNT_PATH=/media/veracrypt
VOLUME_PATH="passwords.hc"
VOLUME_SLOT=1
VOLUME_PASSWORD=teste

generate_random_text(){
    < /dev/urandom tr -dc 'A-Za-z0-9_@#%&*+=!?~$^{}[]<>|:;,.'
}

create_volume(){
    test -f $VOLUME_PATH || touch $VOLUME_PATH

    random=$(mktemp)
    echo $( generate_random_text | head -c 350) > $random

    veracrypt -t -c "$VOLUME_PATH" --volume-type 'normal' --size=1M --encryption AES-Twofish \
        --hash SHA-256 --filesystem fat --pim 0 --keyfiles "" --random-source $random -p $VOLUME_PASSWORD > /dev/null
}

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

    test -f "$VOLUME_MOUNT_PATH/$FILE_PATH" || touch "$VOLUME_MOUNT_PATH/$FILE_PATH"
}

dismount_volume(){
    veracrypt -t -d "$VOLUME_PATH" --slot $VOLUME_SLOT 
}

generate_password(){
    password="$(generate_random_text | head -c 20)"
    echo "$password" | xclip -selection clipboard
    echo -e "The generated password has been copied to the clipboard"
}

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

list_credentials(){ 
    awk '{printf "\nID: %d\nE-mail: %s\nPassword: ******\nDescription: %s\n\n----------------\n", NR, $1, $3}' "$VOLUME_MOUNT_PATH/$FILE_PATH"
}

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
}

remove_credentials(){
    awk -v n="$1" 'NR!=n' "$VOLUME_MOUNT_PATH/$FILE_PATH" > "$VOLUME_MOUNT_PATH/$FILE_PATH.tmp"
    mv "$VOLUME_MOUNT_PATH/$FILE_PATH.tmp" "$VOLUME_MOUNT_PATH/$FILE_PATH"
}

run(){
    case "$1" in
        ""          )
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

#Pipeline
if [ "$1" == "--create-volume" ]; then
    create_volume
    echo "Volume successfully created in $FILE_PATH"
    exit 0
fi

trap 'dismount_volume' EXIT

mount_volume
run "$@"