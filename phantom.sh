#!/bin/bash
# PhantomKernel Build Script - Optimized Version
# Optimized: Out-of-tree build (compiled in 'out' directory) & Simplified Logic

# --- COLOR FORMATTING ---
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"
NC="\033[0m" # No Color

# --- MAIN ENVIRONMENT VARIABLES ---
CR_DIR=$(pwd)
CR_OUT_DIR="$CR_DIR/out" # All build files will be generated in this directory
CR_TC="/run/media/haruka/DATA/Kernel_Android/toolchain/aarch64--glibc--stable-2025.08-1/bin/aarch64-buildroot-linux-gnu-"
CR_DTS_SRC="arch/arm64/boot/dts"
CR_DTS_OUT="$CR_OUT_DIR/arch/arm64/boot/dts" # DTS path after O=out build

CR_OUT="$CR_DIR/PHANTOM/Out"
CR_PRODUCT="$CR_DIR/PHANTOM/Product"
CR_AIK="$CR_DIR/PHANTOM/A.I.K"
CR_RAMDISK="$CR_DIR/PHANTOM/universal7570"

CR_KERNEL="$CR_OUT_DIR/arch/arm64/boot/Image" # Get Image from the out directory
CR_DTB="$CR_DIR/boot.img-dtb"

CR_VERSION="V2"
CR_NAME="PhantomKernel"
CR_JOBS=$(nproc --all)
CR_ANDROID="q"
CR_PLATFORM="10.0.0"
CR_ARCH="arm64"

export CROSS_COMPILE=$CR_TC
export ANDROID_MAJOR_VERSION=$CR_ANDROID
export PLATFORM_VERSION=$CR_PLATFORM
export ARCH=$CR_ARCH

# Flashable Variables
FL_DIR="$CR_DIR/PHANTOM/Flashable"
FL_EXPORT="$CR_DIR/PHANTOM/Flashable_OUT"
FL_SCRIPT="$FL_EXPORT/META-INF/com/google/android/updater-script"

# Create necessary directories if they don't exist
mkdir -p "$CR_OUT_DIR"
mkdir -p "$CR_OUT"
mkdir -p "$CR_PRODUCT"

# =========================================================
# FUNCTIONS
# =========================================================

BUILD_CLEAN() {
    if [ "$CR_CLEAN" = "1" ]; then
        echo -e "${CYAN}>> Cleaning environment (Clean Build)...${NC}"
        rm -rf "$CR_OUT_DIR"/*
        rm -rf "$CR_DTB"
        rm -rf "$CR_OUT"/*.img
        rm -rf "$CR_OUT"/*.zip
        rm -f arch/arm64/configs/tmp_defconfig
    else
        echo -e "${YELLOW}>> Skipping deep clean (Dirty Build)...${NC}"
        rm -rf "$CR_DTB"
    fi
}

BUILD_GENERATE_CONFIG() {
    echo -e "${CYAN}>> Generating Defconfig for ${CR_VARIANT}...${NC}"
    
    # Merge config files into a single tmp_defconfig
    rm -f arch/arm64/configs/tmp_defconfig
    cat arch/arm64/configs/${CR_CONFIG_BASE} > arch/arm64/configs/tmp_defconfig
    cat arch/arm64/configs/${CR_CONFIG_USB} >> arch/arm64/configs/tmp_defconfig
    cat arch/arm64/configs/exynos7570-phantom_defconfig >> arch/arm64/configs/tmp_defconfig
    
    # Set target config variable for make
    CR_CONFIG_TARGET="tmp_defconfig"
}

BUILD_ZIMAGE() {
    echo -e "${GREEN}>> Starting Kernel compilation (zImage)...${NC}"
    
    # Copy corresponding Makefile (J2/J3/J4/J5) to source code
    cp -f "$CR_COMP" "$CR_DIR/$CR_DTS_SRC/Makefile"
    
    export LOCALVERSION="-$CR_IMAGE_NAME"
    
    # BUILD IN OUT DIRECTORY (O=out)
    make O="$CR_OUT_DIR" $CR_CONFIG_TARGET
    make O="$CR_OUT_DIR" -j$CR_JOBS

    if [ ! -f "$CR_KERNEL" ]; then
        echo -e "${RED}>> Error: Image file not found! Aborting script.${NC}"
        exit 1
    fi
}

BUILD_DTB() {
    echo -e "${GREEN}>> Compiling DTB...${NC}"
    # dtbtool scans the out directory for compiled .dtb files
    ./scripts/dtbtool_exynos/dtbTool -o "$CR_DTB" -d "$CR_DTS_OUT/" -s 2048
    
    if [ ! -f "$CR_DTB" ]; then
        echo -e "${RED}>> Error: DTB compilation failed!${NC}"
        exit 1
    fi
}

PACK_BOOT_IMG() {
    echo -e "${GREEN}>> Packing Boot.img using A.I.K...${NC}"
    cp -rf "$CR_RAMDISK"/* "$CR_AIK"
    mv "$CR_KERNEL" "$CR_AIK/split_img/boot.img-zImage"
    mv "$CR_DTB" "$CR_AIK/split_img/boot.img-dtb"
    
    cd "$CR_AIK" || exit
    ./repackimg.sh
    echo -n "SEANDROIDENFORCE" >> image-new.img
    cd "$CR_DIR" || exit

    cp "$CR_AIK/image-new.img" "$CR_PRODUCT/$CR_IMAGE_NAME.img"
    mv "$CR_AIK/image-new.img" "$CR_OUT/$CR_IMAGE_NAME.img"
    "$CR_AIK/cleanup.sh"
}

PACK_FLASHABLE() {
    echo -e "${CYAN}>> Creating Recovery Flashable ZIP...${NC}"
    FL_DEVICE="$FL_EXPORT/PHANTOM/device/$FL_MODEL/boot.img"
    
    rm -rf "$FL_EXPORT"
    mkdir -p "$FL_EXPORT"
    cp -rf "$FL_DIR"/* "$FL_EXPORT"
    
    sed -i "s/FL_NAME/ui_print(\"* $CR_NAME\");/g" "$FL_SCRIPT"
    sed -i "s/FL_VERSION/ui_print(\"* $CR_VERSION\");/g" "$FL_SCRIPT"
    sed -i "s/FL_VARIANT/ui_print(\"* For $FL_VARIANT \");/g" "$FL_SCRIPT"
    
    cp "$CR_OUT/$CR_IMAGE_NAME.img" "$FL_DEVICE"
    
    cd "$FL_EXPORT" || exit
    zip -r "$CR_OUT/$CR_NAME-$CR_VERSION-$FL_VARIANT.zip" . > /dev/null
    cd "$CR_DIR" || exit
    
    cp "$CR_OUT/$CR_NAME-$CR_VERSION-$FL_VARIANT.zip" "$CR_PRODUCT/"
    rm -rf "$FL_EXPORT"
    rm -f arch/arm64/configs/tmp_defconfig
}

RUN_BUILD() {
    BUILD_IMAGE_NAME="${CR_NAME}-${CR_VERSION}-${CR_VARIANT}"
    BUILD_CLEAN
    BUILD_GENERATE_CONFIG
    BUILD_ZIMAGE
    BUILD_DTB
    PACK_BOOT_IMG
    PACK_FLASHABLE
    
    echo -e "${GREEN}----------------------------------------------${NC}"
    echo -e "${CYAN}>> Compilation completed for: ${CR_VARIANT}${NC}"
    echo -e " Image: $CR_PRODUCT/$BUILD_IMAGE_NAME.img"
    echo -e " Zip:   $CR_PRODUCT/$CR_NAME-$CR_VERSION-$FL_VARIANT.zip"
    echo -e "${GREEN}----------------------------------------------${NC}"
}

# =========================================================
# USER INPUT AND MENU
# =========================================================

clear
echo -e "${GREEN}==============================================${NC}"
echo -e "${YELLOW}  $CR_NAME $CR_VERSION Build Script (Out-of-Tree)${NC}"
echo -e "${GREEN}==============================================${NC}"

read -p ">> Do you want to Clean source? (Y/n) > " yn
[[ "$yn" == "Y" || "$yn" == "y" || -z "$yn" ]] && CR_CLEAN="1" || CR_CLEAN="0"

read -p ">> Select Variant (1 = OneUI | 2 = AOSP) > " aud
if [[ "$aud" == "2" || "${aud^^}" == "AOSP" ]]; then
    CR_CONFIG_USB="exynos7570-aosp_defconfig"
    VAR_SUFFIX="AOSP"
else
    CR_CONFIG_USB="exynos7570-oneui_defconfig"
    VAR_SUFFIX="OneUI"
fi

echo -e "\nSelect device to build:"
PS3='Enter a number (1-6): '
menuvar=("SM-G570X" "SM-J330X" "SM-G390X" "SM-J400X" "SM-J260X" "Exit")
select device in "${menuvar[@]}"; do
    case $device in
        "SM-G570X"|"SM-J330X"|"SM-G390X"|"SM-J400X"|"SM-J260X")
            clear
            echo -e "${YELLOW}>> Preparing to build for $device ($VAR_SUFFIX)...${NC}"
            
            # Automatically assign variables based on device name
            case $device in
                "SM-G570X")
                    CR_CONFIG_BASE="exynos7570-on5xelte_defconfig"
                    CR_COMP="$CR_DIR/PHANTOM/MakefileJ5"
                    FL_MODEL="on5xelte"
                    CR_VARIANT="G570X-$VAR_SUFFIX"
                    FL_VARIANT="G570X-$VAR_SUFFIX"
                    ;;
                "SM-J330X")
                    CR_CONFIG_BASE="exynos7570-j3y17lte_defconfig"
                    CR_COMP="$CR_DIR/PHANTOM/MakefileJ3"
                    FL_MODEL="j3y17lte"
                    CR_VARIANT="J330X-$VAR_SUFFIX"
                    FL_VARIANT="J330X-$VAR_SUFFIX"
                    ;;
                "SM-G390X")
                    CR_CONFIG_BASE="exynos7570-j7y17lte_defconfig"
                    CR_COMP="$CR_DIR/PHANTOM/MakefileJ4" 
                    FL_MODEL="j7y17lte"
                    CR_VARIANT="G390X-$VAR_SUFFIX"
                    FL_VARIANT="G390X-$VAR_SUFFIX"
                    ;;
                "SM-J400X")
                    CR_CONFIG_BASE="exynos7570-j4lte_defconfig"
                    CR_COMP="$CR_DIR/PHANTOM/MakefileJ4"
                    FL_MODEL="j4lte"
                    CR_VARIANT="J400X-$VAR_SUFFIX"
                    FL_VARIANT="J400X-$VAR_SUFFIX"
                    ;;
                "SM-J260X")
                    CR_CONFIG_BASE="exynos7570-j2corelte_defconfig"
                    CR_COMP="$CR_DIR/PHANTOM/MakefileJ2"
                    FL_MODEL="j2corelte"
                    CR_VARIANT="J260X-$VAR_SUFFIX"
                    FL_VARIANT="J260X-$VAR_SUFFIX"
                    ;;
            esac
            
            RUN_BUILD
            break
            ;;
        "Exit")
            echo -e "${CYAN}Goodbye!${NC}"
            break
            ;;
        *) echo -e "${RED}Invalid option.${NC}";;
    esac
done
