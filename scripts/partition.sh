#!/bin/sh
set -eu

ROOT="/mnt"            # Root mount point
EFI_SIZE_MB=512        # EFI partition size
SWAP_SIZE_GB=4         # SWAP partition size

# ========================================
# List available disks with SIZE and MODEL
# ========================================
printf "Available disks:"
DISK_LIST=$(lsblk -d -o NAME,SIZE,MODEL -n | grep -E '^sd|^nvme')
printf "\n%s\n\n" "$DISK_LIST"

# ========================================
# Select disk
# ========================================
DISK_NAMES=$(echo "$DISK_LIST" | awk '{print $1}')                      # Create an array of disk names only
printf "Select the disk to install Void Linux on:\n"

i=1; for disk in $DISK_NAMES; do
    printf "%d) %s\n" "$i" "$disk"; i=$((i+1));
done

while true; do
    
    printf "Enter number: "
    read -r choice </dev/tty

    # Validate positive integer
    if ! printf '%s\n' "$choice" | grep -qE '^[1-9][0-9]*$'; then
        printf "Try again.\n"; continue;
    fi

    # Map choice to disk (line-based)
    selected=$(printf '%s\n' $DISK_NAMES | sed -n "${choice}p")

    if [ -n "$selected" ]; then
        SELECTED_DISK="/dev/$selected"
        printf "\nSelected disk: %s\n" "$SELECTED_DISK"
        break
    else
        printf "Try again.\n"
    fi
done

# ========================================
# Message: Disk in DANGER
# ========================================
printf "\nWARNING: All data on the disk will be ERASED. "
while true; do
    printf "Proceed? [Y/n]: "
    read -r yn </dev/tty
    yn=${yn:-Y}
    case "$yn" in
        [Yy]* )
            printf "\033[1A"
            printf "\r" 
            printf "\033[K"
            printf "\rFormatting in 3 sec"
            for i in 2 1 0; do
                sleep 1
                printf "\rFormatting in %d sec" "$i"
            done
            printf "\r\033[K\r"
            break
            ;;
        [Nn]* )
            printf "Aborting.\n"
            exit 1
            ;;
        * )
            echo "Please answer Y or n."
            ;;
    esac
done

# ========================================
# Create partitions
# ========================================
printf "[1/4] Creating partitions ...\n"

PART_TABLE=$(cat <<EOF
label: gpt
,${EFI_SIZE_MB}M,U,*
,${SWAP_SIZE_GB}G,S,
,,L,
EOF
)

printf "%s" "$PART_TABLE" | sfdisk --force "$SELECTED_DISK" > /dev/null

# ========================================
# Format partitions
# ========================================
if echo "$SELECTED_DISK" | grep -q '^/dev/nvme'; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

printf "[3/4] Formatting partitions ...\n"
mkfs.fat -F32 "${SELECTED_DISK}${PART_SUFFIX}1"
mkswap "${SELECTED_DISK}${PART_SUFFIX}2"
swapon "${SELECTED_DISK}${PART_SUFFIX}2"
mkfs.ext4 -F "${SELECTED_DISK}${PART_SUFFIX}3"
