#!/bin/bash
set_colors() {
    black=""
    blue=""
    bold=""
    cyan=""
    green=""
    orange=""
    purple=""
    red=""
    reset=""
    white=""
    yellow=""
    hostStyle=""
    userStyle=""
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        tput sgr0 # reset colors
        bold="\001$(tput bold)\002"
        reset="\001$(tput sgr0)\002"
        # Solarized colors
        # (https://github.com/altercation/solarized/tree/master/iterm2-colors-solarized#the-values)
        #
        # SO life-saving comment on echoing colors inside a function and having bash assume correct prompt length:
        #   Welcome to 2017! For future travelers, the simplest answer is: stackoverflow.com/a/43462720/746890. 
        #   (i.e. Just swap \[ for \001 and \[ for \002.) – Chris Nolet Apr 22 '17 at 0:46
        black="\001$(tput setaf 0)\002"
        blue="\001$(tput setaf 33)\002"
        cyan="\001$(tput setaf 37)\002"
        green="\001$(tput setaf 64)\002"
        orange="\001$(tput setaf 166)\002"
        purple="\001$(tput setaf 125)\002"
        red="\001$(tput setaf 124)\002"
        white="\001$(tput setaf 15)\002"
        yellow="\001$(tput setaf 136)\002"
    else
        bold=""
        reset="\e[0m"
        black="\e[1;30m"
        blue="\e[1;34m"
        cyan="\e[1;36m"
        green="\e[1;32m"
        orange="\e[1;33m"
        purple="\e[1;35m"
        red="\e[1;31m"
        white="\e[1;37m"
        yellow="\e[1;33m"
    fi
}
set_colors
unset set_colors