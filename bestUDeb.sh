#!/bin/bash

# Проверка прав администратора
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт с правами администратора (sudo)"
  exit 1
fi

echo "=== Скрипт очистки Ubuntu ==="
echo "Перед началом работы будут заданы вопросы о действиях"
echo ""

# Функция для подтверждения действий
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Инициализация переменных
REMOVE_SNAP=false
REMOVE_LIBREOFFICE=false
DISABLE_TELEMETRY=true
REMOVE_UBUNTU_PRO=false
INSTALL_FLATPAK=false

# Вопросы пользователю
echo "=== Вопросы по очистке ==="

if confirm "Удалить Snap и все snap-пакеты?"; then
    REMOVE_SNAP=true
fi

if confirm "Удалить LibreOffice?"; then
    REMOVE_LIBREOFFICE=true
fi

if confirm "Отключить телеметрию и сбор статистики?"; then
    DISABLE_TELEMETRY=true
fi

if confirm "Удалить Ubuntu Pro (если установлен)?"; then
    REMOVE_UBUNTU_PRO=true
fi

echo ""
echo "=== Вопросы по установке ==="

if confirm "Установить Flatpak?"; then
    INSTALL_FLATPAK=true
fi

echo ""
echo "=== Начинаем выполнение операций ==="

# 1. Удаление Snap (если выбрано)
if [ "$REMOVE_SNAP" = true ]; then
    echo "Удаление Snap пакетов..."
    snap list | awk '/./ {print $1}' | tail -n +2 | xargs -r sudo snap remove 2>/dev/null || echo "Snap пакеты не найдены или уже удалены"
    
    echo "Отключение и удаление Snap демона..."
    systemctl disable --now snapd snapd.socket 2>/dev/null
    apt purge -y snapd
    rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd 2>/dev/null
    echo "Snap успешно удален"
else
    echo "Snap оставлен без изменений"
fi

# 2. Удаление LibreOffice (если выбрано)
if [ "$REMOVE_LIBREOFFICE" = true ]; then
    echo "Удаление LibreOffice..."
    apt purge -y libreoffice*
    echo "LibreOffice успешно удален"
else
    echo "LibreOffice оставлен без изменений"
fi

# 3. Отключение телеметрии (если выбрано)
if [ "$DISABLE_TELEMETRY" = true ]; then
    echo "Отключение телеметрии..."
    
    # Отключение apport (автоматические отчеты об ошибках)
    systemctl disable --now apport 2>/dev/null
    apt purge -y apport
    
    # Отключение whoopsie (отправка отчетов об ошибках Canonical)
    systemctl disable --now whoopsie 2>/dev/null
    apt purge -y whoopsie
    
    # Отключение популяриметрии (сбор статистики использования пакетов)
    apt purge -y popularity-contest
    
    # Отключение телеметрии в GNOME (если используется)
    gsettings set org.gnome.desktop.privacy send-software-usage-stats false 2>/dev/null
    gsettings set org.gnome.desktop.privacy send-statistics false 2>/dev/null
    
    # Блокировка доменов телеметрии в /etc/hosts
    echo "Блокировка доменов телеметрии..."
    # Проверяем, не добавлены ли уже записи
    if ! grep -q "metrics.ubuntu.com" /etc/hosts; then
        cat >> /etc/hosts << EOF
# Блокировка телеметрии Ubuntu
0.0.0.0 metrics.ubuntu.com
0.0.0.0 stats.ubuntu.com
0.0.0.0 telemetry.ubuntu.com
0.0.0.0 errors.ubuntu.com
EOF
    fi
    
    # Удаление других пакетов телеметрии
    apt purge -y ubuntu-report
    
    echo "Телеметрия отключена"
else
    echo "Телеметрия оставлена без изменений"
fi

# 4. Удаление Ubuntu Pro (если выбрано)
if [ "$REMOVE_UBUNTU_PRO" = true ]; then
    echo "Удаление Ubuntu Pro..."
    # Проверяем, установлен ли ubuntu-advantage-tools
    if dpkg -l | grep -q ubuntu-advantage-tools; then
        # Отключение Ubuntu Pro (если активирован)
        pro detach --assume-yes 2>/dev/null || echo "Ubuntu Pro не был активирован"
        # Удаление пакета
        apt purge -y ubuntu-advantage-tools
        echo "Ubuntu Pro успешно удален"
    else
        echo "Ubuntu Pro не найден в системе"
    fi
else
    echo "Ubuntu Pro оставлен без изменений"
fi

# 5. Установка Flatpak (если выбрано)
if [ "$INSTALL_FLATPAK" = true ]; then
    echo "Установка Flatpak..."
    apt install -y flatpak
    
    # Добавление Flathub репозитория
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    # Интеграция с GNOME Software (если используется GNOME)
    apt install -y gnome-software-plugin-flatpak 2>/dev/null || echo "GNOME Software не найден, пропускаем интеграцию"
    
    echo "Flatpak успешно установлен"
else
    echo "Flatpak не будет установлен"
fi

# Обновление системы
echo "Обновление списка пакетов..."
apt update

echo ""
echo "=== Все операции завершены ==="
echo "Рекомендуется перезагрузить систему для полного применения изменений"

# Вывод сводки по изменениям
echo ""
echo "=== Сводка выполненных действий ==="
[ "$REMOVE_SNAP" = true ] && echo "- Snap удален"
[ "$REMOVE_LIBREOFFICE" = true ] && echo "- LibreOffice удален"
[ "$DISABLE_TELEMETRY" = true ] && echo "- Телеметрия отключена"
[ "$REMOVE_UBUNTU_PRO" = true ] && echo "- Ubuntu Pro удален"
[ "$INSTALL_FLATPAK" = true ] && echo "- Flatpak установлен"
