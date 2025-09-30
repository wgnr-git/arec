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
OVERLAP_TIME=5               # Время перекрытия между файлами в секундах
OUTPUT_DIR="/root/arec"       # Папка для сохранения записанных файлов
LOG_FILE="/root/arec/arec.log" # Файл для записи логов работы скрипта
SAMPLE_RATE=48000             # Частота дискретизации аудио (Гц)
SAMPLE_FORMAT="S24_3LE"       # Формат семплирования
MIC="default"                 # Источник звука (default = микрофон по умолчанию)

# ═══════════════════════════════════════════════════════════════════════════
# НАСТРОЙКИ КОДИРОВАНИЯ АУДИО
# ═══════════════════════════════════════════════════════════════════════════

AUDIO_FORMAT="opus"           # Формат аудио: aac, opus, mp3
BITRATE=64                    # Битрейт аудио в кбит/с

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
# НАСТРОЙКИ АДАПТИВНОЙ СЕТИ
# ═══════════════════════════════════════════════════════════════════════════

MAX_PARALLEL_UPLOADS=3        # Максимальное количество параллельных загрузок
NETWORK_SPEED_THRESHOLD=100   # Порог медленной сети (мс ping)
SLOW_NETWORK_RETRY_DELAY=600  # Задержка для медленной сети (секунды)
SLOW_NETWORK_MAX_RETRIES=5    # Максимальные попытки для медленной сети
QUEUE_WARNING_THRESHOLD=80    # Порог предупреждения о размере очереди (%)

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

# Функция проверки скорости сети
check_network_speed() {
    local ping_time
    ping_time=$(ping -c 3 8.8.8.8 2>/dev/null | grep "avg" | cut -d'/' -f5 | cut -d'.' -f1)
    
    if [ -z "$ping_time" ]; then
        echo "unknown"
        return 1
    fi
    
    if [ "$ping_time" -gt "$NETWORK_SPEED_THRESHOLD" ]; then
        echo "slow"
        return 1
    else
        echo "fast"
        return 0
    fi
}

# Функция проверки интернет-доступа (улучшенная для нестабильной сети)
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

# Функция проверки состояния микрофона
check_microphone_health() {
    local exit_code
    
    # Проверяем доступность микрофона через arecord
    if ! arecord -D "$MIC" -f "$SAMPLE_FORMAT" -r "$SAMPLE_RATE" -d 1 --quiet - >/dev/null 2>&1; then
        exit_code=$?
        log_error "arecord не может получить доступ к микрофону $MIC (код: $exit_code)" "$exit_code" "mic_check"
        return 1
    fi
    
    return 0
}

# Функция восстановления микрофона
restore_microphone() {
    local attempts=0
    local max_attempts=3
    local exit_code
    
    log_message "Попытка восстановления микрофона..."
    
    while [ $attempts -lt $max_attempts ]; do
        attempts=$((attempts + 1))
        log_message "Попытка восстановления $attempts/$max_attempts"
        
        # Перезагружаем ALSA
        if ! alsactl restore >/dev/null 2>&1; then
            log_error "Ошибка восстановления ALSA" "alsa_restore_failed" "mic_restore"
        fi
        sleep 2
        
        # Проверяем восстановление
        if check_microphone_health; then
            log_message "Микрофон успешно восстановлен"
            return 0
        fi
        
        log_error "Попытка восстановления $attempts неудачна" "restore_attempt_failed" "mic_restore"
        sleep 5
    done
    
    log_error "Не удалось восстановить микрофон после $max_attempts попыток" "mic_restore_failed" "mic_restore"
    return 1
}

