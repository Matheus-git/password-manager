#!/bin/bash
#
# passwords.sh
# Armazena senhas em um arquivo criptografado e gerencia seu acesso
#
# Author: Matheus Silva Sores
#
CONFIG="passwords.conf"
FILE_PATH="passwords.txt"

if test -z "$1"; then 
    awk '{print NR, $1, "******", $3}' passwords.txt | column -t -s' ' 
    exit 1
fi

case "$1" in
    --pass       )
        password="$(< /dev/urandom tr -dc 'A-Za-z0-9_@#%&*+=!?~$^{}[]<>|:;,.' | head -c 20)"
        echo "$password"| xclip -selection clipboard
        echo -e "Senha gerada foi copiada para a área de transferência"

        exit 0
    ;;
    --add       )
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
        exit 0
    ;;
    --get-pass    )
        shift;
        awk -v n="$1" 'NR==n {print $2}' "$FILE_PATH" | xclip -selection clipboard
        echo "Senha de '$(awk -v n="$1" 'NR==n {print $1}' "$FILE_PATH")' copiada para a área de transferência e será apagada dela após 30 segundos"
        (sleep 30 && echo -n | xclip -selection clipboard) &
        exit 0
    ;;
    --remove    )
        shift;
        echo "$(awk -v n="$1" 'NR!=n' "$FILE_PATH")" > "$FILE_PATH"
        exit 0
    ;;
    *           )
        echo Opção inválida: $1
        exit 1
    ;;
esac