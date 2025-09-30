#!/bin/bash

# █████████████████████████████████████████████████████████████████████████
# █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ AREC INSTALLER ░░░░░░░░░░░░░░░░░░░░░░░░█
# █████████████████████████████████████████████████████████████████████████
# 
# Автоматический установщик для AREC (Audio Recording)
# Версия: 2.2
# Автор: AI Assistant
# 
# Этот скрипт:
# 1. Проверяет системные требования
# 2. Устанавливает необходимые пакеты
# 3. Настраивает systemd сервисы
# 4. Создает расписание работы
# 5. Проверяет работоспособность
#
# █████████████████████████████████████████████████████████████████████████

set -e  # Остановка при любой ошибке

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ И ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

# Цвета для вывода
BOLD="\033[1m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Версия скрипта
SCRIPT_VERSION="2.2"
INSTALL_DIR="/root/arec"
SERVICE_NAME="arec"
SCRIPT_NAME="arec.sh"

# Расписание по умолчанию
DEFAULT_START_TIME="06:00"
DEFAULT_STOP_TIME="23:30"

# ═══════════════════════════════════════════════════════════════════════════
# ФУНКЦИИ ВЫВОДА
# ═══════════════════════════════════════════════════════════════════════════

# Функция вывода заголовка
print_header() {
    echo -e "${BOLD}${BLUE}"
    echo "█████████████████████████████████████████████████████████████████████████"
    echo "█░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ AREC INSTALLER ░░░░░░░░░░░░░░░░░░░░░░░░█"
    echo "█████████████████████████████████████████████████████████████████████████"
    echo -e "${RESET}"
    echo -e "${CYAN}Версия: ${SCRIPT_VERSION}${RESET}"
    echo -e "${CYAN}Автоматическая установка системы записи аудио${RESET}"
    echo ""
}

# Функция вывода сообщения об успехе
print_success() {
    echo -e "${GREEN}✅ $1${RESET}"
}

# Функция вывода сообщения об ошибке
print_error() {
    echo -e "${RED}❌ $1${RESET}"
}

# Функция вывода предупреждения
print_warning() {
    echo -e "${YELLOW}⚠️  $1${RESET}"
}

# Функция вывода информации
print_info() {
    echo -e "${BLUE}ℹ️  $1${RESET}"
}

# Функция вывода прогресса
print_progress() {
    echo -e "${CYAN}🔄 $1${RESET}"
}

# ═══════════════════════════════════════════════════════════════════════════
# ФУНКЦИИ ПРОВЕРКИ
# ═══════════════════════════════════════════════════════════════════════════

# Функция проверки прав root
check_root() {
    print_progress "Проверка прав доступа..."
    
    if [ "$EUID" -ne 0 ]; then
        print_error "Этот скрипт должен быть запущен с правами root"
        echo -e "${YELLOW}Используйте: sudo $0${RESET}"
        exit 1
    fi
    
    print_success "Права root подтверждены"
}

# Функция проверки операционной системы
check_os() {
    print_progress "Проверка операционной системы..."
    
    # Проверяем, что это Debian/Ubuntu
    if [ ! -f /etc/debian_version ]; then
        print_error "Этот скрипт предназначен для Debian/Ubuntu систем"
        exit 1
    fi
    
    # Проверяем версию
    local os_version
    os_version=$(lsb_release -rs 2>/dev/null || echo "unknown")
    
    print_success "Операционная система: $(lsb_release -ds 2>/dev/null || echo "Debian/Ubuntu")"
    print_info "Версия: $os_version"
}

# Функция проверки архитектуры
check_architecture() {
    print_progress "Проверка архитектуры..."
    
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        "armv7l"|"aarch64"|"x86_64")
            print_success "Архитектура поддерживается: $arch"
            ;;
        *)
            print_warning "Архитектура $arch может не поддерживаться"
            ;;
    esac
}

# Функция проверки свободного места
check_disk_space() {
    print_progress "Проверка свободного места на диске..."
    
    local available_space
    available_space=$(df / | tail -1 | awk '{print $4}')
    local required_space=1048576  # 1GB в килобайтах
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "Недостаточно места на диске"
        print_info "Требуется: 1GB, доступно: $((available_space / 1024))MB"
        exit 1
    fi
    
    print_success "Достаточно места на диске: $((available_space / 1024))MB"
}