# Функция настройки микрофона (простая настройка для arecord)
setup_mic() {
    printf "${BOLD}${BLUE}■ Использование микрофона по умолчанию...${RESET}\n"
    MIC="default"
    printf "${GREEN}✔ Микрофон настроен: ${YELLOW}%s${RESET}\n" "$MIC"
    
    # Проверяем доступность микрофона через arecord
    if ! arecord -D "$MIC" -f "$SAMPLE_FORMAT" -r "$SAMPLE_RATE" -d 1 --quiet - >/dev/null 2>&1; then
        local exit_code=$?
        printf "${RED}✖ Ошибка доступа к микрофону %s (код: %d)${RESET}\n" "$MIC" "$exit_code"
        printf "${YELLOW}⚠ Проверьте подключение микрофона${RESET}\n"
        printf "${BLUE}💡 Доступные устройства ALSA:${RESET}\n"
        arecord -l 2>/dev/null || echo "  Нет доступных устройств"
        handle_critical_error "Не удалось получить доступ к микрофону $MIC (код: $exit_code)" "$exit_code" "mic_setup"
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

# Функция мониторинга размера очереди
check_queue_size() {
    local pending_size
    pending_size=$(get_dir_size_mb "$PENDING_DIR")
    local usage_percent=$((pending_size * 100 / MAX_STORAGE_MB))
    
    if [ "$usage_percent" -gt "$QUEUE_WARNING_THRESHOLD" ]; then
        log_error "Критически мало места: ${usage_percent}% (${pending_size}MB/${MAX_STORAGE_MB}MB)" "storage_critical" "queue"
        return 1
    elif [ "$usage_percent" -gt 60 ]; then
        log_message "Предупреждение: используется ${usage_percent}% хранилища (${pending_size}MB/${MAX_STORAGE_MB}MB)"
    fi
    
    return 0
}

# Функция очистки старых файлов при превышении лимита хранилища (оптимизированная для Pi Zero 2 W)
cleanup_old_files() {
    local pending_size
    pending_size=$(get_dir_size_mb "$PENDING_DIR")
    
    if [ "$pending_size" -gt "$MAX_STORAGE_MB" ]; then
        log_message "Превышен лимит хранилища: ${pending_size}MB > ${MAX_STORAGE_MB}MB"
        # Удаляем самые старые файлы до достижения лимита (оптимизированная версия)
        find "$PENDING_DIR" -name "REC_*.${AUDIO_FORMAT}" -type f -printf '%T@ %p\n' 2>/dev/null | \
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

# Функция логирования ошибок с детальной информацией
log_error() {
    local error_msg="$1"
    local error_code="${2:-unknown}"
    local context="${3:-main}"
    
    log_message "ОШИБКА [$context] (код: $error_code): $error_msg"
    printf "${RED}✖ ОШИБКА [$context]: $error_msg${RESET}\n" >&2
}

# Функция обработки критических ошибок
handle_critical_error() {
    local error_msg="$1"
    local error_code="${2:-1}"
    local context="${3:-main}"
    
    log_error "$error_msg" "$error_code" "$context"
    
    # Очищаем временные файлы
    cleanup_temp_files
    
    # Останавливаем все фоновые процессы
    kill_background_jobs
    
    # Показываем финальное сообщение
    printf "${RED}💥 КРИТИЧЕСКАЯ ОШИБКА: $error_msg${RESET}\n"
    printf "${YELLOW}📋 Проверьте логи: $LOG_FILE${RESET}\n"
    
    exit "$error_code"
}

# Функция очистки временных файлов
cleanup_temp_files() {
    # Удаляем маркеры записи
    find "$OUTPUT_DIR" -name "*.recording" -type f -delete 2>/dev/null
    
    log_message "Временные файлы очищены"
}

# Функция остановки фоновых процессов
kill_background_jobs() {
    local jobs_pids
    jobs_pids=$(jobs -p 2>/dev/null)
    
    if [ -n "$jobs_pids" ]; then
        log_message "Остановка фоновых процессов: $jobs_pids"
        echo "$jobs_pids" | xargs kill -TERM 2>/dev/null
        sleep 2
        echo "$jobs_pids" | xargs kill -KILL 2>/dev/null
    fi
}

# Функция обработки файла после записи
process_recorded_file() {
    local file="$1"
    local file_name="$2"
    
    if [ -f "$file" ]; then
        local file_size
        file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        
        if [ "$file_size" -lt 1024 ]; then
            log_error "$file_name слишком маленький (${file_size} байт): $file" "${file_name,,}_too_small" "overlap_recording"
            rm -f "$file"
        else
            # Обрабатываем файл
            if [ "$CLOUD_SERVICE" != "none" ]; then
                if check_internet_access && upload_to_cloud "$file"; then
                    log_message "$file_name успешно загружен: $file"
                else
                    if ! queue_for_upload "$file"; then
                        log_error "Не удалось добавить $file_name в очередь: $file" "${file_name,,}_queue_failed" "overlap_recording"
                    fi
                fi
            fi
        fi
    fi
}

# Функция проверки и восстановления микрофона
check_and_restore_microphone() {
    local context="$1"
    
    if ! check_microphone_health; then
        log_message "Проблема с микрофоном ($context), попытка восстановления..."
        if restore_microphone; then
            log_message "Микрофон успешно восстановлен"
            return 0
        else
            log_message "КРИТИЧЕСКАЯ ОШИБКА: Не удалось восстановить микрофон ($context)"
            if command -v systemctl >/dev/null 2>&1; then
                systemctl restart arec.service
            fi
            handle_critical_error "Не удалось восстановить микрофон ($context)" 1 "mic_restore"
        fi
    fi
    return 0
}


# Функция запуска записи с перекрытием через arecord
start_overlapping_recording() {
    local file="$1"
    local duration="$2"
    local arecord_pid_var="$3"
    
    log_message "Запуск перекрывающей записи: $file (длительность: ${duration}с)"
    
    # Запускаем arecord + ffmpeg в фоне
    case "$AUDIO_FORMAT" in
        aac)
            arecord -D "$MIC" -f "$SAMPLE_FORMAT" -r "$SAMPLE_RATE" -d "$duration" --quiet - 2>> "$LOG_FILE" | \
            ffmpeg -y -i - -c:a aac -b:a "${BITRATE}k" -ac 1 "$file" -hide_banner -loglevel error 2>> "$LOG_FILE" &
            ;;
        opus)
            arecord -D "$MIC" -f "$SAMPLE_FORMAT" -r "$SAMPLE_RATE" -d "$duration" --quiet - 2>> "$LOG_FILE" | \
            ffmpeg -y -i - -c:a libopus -b:a "${BITRATE}k" -application voip -ac 1 "$file" -hide_banner -loglevel error 2>> "$LOG_FILE" &
            ;;
        mp3)
            arecord -D "$MIC" -f "$SAMPLE_FORMAT" -r "$SAMPLE_RATE" -d "$duration" --quiet - 2>> "$LOG_FILE" | \
            ffmpeg -y -i - -c:a libmp3lame -b:a "${BITRATE}k" -q:a 5 -ac 1 "$file" -hide_banner -loglevel error 2>> "$LOG_FILE" &
            ;;
        *)
            log_error "Неверный формат аудио: $AUDIO_FORMAT" "invalid_audio_format" "overlap_recording"
            return 1
            ;;
    esac
    
    # Сохраняем PID процесса
    eval "$arecord_pid_var=$!"
    local pid
    eval "pid=\$$arecord_pid_var"
    
    # Проверяем, что процесс запустился
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "arecord не удалось запустить для перекрывающей записи: $file" "arecord_start_failed" "overlap_recording"
        return 1
    fi
    
    log_message "Перекрывающая запись запущена (PID: $pid): $file"
    return 0
}

