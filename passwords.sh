#!/bin/bash
#
# passwords.sh
# Armazena senhas em um arquivo criptografado e gerencia seu acesso
#
# Author: Matheus Silva Sores
#
CONFIG="passwords.conf"
FILE_PATH="passwords.txt"
VOLUME_PATH="abacate.hc"
VOLUME_SLOT=1

create_volume(){
    veracrypt -t -c "$VOLUME_PATH" --volume-type 'normal' --size=1M --encryption AES-Twofish --hash SHA-256 --filesystem fat --pim 0 --keyfiles "" --random-source "random.txt" -p 'teste' > /dev/null
}

mount_volume(){
    output_file=$(mktemp)
    error_file=$(mktemp)

    veracrypt -t -l 1> "$output_file" 2> "$error_file"
    if test -s "$error_file"; then
        VOLUME_SLOT="1"
    else
        max_current_slot=$(tail -n 1 "$output_file" | cut -d":" -f1)
        VOLUME_SLOT=$((max_current_slot + 1)) 
    fi

    veracrypt -t "$VOLUME_PATH" /media/veracrypt1 -p teste --non-interactive --pim 0 --keyfiles "" --protect-hidden no --slot $VOLUME_SLOT 1> "$output_file" 2> "$error_file"
}

dismount_volume(){
    veracrypt -t -d "$VOLUME_PATH" --slot $VOLUME_SLOT
}

generate_password(){
    password="$(< /dev/urandom tr -dc 'A-Za-z0-9_@#%&*+=!?~$^{}[]<>|:;,.' | head -c 20)"
    echo "$password"| xclip -selection clipboard
    echo -e "Senha gerada foi copiada para a área de transferência"
}

get_password(){
    awk -v n="$1" 'NR==n {print $2}' "$FILE_PATH" | xclip -selection clipboard
    echo "Senha de '$(awk -v n="$1" 'NR==n {print $1}' "$FILE_PATH")' copiada para a área de transferência e será apagada dela após 30 segundos"
    (sleep 30 && echo -n | xclip -selection clipboard) &
}

list_credentials(){
    awk '{print NR, $1, "******", $3}' passwords.txt | column -t -s' '
}

add_credentials(){
    echo -n "E-mail: "
    read email
    echo -n "Senha(pressione ENTER para criar aleatória): "
    read -s password
    echo -e -n "\nDescrição: "
    read description

    if test -z "$password"
    then
        password="$(< /dev/urandom tr -dc 'A-Za-z0-9_@#%&*+=!?~$^{}[]<>|:;,.' | head -c 20)"
    fi

    echo -e "$email\t$password\t$description" >> "$FILE_PATH"
}

remove_credentials(){
    local temp_file
    temp_file=$(mktemp)
    awk -v n="$1" 'NR!=n' "$FILE_PATH" > "$temp_file" && mv "$temp_file" "$FILE_PATH"
}

run(){
    case "$1" in
        ""          )
            list_credentials
            exit 1
        ;;
        --pass       )
            generate_password
            exit 0
        ;;
        --add       )
            add_credentials
            exit 0
        ;;
        --get-pass    )
            shift;
            get_password
            exit 0
        ;;
        --remove    )
            shift;
            remove_credentials
            exit 0
        ;;
        *           )
            echo Opção inválida: $1
            exit 1
        ;;
    esac
}

#Pipeline
# trap 'dismount_volume' EXIT
# create_volume
mount_volume