# AREC - Автоматическая запись аудио с загрузкой в облако

## Описание

AREC (Audio Recording) - это специализированный скрипт для автоматической записи аудио в автомобиле с USB-микрофона BY-LM40 на Raspberry Pi Zero 2 W. Скрипт предназначен для работы в экстремальных условиях автомобиля: нестабильное питание, перепады температуры, вибрация, периодическое отсутствие интернета.

## Быстрая установка

### 1. Скачайте файлы
```bash
# Скачайте все файлы в одну папку
wget https://github.com/your-repo/arec/archive/main.zip
unzip main.zip
cd arec-main
```

### 2. Запустите установщик
```bash
# Сделайте установщик исполняемым
chmod +x install.sh

# Запустите установку
sudo ./install.sh
```

### 3. Настройте rclone (опционально)
```bash
# Настройте подключение к облаку
rclone config
```

## Ручная установка

Если автоматическая установка не работает, выполните шаги вручную:

### 1. Установка зависимостей
```bash
sudo apt update
sudo apt install -y ffmpeg rclone i2c-tools ntpdate alsa-utils
```

### 2. Создание директорий
```bash
sudo mkdir -p /root/arec/pending
```

### 3. Копирование скрипта
```bash
sudo cp arec.sh /root/arec/
sudo chmod +x /root/arec/arec.sh
```

### 4. Создание systemd сервиса
```bash
sudo cp arec.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable arec.service
```

## Управление

### Основные команды
```bash
# Статус сервиса
sudo systemctl status arec.service

# Запуск записи
sudo systemctl start arec.service

# Остановка записи
sudo systemctl stop arec.service

# Перезапуск
sudo systemctl restart arec.service
```

### Расписание (systemd timers)
```bash
# Статус таймеров
sudo systemctl list-timers | grep arec

# Логи таймеров
sudo journalctl -u arec-start.timer -f
sudo journalctl -u arec-stop.timer -f
```

### Просмотр логов
```bash
# Логи сервиса
sudo journalctl -u arec.service -f

# Логи скрипта
tail -f /root/arec/arec.log
```

## Настройка

### Основные параметры
Отредактируйте файл `/root/arec/arec.sh`:

```bash
sudo nano /root/arec/arec.sh
```

#### Ключевые настройки:
- `SPLIT_TIME=1800` - длительность файла (30 минут)
- `AUDIO_FORMAT="opus"` - формат аудио
- `CLOUD_SERVICE="yandex"` - облачный сервис
- `CONNECTIVITY_CHECK_INTERVAL=180` - интервал проверки интернета

### Настройка облака
```bash
# Настройка rclone
rclone config

# Тест подключения
rclone about yandex.disk:
```

### Изменение расписания
```bash
# Редактировать время запуска
sudo nano /etc/systemd/system/arec-start.timer

# Редактировать время остановки
sudo nano /etc/systemd/system/arec-stop.timer

# Применить изменения
sudo systemctl daemon-reload
```

## Мониторинг

### Проверка работы
```bash
# Активные процессы
ps aux | grep -E "(arecord|ffmpeg)"

# Созданные файлы
ls -lt /root/arec/REC_*.opus

# Размер очереди
du -sh /root/arec/pending/
```

### Системные ресурсы
```bash
# Использование CPU
top -p $(pgrep arecord)

# Использование памяти
free -h

# Температура
vcgencmd measure_temp
```

## Устранение неполадок

### Проблемы с микрофоном
```bash
# Проверка ALSA устройств
arecord -l

# Тест записи
arecord -D default -f S24_3LE -r 48000 -d 5 test.wav

# Восстановление ALSA
alsactl restore
```

### Проблемы с сетью
```bash
# Проверка интернета
ping -c 3 8.8.8.8

# Проверка rclone
rclone about yandex.disk:
```

### Проблемы с сервисом
```bash
# Проверка статуса
sudo systemctl status arec.service

# Просмотр логов
sudo journalctl -u arec.service -n 50

# Перезапуск
sudo systemctl restart arec.service
```

## Файлы проекта

- `arec.sh` - основной скрипт записи
- `install.sh` - автоматический установщик
- `arec.service` - systemd сервис
- `arec-start.service` - сервис запуска
- `arec-stop.service` - сервис остановки
- `arec-start.timer` - таймер запуска
- `arec-stop.timer` - таймер остановки
- `manage-arec.sh` - скрипт управления
- `install-systemd.sh` - установка systemd сервисов

## Системные требования

### Аппаратное обеспечение
- Raspberry Pi Zero 2 W (рекомендуется)
- USB-микрофон BY-LM40
- SD-карта минимум 32 ГБ
- RTC модуль DS3231 (опционально)

### Программное обеспечение
- Raspberry Pi OS (Debian-based)
- FFmpeg
- rclone
- ALSA
- systemd

## Лицензия

Скрипт распространяется свободно для личного использования.

## Поддержка

При возникновении проблем:
1. Проверьте логи: `sudo journalctl -u arec.service -f`
2. Убедитесь в корректности настроек rclone
3. Проверьте подключение микрофона
4. Убедитесь в стабильности интернет-соединения
