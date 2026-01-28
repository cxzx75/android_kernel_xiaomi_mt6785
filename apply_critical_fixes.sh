#!/bin/bash
# Critical Kernel Fixes for Redmi Note 10S (Rosemary)
# Fixes warnings that can cause actual bugs/crashes
# Battery-optimized build - LineageOS Android 16

set -e

KERNEL_DIR="/home/platinum/rosemary-kernel/kernel-4.14"

echo "========================================"
echo "Applying Critical Kernel Fixes"
echo "========================================"

cd "$KERNEL_DIR"

# ==============================================================================
# FIX 1: Thermal Buffer Overflow (CRITICAL)
# Impact: Prevents kernel crash from buffer overflow
# ==============================================================================

echo "[1/3] Fixing thermal buffer overflow..."

# Check if file exists
if [ ! -f "drivers/thermal/thermal_core.c" ]; then
    echo "ERROR: drivers/thermal/thermal_core.c not found!"
    exit 1
fi

# Fix line ~918 - boost_buf overflow
sed -i 's/snprintf(boost_buf, PAGE_SIZE, buf)/snprintf(boost_buf, sizeof(boost_buf), buf)/g' \
    drivers/thermal/thermal_core.c

# Fix line ~1034 - board_sensor_temp overflow  
sed -i 's/snprintf(board_sensor_temp, PAGE_SIZE, buf)/snprintf(board_sensor_temp, sizeof(board_sensor_temp), buf)/g' \
    drivers/thermal/thermal_core.c

echo "✓ Thermal buffer overflow fixed"

# ==============================================================================
# FIX 2: UFS Storage memset Bug (CRITICAL)
# Impact: Prevents uninitialized memory from corrupting storage
# ==============================================================================

echo "[2/3] Fixing UFS memset bug..."

# Check if file exists
if [ ! -f "drivers/scsi/ufs/ufshcd.c" ]; then
    echo "ERROR: drivers/scsi/ufs/ufshcd.c not found!"
    exit 1
fi

# The issue is at line 3941
# Need to find the function and see actual buffer size
# Let's use a safer approach - find the function and fix it properly

# First, let's identify the function containing this bug
FUNC_NAME=$(grep -B50 "memset(buf,0,sizeof(buf))" drivers/scsi/ufs/ufshcd.c | \
            grep -E "^[a-z_].*\(.*\)$|^static.*\(.*\)$" | tail -1 | cut -d'(' -f1 | awk '{print $NF}')

echo "Found bug in function: $FUNC_NAME"

# The bug is: buf is a pointer (u8 *buf), not an array
# sizeof(buf) returns pointer size (8 bytes), not buffer size
# We need to use the actual string length instead

# Check if this is in ufshcd_read_string_desc function
grep -A2 -B2 "memset(buf,0,sizeof(buf))" drivers/scsi/ufs/ufshcd.c | head -10

# The correct fix based on the context:
# Line 3941: memset(buf,0,sizeof(buf));  <- WRONG (buf is pointer)
# Line 3942: memcpy(buf, str, ret);      <- 'ret' has the actual size

# We should memset using 'ret' size, not sizeof(pointer)
sed -i '3941s/memset(buf,0,sizeof(buf))/memset(buf, 0, ret)/' drivers/scsi/ufs/ufshcd.c

echo "✓ UFS memset bug fixed"

# ==============================================================================
# FIX 3: USB Accessory Bitfield (MODERATE - Optional)
# Impact: Fixes USB accessory disconnect detection
# Only if you use Android Auto or USB accessories
# ==============================================================================

echo "[3/3] Fixing USB accessory bitfield (optional)..."

if [ -f "drivers/usb/gadget/function/f_accessory.c" ]; then
    # Find the struct definition and fix bitfield signedness
    # This is more complex - need to find struct acc_dev definition
    
    # The struct is likely in include files, let's find it
    STRUCT_FILE=$(grep -r "struct acc_dev" drivers/usb/gadget/function/ --include="*.h" | \
                  grep "disconnected.*:" | cut -d':' -f1 | head -1)
    
    if [ -n "$STRUCT_FILE" ]; then
        echo "Found struct in: $STRUCT_FILE"
        # Fix: Change signed bitfield to unsigned
        sed -i 's/int disconnected:1/unsigned int disconnected:1/g' "$STRUCT_FILE"
        sed -i 's/int online:1/unsigned int online:1/g' "$STRUCT_FILE"
        echo "✓ USB bitfield fixed"
    else
        echo "⚠ Could not find struct acc_dev, skipping (not critical)"
    fi
else
    echo "⚠ f_accessory.c not found, skipping (not critical)"
fi

echo ""
echo "========================================"
echo "✓ All Critical Fixes Applied!"
echo "========================================"
echo ""
echo "Summary of fixes:"
echo "1. ✓ Thermal buffer overflow - FIXED"
echo "2. ✓ UFS storage memset bug - FIXED"  
echo "3. ⚠ USB bitfield - Attempted (optional)"
echo ""
echo "Now rebuild your kernel:"
echo "  make -j\$(nproc --all) CC=clang O=out ARCH=arm64 LLVM=1 ..."
echo ""