# Функция ожидания завершения arecord с таймаутом
wait_for_arecord() {
    local pid="$1"
    local timeout="$2"
    local file="$3"
    local start_time
    start_time=$(date +%s)
    
    while kill -0 "$pid" 2>/dev/null; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            log_error "Таймаут ожидания завершения arecord (${timeout}с): $file" "arecord_timeout" "overlap_recording"
            kill -TERM "$pid" 2>/dev/null
            sleep 2
            kill -KILL "$pid" 2>/dev/null
            return 1
        fi
        
        sleep 1
    done
    
    # Получаем код завершения
    wait "$pid"
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log_error "arecord завершился с ошибкой (код: $exit_code): $file" "$exit_code" "overlap_recording"
        return 1
    fi
    
    return 0
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

# Универсальная функция загрузки файла в облако (адаптивная для нестабильной сети)
upload_to_cloud() {
    local file="$1"
    local retries=0
    local cloud_target
    local exit_code
    local network_speed
    local max_retries
    local retry_delay
    
    cloud_target=$(get_cloud_settings)

    # Пропускаем загрузку, если облако отключено
    if [ "$CLOUD_SERVICE" = "none" ]; then
        return 0
    fi

    # Проверяем существование файла
    if [ ! -f "$file" ]; then
        log_error "Файл для загрузки не найден: $file" "file_not_found" "upload"
        return 1
    fi

    # Проверяем доступ к интернету
    if ! check_internet_access; then
        log_error "Нет доступа к интернету для загрузки: $file" "no_internet" "upload"
        return 1
    fi

    # Определяем параметры загрузки в зависимости от скорости сети
    network_speed=$(check_network_speed)
    if [ "$network_speed" = "slow" ]; then
        max_retries=$SLOW_NETWORK_MAX_RETRIES
        retry_delay=$SLOW_NETWORK_RETRY_DELAY
        log_message "Медленная сеть обнаружена, используем адаптивные параметры для: $file"
    else
        max_retries=$MAX_RETRIES
        retry_delay=$RETRY_DELAY
    fi

    log_message "Начало выгрузки на $(get_cloud_name): $file (сеть: $network_speed)"
    while [ "$retries" -lt "$max_retries" ]; do
        if rclone copy "$file" "$cloud_target" --quiet 2>/dev/null; then
            log_message "Успешно выгружено на $(get_cloud_name): $file"
            if [ "$DELETE_AFTER_UPLOAD" = "true" ]; then
                if ! rm -f "$file" 2>/dev/null; then
                    log_error "Не удалось удалить файл после загрузки: $file" "delete_failed" "upload"
                else
                    log_message "Файл удален: $file"
                fi
            fi
            return 0
        fi
        exit_code=$?
        retries=$((retries + 1))
        log_error "Ошибка выгрузки ($retries/$max_retries) (код: $exit_code): $file" "$exit_code" "upload"
        sleep "$retry_delay"
    done
    log_error "Выгрузка провалена после $max_retries попыток: $file" "upload_failed" "upload"
    return 1
}

# Функция параллельной загрузки файлов
upload_parallel() {
    local max_parallel="$1"
    local uploaded=0
    local failed=0
    
    # Получаем список файлов, отсортированных по времени (новые первыми) - POSIX совместимо
    local files
    files=$(find "$PENDING_DIR" -name "REC_*.${AUDIO_FORMAT}" -type f -exec stat -c '%Y %n' {} \; 2>/dev/null | \
        sort -nr | head -10 | cut -d' ' -f2-)
    
    for file in $files; do
        if [ -f "$file" ]; then
            # Проверяем количество активных процессов
            if [ $(jobs -r | wc -l) -lt "$max_parallel" ]; then
                # Запускаем загрузку в фоне
                upload_to_cloud "$file" &
                uploaded=$((uploaded + 1))
            else
                # Ждем завершения одного процесса
                wait -n
                # Запускаем новую загрузку
                upload_to_cloud "$file" &
                uploaded=$((uploaded + 1))
            fi
        fi
    done
    
    # Ждем завершения всех фоновых процессов
    wait
    
    log_message "Параллельная загрузка завершена: обработано $uploaded файлов"
    return 0
}

# Функция обработки очереди файлов для загрузки (улучшенная для нестабильной сети)
process_upload_queue() {
    # Если облачное хранилище отключено, не обрабатываем очередь
    if [ "$CLOUD_SERVICE" = "none" ]; then
        return 0
    fi
    
    # Проверяем доступ к интернету
    if ! check_internet_access; then
        return 1
    fi

    # Проверяем размер очереди
    if ! check_queue_size; then
        log_error "Критический размер очереди, приоритетная очистка" "queue_critical" "upload"
        cleanup_old_files
    fi

    printf "${BOLD}${GREEN}☁ Обработка очереди $(get_cloud_name)...${RESET}\n"
    log_message "Начало обработки очереди $(get_cloud_name)"
    
    # Определяем количество параллельных загрузок в зависимости от скорости сети
    local network_speed
    network_speed=$(check_network_speed)
    local max_parallel
    
    if [ "$network_speed" = "slow" ]; then
        max_parallel=1  # Одна загрузка для медленной сети
        log_message "Медленная сеть, используем последовательную загрузку"
    else
        max_parallel=$MAX_PARALLEL_UPLOADS  # Параллельная загрузка для быстрой сети
        log_message "Быстрая сеть, используем параллельную загрузку ($max_parallel потоков)"
    fi
    
    # Запускаем загрузку
    upload_parallel "$max_parallel"
    
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

# Функция graceful shutdown
graceful_shutdown() {
    local signal="$1"
    local exit_code=0
    
    printf "\n${YELLOW}🛑 Получен сигнал $signal, завершение работы...${RESET}\n"
    log_message "Получен сигнал $signal, начало graceful shutdown"
    
    # Останавливаем все фоновые процессы
    kill_background_jobs
    
    # Очищаем временные файлы
    cleanup_temp_files
    
    # Показываем статистику
    pending_count=$(find "$PENDING_DIR" -name "REC_*.${AUDIO_FORMAT}" -type f 2>/dev/null | wc -l)
    if [ "$pending_count" -gt 0 ]; then
        printf "${YELLOW}📁 Файлов в очереди на загрузку: $pending_count${RESET}\n"
        log_message "Завершение работы с $pending_count файлами в очереди"
    fi
    
    printf "${GREEN}✅ Корректное завершение работы${RESET}\n"
    log_message "Graceful shutdown завершен"
    
    exit $exit_code
}

# Обработчики сигналов для корректного завершения
trap 'graceful_shutdown INT' INT
trap 'graceful_shutdown TERM' TERM
trap 'graceful_shutdown EXIT' EXIT

# Создаём папки вывода, если они не существуют
if ! mkdir -p "$OUTPUT_DIR" 2>/dev/null; then
    handle_critical_error "Не удалось создать папку вывода: $OUTPUT_DIR" 1 "init"
fi

if ! mkdir -p "$PENDING_DIR" 2>/dev/null; then
    handle_critical_error "Не удалось создать папку очереди: $PENDING_DIR" 1 "init"
fi

# Проверяем права записи в папки
if [ ! -w "$OUTPUT_DIR" ]; then
    handle_critical_error "Нет прав записи в папку: $OUTPUT_DIR" 1 "init"
fi

if [ ! -w "$PENDING_DIR" ]; then
    handle_critical_error "Нет прав записи в папку: $PENDING_DIR" 1 "init"
fi

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
LAST_MIC_CHECK=0
MIC_CHECK_INTERVAL=300  # Проверка микрофона каждые 5 минут

# Основной цикл записи с перекрытием
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
            pending_count=$(find "$PENDING_DIR" -name "REC_*.${AUDIO_FORMAT}" -type f | wc -l)
            printf "${YELLOW}📁 Файлов в очереди: ${pending_count}${RESET}\n"
        fi
    fi

    # Периодически проверяем состояние микрофона
    if [ $((current_time - LAST_MIC_CHECK)) -ge "$MIC_CHECK_INTERVAL" ]; then
        LAST_MIC_CHECK="$current_time"
        check_and_restore_microphone "периодическая проверка"
    fi

    # Проверяем размер очереди и очищаем старые файлы при необходимости
    check_queue_size
    cleanup_old_files

    # Проверяем состояние микрофона перед началом записи
    check_and_restore_microphone "перед записью"

    # Генерируем временную метку и имя файла с правильным расширением
    TS=$(date +"%Y%m%d_%H%M%S")
    FILE="${OUTPUT_DIR}/REC_${TS}.${AUDIO_FORMAT}"

    log_message "Начало записи с перекрытием: $FILE"

    # Создаём маркер восстановления перед началом записи
    create_recovery_marker "$FILE"

    # Запускаем первый файл
    arecord_pid1=""
    if ! start_overlapping_recording "$FILE" "$SPLIT_TIME" "arecord_pid1"; then
        remove_recovery_marker "$FILE"
        handle_critical_error "Не удалось запустить первую запись" 1 "overlap_recording"
    fi

    # Ждем до момента перекрытия
    overlap_start_time=$((SPLIT_TIME - OVERLAP_TIME))
    printf "${BLUE}⏳ Ожидание перекрытия (${overlap_start_time}с)...${RESET}\n"
    sleep "$overlap_start_time"

    # Генерируем имя для второго файла
    TS2=$(date +"%Y%m%d_%H%M%S")
    FILE2="${OUTPUT_DIR}/REC_${TS2}.${AUDIO_FORMAT}"

    log_message "Запуск перекрывающей записи: $FILE2"

    # Создаём маркер восстановления для второго файла
    create_recovery_marker "$FILE2"

    # Запускаем второй файл с перекрытием
    arecord_pid2=""
    if ! start_overlapping_recording "$FILE2" "$SPLIT_TIME" "arecord_pid2"; then
        remove_recovery_marker "$FILE2"
        log_error "Не удалось запустить перекрывающую запись: $FILE2" "overlap_start_failed" "overlap_recording"
        # Продолжаем с первым файлом
    else
        printf "${GREEN}✅ Перекрывающая запись запущена: $FILE2${RESET}\n"
    fi

    # Ждем завершения первого файла
    printf "${BLUE}⏳ Завершение первого файла (${OVERLAP_TIME}с)...${RESET}\n"
    if ! wait_for_arecord "$arecord_pid1" $((OVERLAP_TIME + 10)) "$FILE"; then
        log_error "Ошибка завершения первого файла: $FILE" "first_file_error" "overlap_recording"
        remove_recovery_marker "$FILE"
    else
        # Удаляем маркер восстановления после успешной записи
        remove_recovery_marker "$FILE"
        log_message "Первый файл завершен: $FILE"
    fi

    # Проверяем первый файл
    process_recorded_file "$FILE" "Первый файл"

    # Ждем завершения второго файла
    printf "${BLUE}⏳ Завершение второго файла...${RESET}\n"
    if ! wait_for_arecord "$arecord_pid2" $((OVERLAP_TIME + 10)) "$FILE2"; then
        log_error "Ошибка завершения второго файла: $FILE2" "second_file_error" "overlap_recording"
        remove_recovery_marker "$FILE2"
    else
        # Удаляем маркер восстановления после успешной записи
        remove_recovery_marker "$FILE2"
        log_message "Второй файл завершен: $FILE2"
    fi

    # Проверяем второй файл
    process_recorded_file "$FILE2" "Второй файл"

    # Проверяем состояние микрофона после записи
    check_and_restore_microphone "после записи"

    printf "${GREEN}✅ Цикл перекрывающей записи завершен${RESET}\n"
done
