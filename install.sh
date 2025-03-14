#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}出于安全考虑，安装/更新完成后需要强制修改端口与账户密码${plain}"
    read -p "确认是否继续?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置您的账户名:" config_account
        echo -e "${yellow}您的账户名将设定为:${config_account}${plain}"
        read -p "请设置您的账户密码:" config_password
        echo -e "${yellow}您的账户密码将设定为:${config_password}${plain}"
        read -p "请设置面板访问端口:" config_port
        echo -e "${yellow}您的面板访问端口将设定为:${config_port}${plain}"
        ~/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}账户密码设定完成${plain}"
        ~/x-ui/x-ui setting -port ${config_port}
        echo -e "\n${yellow}面板端口设定完成${plain}"
    else
        echo -e "${red}已取消,所有设置项均为默认设置,请及时修改${plain}"
    fi
}

install_x-ui() {

    cd ~

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/hxulin/serv00-x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 x-ui 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 x-ui 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 x-ui 最新版本：${last_version}，开始安装"
        wget -N --no-check-certificate -O x-ui-freebsd-amd64.tar.gz https://github.com/hxulin/serv00-x-ui/releases/download/${last_version}/x-ui-freebsd-amd64.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/hxulin/serv00-x-ui/releases/download/${last_version}/x-ui-freebsd-amd64.tar.gz"
        echo -e "开始安装 x-ui v$1"
        wget -N --no-check-certificate -O x-ui-freebsd-amd64.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui v$1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    if [[ -e ~/x-ui/ ]]; then
        rm -rf ~/x-ui/
    fi

    tar zxvf x-ui-freebsd-amd64.tar.gz
    rm -f x-ui-freebsd-amd64.tar.gz
    cd x-ui
    chmod +x x-ui bin/xray-freebsd-amd64
    wget --no-check-certificate -O x-ui.sh https://raw.githubusercontent.com/hxulin/serv00-x-ui/main/x-ui.sh
    chmod +x x-ui.sh
    config_after_install
    echo -e "${green}x-ui ${last_version}${plain} 安装完成，面板已启动"
    echo -e ""
    echo 'alias x-ui="/home/'$USER'/x-ui/x-ui.sh"' >> ~/.profile
    echo "x-ui alias 添加到 ~/.profile 文件完成"
    echo -e "${yellow}重新登录 SSH 终端可直接使用 x-ui 命令${plain}"
    echo -e ""
    echo -e "x-ui 管理脚本使用方法: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - 显示管理菜单 (功能更多)"
    echo -e "x-ui start        - 启动 x-ui 面板"
    echo -e "x-ui stop         - 停止 x-ui 面板"
    echo -e "x-ui restart      - 重启 x-ui 面板"
    echo -e "x-ui status       - 查看 x-ui 状态"
    echo -e "x-ui enable       - 设置 x-ui 开机自启"
    echo -e "x-ui disable      - 取消 x-ui 开机自启"
    echo -e "x-ui update       - 更新 x-ui 面板"
    echo -e "x-ui install      - 安装 x-ui 面板"
    echo -e "x-ui uninstall    - 卸载 x-ui 面板"
    echo -e "----------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_x-ui $1
