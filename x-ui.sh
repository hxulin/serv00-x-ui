#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启面板，重启面板也会重启 xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/hxulin/serv00-x-ui/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "本功能会强制重装当前最新版，数据不会丢失，是否继续?" "n"
    if [[ $? != 0 ]]; then
        LOGE "已取消"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/hxulin/serv00-x-ui/main/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "更新完成，已自动重启面板 "
        exit 0
    fi
}

uninstall() {
    confirm "确定要卸载面板吗,xray 也会卸载?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi

    crontab -l | grep -v 'x-ui run' | crontab -
    grep -v '^alias x-ui="/home/'$USER'/x-ui/x-ui.sh"$' ~/.profile > ~/.profile.tmp && mv ~/.profile.tmp ~/.profile
    cd ~
    rm -rf x-ui/

    echo ""
    echo -e "卸载成功"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "确定要将用户名和密码重置为 admin 吗" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    ~/x-ui/x-ui setting -username admin -password admin
    echo -e "用户名和密码已重置为 ${green}admin${plain}，现在请重启面板"
    confirm_restart
}

reset_config() {
    confirm "确定要重置所有面板设置吗，账号数据不会丢失，用户名和密码不会改变" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    ~/x-ui/x-ui setting -reset
    echo -e "所有面板设置已重置为默认值，现在请重启面板，并使用默认的 ${green}54321${plain} 端口访问面板"
    confirm_restart
}

check_config() {
    info=$(~/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "输入端口号[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "已取消"
        before_show_menu
    else
        ~/x-ui/x-ui setting -port ${port}
        echo -e "设置端口完毕，现在请重启面板，并使用新设置的端口 ${green}${port}${plain} 访问面板"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "面板已运行，无需再次启动，如需重启请选择重启"
    else
        cd ~/x-ui
        nohup ./x-ui run > ./x-ui.log 2>&1 &
        cd -
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui 启动成功"
        else
            LOGE "面板启动失败，可能是因为启动时间超过了两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop_x-ui() {
    # stop xray
    PID=$(pgrep -f "bin/xray-freebsd-amd64 -c bin/config.json")
    if [ ! -z "$PID" ]; then
        kill $PID
        if kill -0 $PID > /dev/null 2>&1; then
            kill -9 $PID
        fi
    fi

    # stop x-ui
    PID=$(pgrep -f "x-ui run")
    if [ ! -z "$PID" ]; then
        kill $PID
        if kill -0 $PID > /dev/null 2>&1; then
            kill -9 $PID
        fi
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "面板已停止，无需再次停止"
    else
        stop_x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui 与 xray 停止成功"
        else
            LOGE "面板停止失败，可能是因为停止时间超过了两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    stop 0
    start 0
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui 与 xray 重启成功"
    else
        LOGE "面板重启失败，可能是因为启动时间超过了两秒，请稍后查看日志信息"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    PID=$(pgrep -f "x-ui run")
    if [ ! -z "$PID" ]; then
        LOGI "x-ui 运行中"
    else
        LOGI "x-ui 没有运行"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    (crontab -l; echo "@reboot cd ~/x-ui && nohup ./x-ui run > ./x-ui.log 2>&1 &") | crontab -
    if [[ $? == 0 ]]; then
        LOGI "x-ui 设置开机自启成功"
    else
        LOGE "x-ui 设置开机自启失败"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    crontab -l | grep -v 'x-ui run' | crontab -
    if [[ $? == 0 ]]; then
        LOGI "x-ui 取消开机自启成功"
    else
        LOGE "x-ui 取消开机自启失败"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f ~/x-ui/x-ui ]]; then
        return 2
    fi
    PID=$(pgrep -f "x-ui run")
    if [ ! -z "$PID" ]; then
        return 0
    else
        return 1
    fi
}

check_enabled() { 
    crontab -l 2>/dev/null | grep -q 'x-ui run'
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "面板已安装，请不要重复安装"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "请先安装面板"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "面板状态: ${green}已运行${plain}"
        show_enable_status
        ;;
    1)
        echo -e "面板状态: ${yellow}未运行${plain}"
        show_enable_status
        ;;
    2)
        echo -e "面板状态: ${red}未安装${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自启: ${green}是${plain}"
    else
        echo -e "是否开机自启: ${red}否${plain}"
    fi
}

check_xray_status() {
    count=$(pgrep xray-freebsd-amd64 | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray 状态: ${green}运行${plain}"
    else
        echo -e "xray 状态: ${red}未运行${plain}"
    fi
}

show_usage() {
    echo "x-ui 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "x-ui              - 显示管理菜单 (功能更多)"
    echo "x-ui start        - 启动 x-ui 面板"
    echo "x-ui stop         - 停止 x-ui 面板"
    echo "x-ui restart      - 重启 x-ui 面板"
    echo "x-ui status       - 查看 x-ui 状态"
    echo "x-ui enable       - 设置 x-ui 开机自启"
    echo "x-ui disable      - 取消 x-ui 开机自启"
    echo "x-ui update       - 更新 x-ui 面板"
    echo "x-ui install      - 安装 x-ui 面板"
    echo "x-ui uninstall    - 卸载 x-ui 面板"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}x-ui 面板管理脚本${plain}
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 安装 x-ui
  ${green}2.${plain} 更新 x-ui
  ${green}3.${plain} 卸载 x-ui
————————————————
  ${green}4.${plain} 重置用户名密码
  ${green}5.${plain} 重置面板设置
  ${green}6.${plain} 设置面板端口
  ${green}7.${plain} 查看当前面板设置
————————————————
  ${green}8.${plain} 启动 x-ui
  ${green}9.${plain} 停止 x-ui
  ${green}10.${plain} 重启 x-ui
  ${green}11.${plain} 查看 x-ui 状态
  ${green}12.${plain} 设置流量监测端口
————————————————
  ${green}13.${plain} 设置 x-ui 开机自启
  ${green}14.${plain} 取消 x-ui 开机自启
 "
    show_status
    echo && read -p "请输入选择 [0-14]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && set_traffic_port
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    *)
        LOGE "请输入正确的数字 [0-14]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi