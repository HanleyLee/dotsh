# Author: Hanley Lee
# Website: https://www.hanleylee.com
# GitHub: https://github.com/hanleylee
# License:  MIT License

# set -e # 有一个未通过立刻终止脚本
# set -x # 显示所有步骤

# Quick change directories, Expands .... -> ../../../
function smartdots() {
    if [[ $LBUFFER = *.. ]]; then
        LBUFFER+=/..
    else
        LBUFFER+=.
    fi
}

function whichd() {
    if type "$1" | grep -q 'is a shell function'; then
        type "$1"
        which "$1"
    elif type "$1" | grep -q 'is an alias'; then
        PS4='+%x:%I>' zsh -i -x -c '' |& grep '>alias ' | grep "${1}="
    else
        type "$1"
    fi
}

# 快速查找当前目录下的文件
function s () {
    find . -name "*$1*"
}

# 在 xcode 中打开当前目录下的工程
function ofx() {
    open ./*.xcworkspace || open ./*.xcodeproj || open ./Package.swift
} 2> /dev/null

# print the path of current file of MacVim's front window
function pfmv() {
    osascript <<'EOF'
tell application "MacVim"
    set window_title to name of window 1
    set is_empty to offset of "[NO NAME]" in window_title
    if is_empty is 0 then
        set cwd to do shell script "echo '" & window_title & "' |sed 's/.* (\\(.*\\)).*/\\1/'" & " |sed \"s,^~,$HOME,\""
        return cwd
    end if
end tell
EOF
}

# use MacVim to edit the current file of Xcode
function mvxc() {
    # either of the below method is acceptable
    # open -a MacVim `pfxc`
    osascript <<EOF
tell application "MacVim"
    activate
    set current_document_path to "$(pfxc)"
    if (current_document_path is not "") then
        open current_document_path
        return
    end if
end tell
EOF
}

# cd to the path of MacVim's current working directory
function cdmv() {
    cd "$(pfmv)"
}

# function cdit() {
#   cd "$(pfit)"
# }

function repeat() {
    local i max
    max=$1
    shift
    for ((i = 1; i <= max; i++)); do # --> C-like syntax
        eval "$@"
    done
}

# Go back up N directories
function up() {
    if [[ $# -eq 0 ]]; then
        cd "../"
    elif [[ $# -eq 1 ]] && [[ $1 -gt 0 ]]; then
        local up_dir=""
        for _ in $(seq 1 "$1"); do
            up_dir+="../"
        done
        cd "$up_dir" || return 1
    else
        echo "Usage: up [n]"
        return 1
    fi
}

# Pretty diff
function pdiff() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: pdiff file1 file2"
        return 1
    fi

    if [[ -x $(command -v delta) ]]; then
        delta "$1" "$2"
    else
        diff -s -u --color=always "$1" "$2"
    fi
}

function benchmark_zsh() {
    for i in $(seq 1 20); do
        /usr/bin/time /bin/zsh --no-rcs -i -c exit
    done
}

function light() {
    if [ -z "$2" ]; then
        src="pbpaste"
    else
        src="cat $2"
    fi
    eval "$src" | highlight -O rtf --syntax="$1" -k "Fira Code" --style=solarized-dark --font-size 24 | pbcopy
}

function nocolor () {
    sed -r 's:\x1b\[[0-9;]*[mK]::g;s:[\r\x0f]::g'
}

# 删除空文件
function rmempty () {
    for i; do
        [[ -f $i && ! -s $i ]] && rm $i
    done
    return 0
}

# 断掉软链接
function breakln () {
    for f in $*; do
        tgt=$(readlink "$f")
        unlink "$f"
        cp -rL "$tgt" "$f"
    done
}

# 使用伪终端代替管道，对 ls 这种“顽固分子”有效 {{{2
function ptyrun () {
    local ptyname=pty-$$
    zmodload zsh/zpty
    zpty $ptyname "${(q)@}"
    if [[ ! -t 1 ]]; then
        setopt local_traps
        trap '' INT
    fi
    zpty -r $ptyname
    zpty -d $ptyname
}

function ptyless () {
    ptyrun "$@" | tr -d $'\x0f' | less
}

# 文件名从 GB 转码, 带确认
function mvgb () {
    for i in $*; do
        new="$(echo $i|iconv -f utf8 -t latin1|iconv -f gbk)"
        echo $new
        echo -n 'Sure? '
        read -q ans && mv -i $i $new
        echo
    done
}

function pid () {
    s=0
    for i in $*; do
        i=${i/,/}
        echo -n "$i: "
        r=$(cat /proc/$i/cmdline|tr '\0' ' ' 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            echo not found
            s=1
        else
            echo $r
        fi
    done
    return $s
}

# query XMPP SRV records
function xmpphost () {
    host -t SRV _xmpp-client._tcp.$1
    host -t SRV _xmpp-server._tcp.$1
}

# 反复重试, 直到成功
function try_until_success () {
    local i=1
    while true; do
        echo "Try $i at $(date)."
        $* && break
        (( i+=1 ))
        echo
    done
}
compdef try_until_success=command

function wait_pid () {
    local pid=$1
    while true; do
        if [[ -d /proc/$pid ]]; then
            sleep 3
        else
            break
        fi
    done
}

function uName() {
    declare -A unameInfo
    unameInfo=( [kernel]=-s [kernel_release]=-r [os]=-o [cpu]=-p )
    for name com in ${(kv)unameInfo}; do
        res=$(uname $com)
        echo "$name -> $res"
    done
}

if is_darwin; then
    function show_current_wifi_ssid() {
        /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ SSID/ {print substr($0, index($0, $2))}'
    }

    function show_wifi_password() {
        ssid=$1
        security find-generic-password -D "AirPort network password" -a $ssid -gw
    }

    function show_current_wifi_password() {
        ssid=$(show_current_wifi_ssid)

        show_wifi_password $ssid
    }
fi

if command_exists code; then
    # 在 vscode 中打开当前 finder 的文件夹
    function codef() {
        code "$(pfd)"
    }
fi

if command_exists lazygit; then
    function lgf() {
        export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

        lazygit "$@"

        if [ -f "$LAZYGIT_NEW_DIR_FILE" ]; then
            cd "$(cat "$LAZYGIT_NEW_DIR_FILE")"
            rm -f "$LAZYGIT_NEW_DIR_FILE" >/dev/null
        fi
    }
fi

if command_exists tmux; then
    # tmux attach
    function ta() {
        test -z "$TMUX" && (tmux attach || tmux new-session)
    }
fi

if command_exists scmpuff; then
    function gdf() {
        params="$*"
        if brew ls --versions scmpuff >/dev/null; then
            params=$(scmpuff expand "$@" 2>/dev/null)
        fi

        if [ $# -eq 0 ]; then
            git difftool --no-prompt --extcmd "icdiff --line-numbers --no-bold" | less
        elif [ ${#params} -eq 0 ]; then
            git difftool --no-prompt --extcmd "icdiff --line-numbers --no-bold" "$@" | less
        else
            git difftool --no-prompt --extcmd "icdiff --line-numbers --no-bold" "$params" | less
        fi
    }
fi

if command_exists apt; then
    # Update and upgrade packages
    function apt-update() {
        sudo apt update
        sudo apt -y upgrade
    }

    # Clean packages
    function apt-clean() {
        sudo apt -y autoremove
        sudo apt-get -y autoclean
        sudo apt-get -y clean
    }

    # List intentionally installed packages
    function apt-list() {
        (
        zcat "$(ls -tr /var/log/apt/history.log*.gz)"
        cat /var/log/apt/history.log
        ) 2>/dev/null |
            grep -E '^Commandline' |
            sed -e 's/Commandline: \(.*\)/\1/' |
            grep -E -v '^/usr/bin/unattended-upgrade$'
    }
fi

# *************** zoxide *****************
if command_exists zi; then
    function _zi {
        zi
        if [[ -z "$lines" ]]; then
            zle && zle reset-prompt
            # zle && zle redraw-prompt
        fi
    }
fi

# function _fish_collapsed_pwd() {
#     local pwd="$1"
#     local home="$HOME"
#     local size=${#home}
#     [[ $# == 0 ]] && pwd="$PWD"
#     [[ -z "$pwd" ]] && return
#     if [[ "$pwd" == "/" ]]; then
#         echo "/"
#         return
#     elif [[ "$pwd" == "$home" ]]; then
#         echo "~"
#         return
#     fi
#     [[ "$pwd" == "$home/"* ]] && pwd="~${pwd:$size}"
#     if [[ -n "$BASH_VERSION" ]]; then
#         local IFS="/"
#         local elements=($pwd)
#         local length=${#elements[@]}
#         for ((i=0;i<length-1;i++)); do
#             local elem=${elements[$i]}
#             if [[ ${#elem} -gt 1 ]]; then
#                 elements[$i]=${elem:0:1}
#             fi
#         done
#     else
#         local elements=("${(s:/:)pwd}")
#         local length=${#elements}
#         for i in {1..$((length-1))}; do
#             local elem=${elements[$i]}
#             if [[ ${#elem} > 1 ]]; then
#                 elements[$i]=${elem[1]}
#             fi
#         done
#     fi
#     local IFS="/"
#     echo "${elements[*]}"
# }