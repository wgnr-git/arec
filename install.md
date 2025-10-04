## 🚀 Пошаговая установка

### 1. Установите необходимые пакеты

```bash
sudo apt update
sudo apt install -y alsa-utils ffmpeg rclone ntpdate

### 2. Настройте микрофон

Проверьте доступные устройства:

arecord -l
Если используется нестандартный микрофон, укажите его в настройках скрипта (параметр MIC).

### 3. Настройте rclone (если используется облако)

Настройте удалённое хранилище:
rclone config

Создайте:
google.drive — для Google Drive
yandex.disk — для Яндекс.Диска
 📌 Имена должны совпадать с настройками в скрипте (GOOGLE_REMOTE, YANDEX_REMOTE).

### 6. Создайте systemd-сервис

Скопируйте файл сервиса (arec.service) в эту папку /etc/systemd/system/

Перезагрузите конфигурацию systemd
sudo systemctl daemon-reload

Включите автозапуск
sudo systemctl enable arec.service

Запустите вручную
sudo systemctl start arec.service

