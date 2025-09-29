#!/bin/bash

# █████████████████████████████████████████████████████████████████████████
# █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ НАСТРОЙКИ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░█
# █████████████████████████████████████████████████████████████████████████

# Цвета для вывода
BOLD="\033[1m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# ═══════════════════════════════════════════════════════════════════════════
# ОСНОВНЫЕ ПАРАМЕТРЫ ЗАПИСИ
# ═══════════════════════════════════════════════════════════════════════════

SPLIT_TIME=1800               # Длительность одного файла в секундах (30 минут)
OUTPUT_DIR="/root/arec"       # Папка для сохранения записанных файлов
LOG_FILE="/root/arec/arec.log" # Файл для записи логов работы скрипта
SAMPLE_RATE=48000             # Частота дискретизации аудио (Гц)
MIC=""                        # Источник звука (пусто = автоопределение, default = микрофон по умолчанию)

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ КОДИРОВАНИЯ АУДИО
# ═══════════════════════════════════════════════════════════════════════════

AUDIO_FORMAT="opus"           # Формат аудио: aac, opus, mp3
BITRATE=64                    # Битрейт аудио в кбит/с (качество звука)

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ ОБЛАЧНОГО ХРАНИЛИЩА
# ═══════════════════════════════════════════════════════════════════════════

CLOUD_SERVICE="yandex"        # Облачный сервис: google, yandex, none (без облака)
DELETE_AFTER_UPLOAD=true      # Удалять файлы после успешной выгрузки
RETRY_DELAY=300               # Задержка между попытками загрузки (секунды)
MAX_RETRIES=15                # Максимальное количество попыток загрузки
CONNECTIVITY_CHECK_INTERVAL=600 # Интервал проверки интернет-соединения (секунды)
PENDING_DIR="/root/arec/pending" # Папка для файлов в очереди на загрузку
MAX_STORAGE_MB=40960          # Максимальный размер локального хранилища (МБ)
CONNECTIVITY_TIMEOUT=10       # Таймаут проверки сетевого соединения (секунды)

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ GOOGLE DRIVE
# ═══════════════════════════════════════════════════════════════════════════

GOOGLE_REMOTE="google.drive"  # Имя удаленного хранилища в rclone
GOOGLE_DIR="/Recordings"      # Папка на Google Drive для загрузки

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ ЯНДЕКС.ДИСК
# ═══════════════════════════════════════════════════════════════════════════

YANDEX_REMOTE="yandex.disk"   # Имя удаленного хранилища в rclone
YANDEX_DIR="/Recordings"      # Папка на Яндекс.Диске для загрузки

# █████████████████████████████████████████████████████████████████████████
# █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ФУНКЦИИ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░█
# █████████████████████████████████████████████████████████████████████████

# Функция выбора облачного сервиса (только если не задан в настройках)
select_cloud_service() {
    if [ -n "$CLOUD_SERVICE" ]; then
        printf "${GREEN}✔ Используется предустановленный сервис: $(get_cloud_name)${RESET}\n"
        return
    fi
    
    printf "${BOLD}${BLUE}☁ Выберите облачное хранилище:${RESET}\n"
    printf "${YELLOW}1)${RESET} Google Drive\n"
    printf "${YELLOW}2)${RESET} Яндекс.Диск\n"
    printf "${YELLOW}3)${RESET} Без облачного хранилища\n"
    printf "\n${BOLD}Введите номер (1-3): ${RESET}"
    
    while true; do
        read -r choice
        case "$choice" in
            1)
                CLOUD_SERVICE="google"
                printf "${GREEN}✔ Выбран Google Drive${RESET}\n"
                break
                ;;
            2)
                CLOUD_SERVICE="yandex"
                printf "${GREEN}✔ Выбран Яндекс.Диск${RESET}\n"
                break
                ;;
            3)
                CLOUD_SERVICE="none"
                printf "${GREEN}✔ Облачное хранилище отключено${RESET}\n"
                break
                ;;
            *)
                printf "${RED}✖ Неверный выбор. Введите 1, 2 или 3: ${RESET}"
                ;;
        esac
    done
}

# Функция получения настроек облачного сервиса
get_cloud_settings() {
    case "$CLOUD_SERVICE" in
        "google")
            echo "$GOOGLE_REMOTE:$GOOGLE_DIR"
            ;;
        "yandex")
            echo "$YANDEX_REMOTE:$YANDEX_DIR"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Функция получения имени облачного сервиса для отображения
get_cloud_name() {
    case "$CLOUD_SERVICE" in
        "google")
            echo "Google Drive"
            ;;
        "yandex")
            echo "Яндекс.Диск"
            ;;
        *)
            echo "локальное хранилище"
            ;;
    esac
}

# Функция проверки интернет-доступа (упрощенная для Pi Zero 2 W)
check_internet_access() {
    # Если облачное хранилище отключено, считаем что интернет доступен
    if [ "$CLOUD_SERVICE" = "none" ]; then
        return 0
    fi
    
    # Проверяем базовую связность
    if ! ping -c 1 -W "$CONNECTIVITY_TIMEOUT" "8.8.8.8" >/dev/null 2>&1; then
        return 1
    fi
    
    # Проверяем доступ к выбранному облачному сервису
    case "$CLOUD_SERVICE" in
        "google")
            timeout $((CONNECTIVITY_TIMEOUT * 2)) rclone about "$GOOGLE_REMOTE:" >/dev/null 2>&1
            ;;
        "yandex")
            timeout $((CONNECTIVITY_TIMEOUT * 2)) rclone about "$YANDEX_REMOTE:" >/dev/null 2>&1
            ;;
        *)
            return 0
            ;;
    esac
}

# Функция синхронизации времени
sync_time() {
    # Проверяем наличие RTC
    if [ -e /dev/rtc ] || [ -e /dev/rtc0 ]; then
        printf "${BLUE}🕐 Синхронизация времени с RTC...${RESET}\n"
        if hwclock --hctosys 2>/dev/null; then
            printf "${GREEN}✔ Время синхронизировано с RTC${RESET}\n"
            log_message "Время синхронизировано с RTC: $(date)"
        else
            printf "${YELLOW}⚠ Ошибка синхронизации с RTC${RESET}\n"
            log_message "Ошибка синхронизации с RTC"
        fi
    else
        printf "${YELLOW}⚠ RTC не найден, используем системное время${RESET}\n"
        log_message "RTC не найден, используется системное время: $(date)"
    fi
    
    # Попытка синхронизации через NTP при наличии интернета
    if check_internet_access; then
        printf "${BLUE}🌐 Синхронизация времени через NTP...${RESET}\n"
        if ntpdate -s time.nist.gov 2>/dev/null; then
            printf "${GREEN}✔ Время синхронизировано через NTP${RESET}\n"
            log_message "Время синхронизировано через NTP: $(date)"
            # Сохраняем время в RTC если доступен
            if [ -e /dev/rtc ] || [ -e /dev/rtc0 ]; then
                hwclock --systohc 2>/dev/null && log_message "Время сохранено в RTC"
            fi
        else
            printf "${YELLOW}⚠ Ошибка синхронизации через NTP${RESET}\n"
            log_message "Ошибка синхронизации через NTP"
        fi
    else
        printf "${YELLOW}⚠ Нет интернета для синхронизации времени${RESET}\n"
        log_message "Нет интернета для синхронизации времени"
    fi
}

# Функция настройки микрофона (автоопределение для Pi Zero 2 W)
setup_mic() {
    # Запускаем PulseAudio если не запущен
    if ! pulseaudio --check >/dev/null 2>&1; then
        printf "${BLUE}🔧 Запуск PulseAudio...${RESET}\n"
        pulseaudio --start >/dev/null 2>&1
        sleep 1
    fi
    
    # Если микрофон уже задан в настройках, используем его
    if [ -n "$MIC" ]; then
        printf "${GREEN}✔ Используется микрофон: ${YELLOW}%s${RESET}\n" "$MIC"
    else
        # Ищем BY-LM40 микрофон в PulseAudio
        PULSE_SOURCE=$(pactl list sources short | grep "BY-LM40" | awk '{print $2}' | head -1)
        if [ -n "$PULSE_SOURCE" ]; then
            MIC="$PULSE_SOURCE"
            printf "${GREEN}✔ BY-LM40 микрофон найден в PulseAudio: ${YELLOW}%s${RESET}\n" "$MIC"
        else
            MIC="default"
            printf "${YELLOW}⚠ BY-LM40 микрофон не найден, используется: ${YELLOW}%s${RESET}\n" "$MIC"
        fi
    fi
    
    # Проверяем доступность микрофона через PulseAudio
    if ! ffmpeg -f pulse -i "$MIC" -t 1 -f null - 2>/dev/null; then
        printf "${RED}✖ Ошибка доступа к микрофону %s${RESET}\n" "$MIC"
        printf "${YELLOW}⚠ Проверьте подключение микрофона${RESET}\n"
        printf "${BLUE}💡 Доступные устройства PulseAudio:${RESET}\n"
        pactl list sources short 2>/dev/null || echo "  Нет доступных устройств"
        exit 1
    fi
}

# Функция получения размера директории в МБ
get_dir_size_mb() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sm "$dir" 2>/dev/null | cut -f1
    else
        echo 0
    fi
}

# Функция очистки старых файлов при превышении лимита хранилища (оптимизированная для Pi Zero 2 W)
cleanup_old_files() {
    local pending_size
    pending_size=$(get_dir_size_mb "$PENDING_DIR")
    
    if [ "$pending_size" -gt "$MAX_STORAGE_MB" ]; then
        log_message "Превышен лимит хранилища: ${pending_size}MB > ${MAX_STORAGE_MB}MB"
        # Удаляем самые старые файлы до достижения лимита (Linux версия для Pi)
        find "$PENDING_DIR" -name "REC_*.${AUDIO_FORMAT}" -type f -exec stat -c '%Y %n' {} \; 2>/dev/null | \
            sort -n | \
            while read -r timestamp file; do
                rm -f "$file"
                log_message "Удален старый файл: $file"
                pending_size=$(get_dir_size_mb "$PENDING_DIR")
                [ "$pending_size" -le "$MAX_STORAGE_MB" ] && break
            done
    fi
}

# Функция логирования сообщений (упрощенная для Pi Zero 2 W)
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}


# Функция отображения прогресса записи (упрощенная для Pi Zero 2 W)
show_progress() {
    local duration=$1 start=$(date +%s)
    while true; do
        elapsed=$(($(date +%s)-start))
        [ $elapsed -ge $duration ] && break
        percent=$((elapsed*100/duration))
        # Упрощенный прогресс (меньше вычислений)
        printf "\r${BOLD}${BLUE}⌛ ${GREEN}%3d%%${RESET}" $percent
        sleep 5  # Обновляем каждые 5 секунд вместо 1
    done
    printf "\r\033[K" # Очищаем строку прогресса
}

# Универсальная функция загрузки файла в облако
upload_to_cloud() {
    local file="$1"
    local retries=0
    local cloud_target
    cloud_target=$(get_cloud_settings)

    # Пропускаем загрузку, если облако отключено
    if [ "$CLOUD_SERVICE" = "none" ]; then
        return 0
    fi

    # Проверяем доступ к интернету
    if ! check_internet_access; then
        log_message "Нет доступа к интернету: $file"
        return 1
    fi

    log_message "Начало выгрузки на $(get_cloud_name): $file"
    while [ "$retries" -lt "$MAX_RETRIES" ]; do
        if rclone copy "$file" "$cloud_target" --quiet; then
            log_message "Успешно выгружено на $(get_cloud_name): $file"
            if [ "$DELETE_AFTER_UPLOAD" = "true" ]; then
                rm -f "$file" && log_message "Файл удален: $file"
            fi
            return 0
        fi
        retries=$((retries + 1))
        log_message "Ошибка выгрузки ($retries/$MAX_RETRIES): $file"
        sleep "$RETRY_DELAY"
    done
    log_message "Выгрузка провалена: $file"
    return 1
}

