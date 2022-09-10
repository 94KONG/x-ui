#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Ошибка: ${plain} Этот скрипт должен быть запущен как пользователь root！\n" && exit 1

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
    echo -e "${red}Версия системы не обнаружена, обратитесь к автору скрипта！${plain}\n" && exit 1
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
        echo -e "${red}Пожалуйста, используйте CentOS 7 или выше！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Пожалуйста, используйте Ubuntu 16 или более позднюю версию！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Пожалуйста, используйте Debian 8 или выше！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Дефолт$2]: " temp
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
    confirm "Следует ли перезапустить панель, перезапуск панели также перезапустит xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Нажмите Enter, чтобы вернуться в главное меню: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/94KONG/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Эта функция принудительно переустановит текущую последнюю версию, данные не будут потеряны, следует ли продолжать?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}Отменено${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/94KONG/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green}Обновление завершено, панель автоматически перезапустилась${plain}"
        exit 0
    fi
}

uninstall() {
    confirm "Вы уверены, что хотите удалить панель, xray также удалит?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "Удаление прошло успешно, если вы хотите удалить этот скрипт, запустите после выхода из скрипта ${green}rm /usr/bin/x-ui -f${plain} удалить"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Вы уверены, что хотите сбросить имя пользователя и пароль на admin" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Имя пользователя и пароль были сброшены на ${green}admin${plain}，Пожалуйста, перезапустите панель сейчас"
    confirm_restart
}

reset_config() {
    confirm "Вы уверены, что хотите сбросить все настройки панели, данные учетной записи не будут потеряны, имя пользователя и пароль не будут изменены" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "Все настройки панели были сброшены на значения по умолчанию, пожалуйста, перезапустите панель сейчас и используйте настройки по умолчанию. ${green}54321${plain} Панель доступа к портам"
    confirm_restart
}

set_port() {
    echo && echo -n -e "Введите номер порта[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow}Отменено${plain}"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "После настройки порта перезапустите панель и используйте только что установленный порт. ${green}${port}${plain} Панель доступа"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Панель уже запущена, перезапускать не нужно, если вы хотите перезапустить, выберите перезапуск${plain}"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}xx-ui успешно запущен${plain}"
        else
            echo -e "${red}Панель не запустилась, возможно, из-за того, что время запуска превысило две секунды, пожалуйста, проверьте информацию журнала позже${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green}Панель остановилась, нет необходимости останавливать снова${plain}"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}x-ui и xray успешно останавливаются${plain}"
        else
            echo -e "${red}Панель не удалось остановить, возможно, из-за того, что время остановки превысило две секунды. Пожалуйста, проверьте информацию журнала позже.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui и xray успешно перезапущены${plain}"
    else
        echo -e "${red}Панель не перезапустилась, возможно, из-за того, что время запуска превысило две секунды, пожалуйста, проверьте информацию журнала позже${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui настроить загрузку на успешный запуск${plain}"
    else
        echo -e "${red}x-ui не удалось установить автозапуск при загрузке${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui успешно отменяет самозапуск загрузки${plain}"
    else
        echo -e "${red}x-ui не удалось отменить автозапуск загрузки${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://raw.githubusercontent.com/94KONG/x-ui/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Не удалось загрузить скрипт, проверьте, может ли машина подключиться к Github.${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        echo -e "${green}Сценарий обновления выполнен успешно. Повторите сценарий.${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Панель уже установлена, пожалуйста, не устанавливайте ее снова${plain}"
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
        echo -e "${red}Сначала установите панель${plain}"
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
            echo -e "Статус панели: ${green}Была запущена${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Статус панели: ${yellow}Не работает (Или не загруженна)${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Статус панели: ${red}Не установлена${plain}"
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Запускаться ли автоматически: ${green}Да${plain}"
    else
        echo -e "Запускаться ли автоматически: ${red}Нет${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray статус: ${green}Работает${plain}"
    else
        echo -e "xray статус: ${red}Не работает${plain}"
    fi
}

show_usage() {
    echo "Как использовать скрипт управления x-ui: "
    echo "------------------------------------------"
    echo "x-ui              - Показать меню управления (больше функций)"
    echo "x-ui start        - Запустите панель x-ui"
    echo "x-ui stop         - Остановить панель x-ui"
    echo "x-ui restart      - Перезапустите панель x-ui"
    echo "x-ui status       - Просмотр статуса x-ui"
    echo "x-ui enable       - Установите x-ui для автоматического запуска при загрузке"
    echo "x-ui disable      - Отменить автозапуск загрузки x-ui"
    echo "x-ui log          - Просмотр логов x-ui"
    echo "x-ui v2-ui        - Перенесите данные учетной записи v2-ui этого компьютера в x-ui"
    echo "x-ui update       - Обновление панели x-ui"
    echo "x-ui install      - Установите панель x-ui"
    echo "x-ui uninstall    - Удалить панель x-ui"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Скрипт управления панелью x-ui${plain}
  ${green}0.${plain} Сценарий выхода
————————————————
  ${green}1.${plain} Установить x-ui
  ${green}2.${plain} Обновить x-ui
  ${green}3.${plain} Удалить нахуй x-ui
————————————————
  ${green}4.${plain} Сбросить пароль пользователя
  ${green}5.${plain} Сбросить настройки панели
  ${green}6.${plain} Настройка портов панели
————————————————
  ${green}7.${plain} Запустить x-ui
  ${green}8.${plain} Остановка x-ui
  ${green}9.${plain} Перезагрузка x-ui
 ${green}10.${plain} Просмотр статуса x-ui
 ${green}11.${plain} Просмотр журналов x-ui
————————————————
 ${green}12.${plain} Установите x-ui для автоматического запуска при загрузке
 ${green}13.${plain} Отменить автозапуск загрузки x-ui
————————————————
 ${green}14.${plain} 一Установка ключа bbr (Последнее ядро)
 "
    show_status
    echo && read -p "Пожалуйста, введите выбор [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && reset_user
        ;;
        5) check_install && reset_config
        ;;
        6) check_install && set_port
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && status
        ;;
        11) check_install && show_log
        ;;
        12) check_install && enable
        ;;
        13) check_install && disable
        ;;
        14) install_bbr
        ;;
        *) echo -e "${red}Пожалуйста, введите правильный номер [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "v2-ui") check_install 0 && migrate_v2_ui 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
