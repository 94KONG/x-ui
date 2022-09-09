#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Ошибка：${plain} Этот скрипт должен быть запущен как пользователь root！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Версия системы не обнаружена，Пожалуйста, свяжитесь с автором сценария！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}Не удалось обнаружить схему，Использовать схему по умолчанию: ${arch}${plain}"
fi

echo "Архитектура: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
    echo "Это программное обеспечение не поддерживает 32-битную систему (x86), используйте 64-битную систему (x86_64), если обнаружение неверно, свяжитесь с автором"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Пожалуйста, используйте CentOS 7 или более поздняя систему！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Пожалуйста, используйте Ubuntu 16 или более поздняя систему！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Пожалуйста, используйте Debian 8 или более поздняя систему！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Обнаружить x-ui верс не удалось，может быть из за Github API ограничения，Пожалуйста, попробуйте позже，Или вручную указать версию x-ui для установки${plain}"
            exit 1
        fi
        echo -e "Обнаружена последняя версия x-ui：${last_version}，Начать установку"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Не удалось загрузить x-ui, убедитесь, что ваш сервер может загружать файлы Github.${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Начать установку x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Скачать x-ui v$1 не удалось, убедитесь, что эта версия существует${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch} x-ui.sh
    cp -f x-ui.service /etc/systemd/system/
    cp -f x-ui.sh /usr/bin/x-ui
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} Установка завершена, панель запущена，"
    echo -e ""
    echo -e "Если это новая установка, веб-порт по умолчанию ${green}54321${plain}，Имя пользователя и пароль по умолчанию ${green}admin${plain}"
    echo -e "Пожалуйста, убедитесь, что этот порт не занят другими программами，${yellow}И убедитесь 54321 порт открыт${plain}"
#    echo -e "Если ты хочешь 54321 изменить его на другой порт, введите команду x-ui для изменения, а также убедитесь, что порт, который вы изменяете, также открыт."
    echo -e ""
    echo -e "Если эта панель обновления, получите доступ к панели, как и раньше."
    echo -e ""
    echo -e "x-ui Как использовать скрипт управления: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Показать меню управления (больше функций)"
    echo -e "x-ui start        - Запустите панель x-ui"
    echo -e "x-ui stop         - Остановить панель x-ui"
    echo -e "x-ui restart      - Перезапустите панель x-ui"
    echo -e "x-ui status       - Просмотр статуса x-ui"
    echo -e "x-ui enable       - Установите x-ui для автоматического запуска при загрузке"
    echo -e "x-ui disable      - Отменить автозапуск загрузки x-ui"
    echo -e "x-ui log          - Просмотр логов x-ui"
    echo -e "x-ui v2-ui        - Перенесите данные учетной записи v2-ui этого компьютера в x-ui"
    echo -e "x-ui update       - Обновление панели x-ui"
    echo -e "x-ui install      - Установить панель x-ui"
    echo -e "x-ui uninstall    - Удалить панель x-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}Начать установку${plain}"
install_base
install_x-ui $1