# Функция обработки очереди файлов для загрузки
process_upload_queue() {
    # Если облачное хранилище отключено, не обрабатываем очередь
    if [ "$CLOUD_SERVICE" = "none" ]; then
        return 0
    fi
    
    # Проверяем доступ к интернету
    if ! check_internet_access; then
        return 1
    fi

    printf "${BOLD}${GREEN}☁ Обработка очереди $(get_cloud_name)...${RESET}\n"
    log_message "Начало обработки очереди $(get_cloud_name)"
    
    local uploaded=0
    local failed=0
    
    # Обрабатываем файлы по порядку
    find "$PENDING_DIR" -name "REC_*.${AUDIO_FORMAT}" -type f -exec stat -c '%Y %n' {} \; 2>/dev/null | \
        sort -n | while read -r timestamp file; do
        if [ -f "$file" ]; then
            if upload_to_cloud "$file"; then
                uploaded=$((uploaded + 1))
            else
                failed=$((failed + 1))
                break
            fi
        fi
    done
    
    log_message "Очередь обработана: успешно $uploaded, ошибки $failed"
    return 0
}

# Функция перемещения файла в очередь загрузки
queue_for_upload() {
    local file="$1"
    local pending_file="$PENDING_DIR/$(basename "$file")"
    
    if mv "$file" "$pending_file" 2>/dev/null; then
        log_message "Файл добавлен в очередь для $(get_cloud_name): $pending_file"
        return 0
    else
        log_message "Ошибка перемещения в очередь: $file"
        return 1
    fi
}

