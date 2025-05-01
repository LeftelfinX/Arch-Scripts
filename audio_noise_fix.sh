#!/bin/bash

set -e

echo "🔧 Disabling PipeWire and ALSA audio power saving..."

# Step 1: Patch PipeWire config
mkdir -p ~/.config/pipewire

for FILE in pipewire.conf pipewire-pulse.conf; do
    SYSTEM_CONF="/etc/pipewire/$FILE"
    USER_CONF="$HOME/.config/pipewire/$FILE"

    if [[ -f "$SYSTEM_CONF" ]]; then
        cp "$SYSTEM_CONF" "$USER_CONF"
        echo "✅ Copied $FILE to user config"

        # Edit suspend timeout
        sed -i '/context\.properties\s*=/,/}/s/#\?\s*suspend-timeout-seconds\s*=.*/    suspend-timeout-seconds = 0/' "$USER_CONF"
        echo "🔧 Set suspend-timeout-seconds = 0 in $FILE"
    else
        echo "⚠️  $SYSTEM_CONF not found. Skipping."
    fi
done

# Step 2: Disable ALSA power saving
MODPROBE_CONF="/etc/modprobe.d/audio_powersave.conf"
sudo bash -c "echo 'options snd_hda_intel power_save=0 power_save_controller=N' > $MODPROBE_CONF"
echo "🔒 ALSA power saving disabled in $MODPROBE_CONF"

# Step 3: Rebuild initramfs
echo "🔁 Rebuilding initramfs..."
sudo mkinitcpio -P

# Step 4: Restart PipeWire
echo "🔁 Restarting PipeWire..."
systemctl --user daemon-reexec
systemctl --user restart pipewire pipewire-pulse

echo "✅ Done! Please reboot to ensure ALSA changes are applied."