# Функция проверки интернет-соединения
check_internet() {
    print_progress "Проверка интернет-соединения..."
    
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        print_warning "Нет интернет-соединения"
        print_info "Некоторые функции могут не работать"
    else
        print_success "Интернет-соединение активно"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ФУНКЦИИ УСТАНОВКИ
# ═══════════════════════════════════════════════════════════════════════════

# Функция обновления системы
update_system() {
    print_progress "Обновление списка пакетов..."
    
    apt update -qq
    
    print_success "Список пакетов обновлен"
}

# Функция установки пакетов
install_packages() {
    print_progress "Установка необходимых пакетов..."
    
    # Список необходимых пакетов
    local packages=(
        "ffmpeg"           # Кодирование аудио
        "rclone"           # Синхронизация с облаком
        "i2c-tools"        # Работа с RTC модулем
        "ntpdate"          # Синхронизация времени
        "alsa-utils"       # Работа с ALSA
        "curl"             # Загрузка файлов
        "wget"             # Загрузка файлов
        "unzip"            # Распаковка архивов
    )
    
    # Проверяем, какие пакеты уже установлены
    local packages_to_install=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            packages_to_install+=("$package")
        else
            print_info "Пакет $package уже установлен"
        fi
    done
    
    # Устанавливаем недостающие пакеты
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        print_info "Устанавливаем пакеты: ${packages_to_install[*]}"
        apt install -y "${packages_to_install[@]}"
        print_success "Пакеты установлены"
    else
        print_success "Все необходимые пакеты уже установлены"
    fi
}

# Функция создания директорий
create_directories() {
    print_progress "Создание рабочих директорий..."
    
    # Создаем основную директорию
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/pending"
    
    # Устанавливаем права
    chown root:root "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR/pending"
    
    print_success "Директории созданы: $INSTALL_DIR"
}

# Функция копирования скрипта
copy_script() {
    print_progress "Копирование скрипта записи..."
    
    # Проверяем наличие скрипта
    if [ ! -f "$SCRIPT_NAME" ]; then
        print_error "Файл $SCRIPT_NAME не найден в текущей директории"
        exit 1
    fi
    
    # Копируем скрипт
    cp "$SCRIPT_NAME" "$INSTALL_DIR/"
    
    # Устанавливаем права
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    chown root:root "$INSTALL_DIR/$SCRIPT_NAME"
    
    print_success "Скрипт скопирован: $INSTALL_DIR/$SCRIPT_NAME"
}

# ═══════════════════════════════════════════════════════════════════════════
# ФУНКЦИИ SYSTEMD
# ═══════════════════════════════════════════════════════════════════════════

# Функция создания основного сервиса
create_main_service() {
    print_progress "Создание основного systemd сервиса..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=AREC Audio Recording Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$SCRIPT_NAME
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Ограничения ресурсов
LimitNOFILE=65536
LimitNPROC=4096

# Безопасность
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    print_success "Основной сервис создан: $SERVICE_NAME.service"
}

# Функция создания сервиса запуска
create_start_service() {
    print_progress "Создание сервиса запуска..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME-start.service" << EOF
[Unit]
Description=Start AREC Audio Recording Service
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/bin/systemctl start $SERVICE_NAME.service
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    print_success "Сервис запуска создан: $SERVICE_NAME-start.service"
}

# Функция создания сервиса остановки
create_stop_service() {
    print_progress "Создание сервиса остановки..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME-stop.service" << EOF
[Unit]
Description=Stop AREC Audio Recording Service

[Service]
Type=oneshot
ExecStart=/bin/systemctl stop $SERVICE_NAME.service
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    print_success "Сервис остановки создан: $SERVICE_NAME-stop.service"
}

# Функция создания таймера запуска
create_start_timer() {
    print_progress "Создание таймера запуска..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME-start.timer" << EOF
[Unit]
Description=Start AREC Audio Recording at $DEFAULT_START_TIME
Requires=$SERVICE_NAME-start.service

[Timer]
OnCalendar=*-*-* $DEFAULT_START_TIME:00
Persistent=true
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

    print_success "Таймер запуска создан: $SERVICE_NAME-start.timer"
}

# Функция создания таймера остановки
create_stop_timer() {
    print_progress "Создание таймера остановки..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME-stop.timer" << EOF
[Unit]
Description=Stop AREC Audio Recording at $DEFAULT_STOP_TIME
Requires=$SERVICE_NAME-stop.service

[Timer]
OnCalendar=*-*-* $DEFAULT_STOP_TIME:00
Persistent=true
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

    print_success "Таймер остановки создан: $SERVICE_NAME-stop.timer"
}

# Функция настройки systemd
setup_systemd() {
    print_progress "Настройка systemd сервисов..."
    
    # Перезагружаем systemd
    systemctl daemon-reload
    
    # Включаем таймеры
    systemctl enable "$SERVICE_NAME-start.timer"
    systemctl enable "$SERVICE_NAME-stop.timer"
    
    # Запускаем таймеры
    systemctl start "$SERVICE_NAME-start.timer"
    systemctl start "$SERVICE_NAME-stop.timer"
    
    # Отключаем автозапуск основного сервиса (управляется таймерами)
    systemctl disable "$SERVICE_NAME.service"
    
    print_success "Systemd сервисы настроены"
}

# ═══════════════════════════════════════════════════════════════════════════
# ФУНКЦИИ ПРОВЕРКИ РАБОТОСПОСОБНОСТИ
# ═══════════════════════════════════════════════════════════════════════════

# Функция проверки ALSA
check_alsa() {
    print_progress "Проверка ALSA устройств..."
    
    if ! command -v arecord >/dev/null 2>&1; then
        print_error "arecord не найден"
        return 1
    fi
    
    # Проверяем доступные устройства
    local devices
    devices=$(arecord -l 2>/dev/null | wc -l)
    
    if [ "$devices" -eq 0 ]; then
        print_warning "ALSA устройства не найдены"
        print_info "Убедитесь, что микрофон подключен"
    else
        print_success "ALSA устройства найдены: $devices"
    fi
}

# Функция проверки FFmpeg
check_ffmpeg() {
    print_progress "Проверка FFmpeg..."
    
    if ! command -v ffmpeg >/dev/null 2>&1; then
        print_error "FFmpeg не найден"
        return 1
    fi
    
    local ffmpeg_version
    ffmpeg_version=$(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f3)
    
    print_success "FFmpeg установлен: $ffmpeg_version"
}

# Функция проверки rclone
check_rclone() {
    print_progress "Проверка rclone..."
    
    if ! command -v rclone >/dev/null 2>&1; then
        print_error "rclone не найден"
        return 1
    fi
    
    local rclone_version
    rclone_version=$(rclone version 2>/dev/null | head -1 | cut -d' ' -f2)
    
    print_success "rclone установлен: $rclone_version"
    print_info "Настройте rclone для работы с облаком: rclone config"
}

# Функция тестирования скрипта
test_script() {
    print_progress "Тестирование скрипта записи..."
    
    # Проверяем синтаксис
    if ! bash -n "$INSTALL_DIR/$SCRIPT_NAME"; then
        print_error "Синтаксическая ошибка в скрипте"
        return 1
    fi
    
    print_success "Синтаксис скрипта корректен"
}

# ═══════════════════════════════════════════════════════════════════════════
# ФУНКЦИИ ИНФОРМАЦИИ
# ═══════════════════════════════════════════════════════════════════════════

# Функция вывода информации об установке
show_installation_info() {
    echo ""
    echo -e "${BOLD}${GREEN}🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО! 🎉${RESET}"
    echo ""
    echo -e "${CYAN}📋 Информация об установке:${RESET}"
    echo -e "  • Директория: ${YELLOW}$INSTALL_DIR${RESET}"
    echo -e "  • Скрипт: ${YELLOW}$INSTALL_DIR/$SCRIPT_NAME${RESET}"
    echo -e "  • Сервис: ${YELLOW}$SERVICE_NAME.service${RESET}"
    echo -e "  • Расписание: ${YELLOW}$DEFAULT_START_TIME - $DEFAULT_STOP_TIME${RESET}"
    echo ""
    echo -e "${CYAN}🔧 Управление сервисом:${RESET}"
    echo -e "  • Статус: ${YELLOW}sudo systemctl status $SERVICE_NAME.service${RESET}"
    echo -e "  • Запуск: ${YELLOW}sudo systemctl start $SERVICE_NAME.service${RESET}"
    echo -e "  • Остановка: ${YELLOW}sudo systemctl stop $SERVICE_NAME.service${RESET}"
    echo -e "  • Перезапуск: ${YELLOW}sudo systemctl restart $SERVICE_NAME.service${RESET}"
    echo ""
    echo -e "${CYAN}⏰ Управление расписанием:${RESET}"
    echo -e "  • Статус таймеров: ${YELLOW}sudo systemctl list-timers | grep $SERVICE_NAME${RESET}"
    echo -e "  • Логи таймеров: ${YELLOW}sudo journalctl -u $SERVICE_NAME-start.timer -f${RESET}"
    echo ""
    echo -e "${CYAN}📝 Просмотр логов:${RESET}"
    echo -e "  • Логи сервиса: ${YELLOW}sudo journalctl -u $SERVICE_NAME.service -f${RESET}"
    echo -e "  • Логи скрипта: ${YELLOW}tail -f $INSTALL_DIR/arec.log${RESET}"
    echo ""
    echo -e "${CYAN}📁 Файлы записи:${RESET}"
    echo -e "  • Основная папка: ${YELLOW}$INSTALL_DIR${RESET}"
    echo -e "  • Очередь загрузки: ${YELLOW}$INSTALL_DIR/pending${RESET}"
    echo ""
    echo -e "${CYAN}⚙️ Настройка:${RESET}"
    echo -e "  • Редактировать скрипт: ${YELLOW}sudo nano $INSTALL_DIR/$SCRIPT_NAME${RESET}"
    echo -e "  • Настроить rclone: ${YELLOW}rclone config${RESET}"
    echo -e "  • Изменить расписание: ${YELLOW}sudo nano /etc/systemd/system/$SERVICE_NAME-start.timer${RESET}"
    echo ""
    echo -e "${YELLOW}⚠️  ВАЖНО:${RESET}"
    echo -e "  • Настройте rclone для работы с облаком"
    echo -e "  • Проверьте подключение микрофона"
    echo -e "  • Убедитесь в стабильности интернет-соединения"
    echo ""
    echo -e "${GREEN}✅ Система готова к работе!${RESET}"
}

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНАЯ ФУНКЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

# Главная функция установки
main() {
    # Выводим заголовок
    print_header
    
    # Проверки системы
    check_root
    check_os
    check_architecture
    check_disk_space
    check_internet
    
    echo ""
    print_progress "Начинаем установку AREC..."
    echo ""
    
    # Установка компонентов
    update_system
    install_packages
    create_directories
    copy_script
    
    # Настройка systemd
    create_main_service
    create_start_service
    create_stop_service
    create_start_timer
    create_stop_timer
    setup_systemd
    
    # Проверки работоспособности
    check_alsa
    check_ffmpeg
    check_rclone
    test_script
    
    # Выводим информацию об установке
    show_installation_info
}

# ═══════════════════════════════════════════════════════════════════════════
# ЗАПУСК СКРИПТА
# ═══════════════════════════════════════════════════════════════════════════

# Проверяем аргументы командной строки
case "${1:-}" in
    --help|-h)
        echo "AREC Installer v$SCRIPT_VERSION"
        echo ""
        echo "Использование: $0 [ОПЦИЯ]"
        echo ""
        echo "Опции:"
        echo "  --help, -h     Показать эту справку"
        echo "  --version, -v  Показать версию"
        echo ""
        echo "Примеры:"
        echo "  sudo $0        Установить AREC"
        echo "  sudo $0 --help Показать справку"
        exit 0
        ;;
    --version|-v)
        echo "AREC Installer v$SCRIPT_VERSION"
        exit 0
        ;;
    "")
        # Запускаем установку
        main
        ;;
    *)
        print_error "Неизвестная опция: $1"
        echo "Используйте $0 --help для справки"
        exit 1
        ;;
esac