# Функция восстановления файлов после сбоя питания (упрощенная для Pi Zero 2 W)
recover_interrupted_files() {
    printf "${BLUE}🔄 Проверка файлов после сбоя...${RESET}\n"
    log_message "Начало восстановления файлов"
    
    local recovered=0
    local corrupted=0
    
    # Проверяем файлы в основной папке вывода
    for file in "$OUTPUT_DIR"/REC_*."$AUDIO_FORMAT"; do
        [ ! -f "$file" ] && continue
        
        local filename
        filename=$(basename "$file")
        
        # Проверяем размер файла (упрощенная проверка для Pi Zero 2 W)
        if [ -s "$file" ]; then
            local file_size
            file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            
            # Минимальный размер валидного аудиофайла (1КБ)
            if [ "$file_size" -gt 1024 ]; then
                # Перемещаем в очередь без проверки ffprobe (экономия ресурсов)
                if mv "$file" "$PENDING_DIR/$filename" 2>/dev/null; then
                    log_message "Восстановлен файл: $filename"
                    recovered=$((recovered + 1))
                fi
            else
                # Файл слишком маленький, удаляем
                log_message "Неполный файл удален: $filename (${file_size} байт)"
                rm -f "$file"
                corrupted=$((corrupted + 1))
            fi
        else
            # Пустой файл, удаляем
            log_message "Пустой файл удален: $filename"
            rm -f "$file"
            corrupted=$((corrupted + 1))
        fi
    done
    
    # Очищаем осиротевшие маркеры записи
    for marker in "$OUTPUT_DIR"/*.recording; do
        [ -f "$marker" ] && rm -f "$marker"
    done
    
    if [ $recovered -gt 0 ] || [ $corrupted -gt 0 ]; then
        printf "${GREEN}✅ Восстановлено: ${YELLOW}%d${GREEN}, удалено: ${YELLOW}%d${RESET}\n" "$recovered" "$corrupted"
        log_message "Восстановление завершено: восстановлено=$recovered, повреждено=$corrupted"
    else
        printf "${GREEN}✅ Файлов для восстановления не найдено${RESET}\n"
    fi
}

# Функция создания маркера восстановления
create_recovery_marker() {
    local file="$1"
    local marker_file="${file}.recording"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Запись начата" > "$marker_file"
}

# Функция удаления маркера восстановления
remove_recovery_marker() {
    local file="$1"
    local marker_file="${file}.recording"
    rm -f "$marker_file"
}

# █████████████████████████████████████████████████████████████████████████
# █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ЗАПУСК ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░█
# █████████████████████████████████████████████████████████████████████████

# Обработчик INT (Ctrl+C) для корректного завершения - POSIX совместимо
trap 'kill $(jobs -p) 2>/dev/null; printf "\n${RED}✖ Завершение работы...${RESET}\n"; exit' INT

# Создаём папки вывода, если они не существуют
mkdir -p "$OUTPUT_DIR"
mkdir -p "$PENDING_DIR"

# Синхронизируем время
sync_time

# Выбираем облачное хранилище
select_cloud_service

# Настраиваем микрофон по умолчанию
setup_mic

# Восстанавливаем любые файлы, оставшиеся после сбоя питания
recover_interrupted_files

# Отображаем информацию о запуске
if [ "$CLOUD_SERVICE" != "none" ]; then
    printf "${BOLD}${GREEN}▶ Запуск записи в формате ${YELLOW}${AUDIO_FORMAT}${RESET} с выгрузкой на $(get_cloud_name)...${RESET}\n"
else
    printf "${BOLD}${GREEN}▶ Запуск записи в формате ${YELLOW}${AUDIO_FORMAT}${RESET} (локальное хранилище)...${RESET}\n"
fi

LAST_CONNECTIVITY_CHECK=0

# Основной цикл записи
while true; do
    # Периодически проверяем интернет и обрабатываем очередь
    current_time=$(date +%s)
    if [ $((current_time - LAST_CONNECTIVITY_CHECK)) -ge "$CONNECTIVITY_CHECK_INTERVAL" ]; then
        LAST_CONNECTIVITY_CHECK="$current_time"
        
        # Обрабатываем очередь при наличии интернета
        if check_internet_access && [ "$CLOUD_SERVICE" != "none" ]; then
            process_upload_queue &
        elif [ "$CLOUD_SERVICE" != "none" ]; then
            # Показываем статистику очереди
            local pending_count
            pending_count=$(find "$PENDING_DIR" -name "REC_*.${AUDIO_FORMAT}" -type f | wc -l)
            printf "${YELLOW}📁 Файлов в очереди: ${pending_count}${RESET}\n"
        fi
    fi


    # Очищаем старые файлы при превышении лимита хранилища
    cleanup_old_files

    # Генерируем временную метку и имя файла с правильным расширением
    TS=$(date +"%Y%m%d_%H%M%S")
    FILE="${OUTPUT_DIR}/REC_${TS}.${AUDIO_FORMAT}"

    log_message "Начало записи: $FILE"

    # Создаём маркер восстановления перед началом записи
    create_recovery_marker "$FILE"

    # Начинаем запись и кодирование через ffmpeg с PulseAudio
    # ffmpeg захватывает звук через PulseAudio
    case "$AUDIO_FORMAT" in
        aac)
            ffmpeg -y -f pulse -i "$MIC" -t "$SPLIT_TIME" -c:a aac -b:a "${BITRATE}k" -ar "$SAMPLE_RATE" "$FILE" -hide_banner -loglevel error 2>> "$LOG_FILE" &
            ;;
        opus)
            ffmpeg -y -f pulse -i "$MIC" -t "$SPLIT_TIME" -c:a libopus -b:a "${BITRATE}k" -application voip -ar "$SAMPLE_RATE" "$FILE" -hide_banner -loglevel error 2>> "$LOG_FILE" &
            ;;
        mp3)
            ffmpeg -y -f pulse -i "$MIC" -t "$SPLIT_TIME" -c:a libmp3lame -b:a "${BITRATE}k" -q:a 5 -ar "$SAMPLE_RATE" "$FILE" -hide_banner -loglevel error 2>> "$LOG_FILE" &
            ;;
        *)
            printf "${RED}✖ Неверный формат аудио: %s. Используйте aac, opus или mp3.${RESET}\n" "$AUDIO_FORMAT"
            log_message "Ошибка: Неверный формат аудио: $AUDIO_FORMAT"
            remove_recovery_marker "$FILE"
            exit 1
            ;;
    esac

    # Отображаем прогресс для текущего сегмента
    show_progress "$SPLIT_TIME"
    wait # Ожидаем завершения процесса ffmpeg

    # Удаляем маркер восстановления после успешной записи
    remove_recovery_marker "$FILE"

    log_message "Запись завершена: $FILE"

    # Обрабатываем записанный файл
    if [ "$CLOUD_SERVICE" != "none" ] && [ -f "$FILE" ]; then
        # Попытка немедленной загрузки
        if check_internet_access && upload_to_cloud "$FILE"; then
            log_message "Файл успешно загружен: $FILE"
        else
            # Добавляем файл в очередь
            queue_for_upload "$FILE"
        fi
    elif [ ! -f "$FILE" ]; then
        log_message "Файл не найден после записи: $FILE"
    fi
done
