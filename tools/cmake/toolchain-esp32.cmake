message(STATUS "importing the toolchain cmake directory")

if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    get_filename_component( WORK_PATH "${ICON_TOOLCHAIN_DIR}/mac/xtensa-esp32-elf/bin" ABSOLUTE)
    #Set the ESP device port if it has not been set before
    if(DEFINED ESPPORT_OVER_RIDE)
        set(ESPPORT ${ESPPORT_OVER_RIDE})
    else()
        set(ESPPORT /dev/cu.SLAB_USBtoUART)
    endif(DEFINED ESPPORT_OVER_RIDE)
    set(ESPBAUD 115200)
    set(ESPRESSIF_TOOLCHAIN_PATH "${WORK_PATH}")
	set(OPENOCD_PATH "${ICON_TOOLCHAIN_DIR}/mac/openocd-esp32")
elseif (CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    get_filename_component( WORK_PATH "${ICON_TOOLCHAIN_DIR}/linux/xtensa-esp32-elf/bin" ABSOLUTE)
    #Set the ESP device port if it has not been set before
    if(DEFINED ESPPORT_OVER_RIDE)
        set(ESPPORT ${ESPPORT_OVER_RIDE})
    else()
        set(ESPPORT /dev/ttyUSB0)
    endif(DEFINED ESPPORT_OVER_RIDE)
    set(ESPBAUD 115200)
    set(ESPRESSIF_TOOLCHAIN_PATH "${WORK_PATH}")
	set(OPENOCD_PATH "${ICON_TOOLCHAIN_DIR}/linux/openocd-esp32")
else()
    message( FATAL_ERROR "Cannot Configure for ${CMAKE_HOST_SYSTEM_NAME}")
endif()

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_C_COMPILER ${WORK_PATH}/xtensa-esp32-elf-gcc)
set(CMAKE_CXX_COMPILER ${WORK_PATH}/xtensa-esp32-elf-g++)
set(CMAKE_ASM_COMPILER ${WORK_PATH}/xtensa-esp32-elf-gcc)
set(CMAKE_GDB ${WORK_PATH}/xtensa-esp32-elf-gdb)
set(CMAKE_OBJDUMP ${WORK_PATH}/xtensa-esp32-elf-objdump)

set(CMAKE_C_FLAGS "-mlongcalls -Wno-frame-address" CACHE STRING "C Compiler Base Flags")
set(CMAKE_ASM_FLAGS "" CACHE STRING "ASM Compiler Base Flags") #  -Wno-frame-address -mtext-section-literals -mlongcalls
set(CMAKE_CXX_FLAGS "-mlongcalls -Wno-frame-address" CACHE STRING "C++ Compiler Base Flags")

message(STATUS "CMAKE_ASM_FLAGS: ${CMAKE_ASM_FLAGS}")

# Can be removed after gcc 5.2.0 support is removed (ref GCC_NOT_5_2_0)
set(CMAKE_EXE_LINKER_FLAGS "-nostdlib" CACHE STRING "Linker Base Flags")


