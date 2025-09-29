# AREC - Car Audio Recorder

Automated audio recording script for Raspberry Pi Zero 2 W in car environment.

## Features
- Automatic audio recording with BY-LM40 USB microphone
- Cloud upload to Google Drive/Yandex Disk
- RTC time synchronization
- Car-specific optimizations
- Recovery after power failures

## Quick Start
1. Install dependencies: `sudo apt install pulseaudio ffmpeg rclone i2c-tools ntpdate`
2. Configure RTC module DS3231
3. Setup Wi-Fi connections
4. Configure rclone for cloud storage
5. Run: `sudo ./arec.sh`

## Documentation
See [arec.md](arec.md) for detailed documentation.

## License
Free for personal use.
