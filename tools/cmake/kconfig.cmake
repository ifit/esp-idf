include(ExternalProject)

function(__kconfig_init)
    message(STATUS "***Starting up __kconfig_init()***")
    if(${CMAKE_HOST_SYSTEM_NAME} MATCHES "FreeBSD")
        set(MAKE_COMMMAND "gmake")
    else()
        set(MAKE_COMMMAND "make")
    endif()

    idf_build_get_property(idf_path IDF_PATH)
    if(CMAKE_HOST_WIN32 AND DEFINED ENV{MSYSTEM})
        # Prefer a prebuilt mconf-idf on Windows
        find_program(WINPTY winpty)
        unset(MCONF CACHE)  # needed when MSYS and CMD is intermixed (cache could contain an incompatible path)
        find_program(MCONF mconf-idf)

        # Fall back to the old binary which was called 'mconf' not 'mconf-idf'
        if(NOT MCONF)
            find_program(MCONF mconf)
            if(MCONF)
                message(WARNING "Falling back to mconf binary '${MCONF}' not mconf-idf. "
                    "This is probably because an old version of IDF mconf is installed and this is fine. "
                    "However if there are config problems please check the Getting Started guide for your platform.")
            endif()
        endif()

        if(NOT MCONF)
            find_program(NATIVE_GCC gcc)
            if(NOT NATIVE_GCC)
                message(FATAL_ERROR
                    "Windows requires an MSYS2 version of gcc on the PATH to build mconf-idf. "
                    "Consult the setup docs for ESP-IDF on Windows.")
            else()
                # Use the existing Makefile to build mconf (out of tree) when needed
                #
                set(MCONF ${CMAKE_BINARY_DIR}/kconfig_bin/mconf-idf)
                set(src_path ${idf_path}/tools/kconfig)

                # note: we preemptively remove any build files from the src dir
                # as we're building out of tree, but don't want build system to
                # #include any from there that were previously build with/for make
                externalproject_add(mconf-idf
                    SOURCE_DIR ${src_path}
                    CONFIGURE_COMMAND ""
                    BINARY_DIR "${CMAKE_BINARY_DIR}/kconfig_bin"
                    BUILD_COMMAND rm -f ${src_path}/zconf.lex.c ${src_path}/zconf.hash.c
                    COMMAND ${MAKE_COMMMAND} -f ${src_path}/Makefile mconf-idf
                    BUILD_BYPRODUCTS ${MCONF}
                    INSTALL_COMMAND ""
                    EXCLUDE_FROM_ALL 1
                    )

                file(GLOB mconf_srcfiles ${src_path}/*.c)
                list(REMOVE_ITEM mconf_srcfiles "${src_path}/zconf.lex.c" "${src_path}/zconf.hash.c")
                externalproject_add_stepdependencies(mconf-idf build
                    ${mconf_srcfiles}
                    ${src_path}/Makefile
                    ${CMAKE_CURRENT_LIST_FILE})
                unset(mconf_srcfiles)
                unset(src_path)

                set(menuconfig_depends DEPENDS mconf-idf)
            endif()
        else()
            execute_process(COMMAND "${MCONF}" -v
                RESULT_VARIABLE mconf_res
                OUTPUT_VARIABLE mconf_out
                ERROR_VARIABLE mconf_err)
            if(${mconf_res})
                message(WARNING "Failed to detect version of mconf-idf. Return code was ${mconf_res}.")
            else()
                string(STRIP "${mconf_out}" mconf_out)
                set(mconf_expected_ver "mconf-v4.6.0.0-idf-20190628-win32")
                if(NOT ${mconf_out} STREQUAL "mconf-idf version ${mconf_expected_ver}")
                    message(WARNING "Unexpected ${mconf_out}. Expected ${mconf_expected_ver}. "
                                    "Please check the ESP-IDF Getting Started guide for version "
                                    "${IDF_VERSION_MAJOR}.${IDF_VERSION_MINOR}.${IDF_VERSION_PATCH} "
                                    "to correct this issue")
                else()
                    message(STATUS "${mconf_out}")   # prints: mconf-idf version ....
                endif()
            endif()
            if(WINPTY)
                set(MCONF "\"${WINPTY}\" \"${MCONF}\"")
            endif()
        endif()
        idf_build_set_property(__MCONF ${MCONF})
        idf_build_set_property(__MENUCONFIG_DEPENDS "${menuconfig_depends}")
    endif()

    if(NOT DEFINED OVERRIDE_ROOT_KCONF)
        if(BOOTLOADER_BUILD)
        # set(BL_BASE_PROJECT_DIR ${ROOT_PROJECT_DIR}/../../../../../)
        get_filename_component(BL_BASE_PROJECT_DIR ${ROOT_PROJECT_DIR}/BUILD_HELPERS/esp32/esp_bootloader.kconf ABSOLUTE)
        message(STATUS "--------------------------")
        message(STATUS "this is a bootloader build")
        message(STATUS "BL_BASE_PROJECT_DIR: ${BL_BASE_PROJECT_DIR}")
        message(STATUS "--------------------------")
        set(ROOT_KCONFIG ${BL_BASE_PROJECT_DIR})
        else() 
            set(ROOT_KCONFIG ${IDF_PATH}/Kconfig)
        endif()
    	
    else()
    	message(STATUS "Using Override Kconfig")
    	set(ROOT_KCONFIG ${OVERRIDE_ROOT_KCONF})
    endif()

    idf_build_get_property(idf_path IDF_PATH)
    idf_build_set_property(__ROOT_KCONFIG ${ROOT_KCONFIG})
    idf_build_set_property(__ROOT_SDKCONFIG_RENAME ${idf_path}/sdkconfig.rename)
    idf_build_set_property(__OUTPUT_SDKCONFIG 1)
endfunction()

#
# Initialize Kconfig-related properties for components.
# This function assumes that all basic properties of the components have been
# set prior to calling it.
#
function(__kconfig_component_init component_target)
    message(STATUS "***Starting up __kconfig_component_init()***")
    __component_get_property(component_dir ${component_target} COMPONENT_DIR)
    file(GLOB kconfig "${component_dir}/Kconfig")
    __component_set_property(${component_target} KCONFIG "${kconfig}")
    file(GLOB kconfig "${component_dir}/Kconfig.projbuild")
    __component_set_property(${component_target} KCONFIG_PROJBUILD "${kconfig}")
    file(GLOB sdkconfig_rename "${component_dir}/sdkconfig.rename")
    __component_set_property(${component_target} SDKCONFIG_RENAME "${sdkconfig_rename}")
endfunction()

#
# Generate the config files and create config related targets and configure
# dependencies.
#
function(__kconfig_generate_config sdkconfig sdkconfig_defaults)
    message(STATUS "***Starting up __kconfig_generate_config()***")
    # List all Kconfig and Kconfig.projbuild in known components
    idf_build_get_property(component_targets __COMPONENT_TARGETS)
    idf_build_get_property(build_component_targets __BUILD_COMPONENT_TARGETS)
    foreach(component_target ${component_targets})
        if(component_target IN_LIST build_component_targets)
            __component_get_property(kconfig ${component_target} KCONFIG)
            __component_get_property(kconfig_projbuild ${component_target} KCONFIG_PROJBUILD)
            __component_get_property(sdkconfig_rename ${component_target} SDKCONFIG_RENAME)
            if(kconfig)
                list(APPEND kconfigs ${kconfig})
            endif()
            if(kconfig_projbuild)
                list(APPEND kconfig_projbuilds ${kconfig_projbuild})
            endif()
            if(sdkconfig_rename)
                list(APPEND sdkconfig_renames ${sdkconfig_rename})
            endif()
        endif()
    endforeach()

    # Store the list version of kconfigs and kconfig_projbuilds
    idf_build_set_property(KCONFIGS "${kconfigs}")
    idf_build_set_property(KCONFIG_PROJBUILDS "${kconfig_projbuilds}")

    idf_build_get_property(idf_target IDF_TARGET)
    idf_build_get_property(idf_path IDF_PATH)

    string(REPLACE ";" " " kconfigs "${kconfigs}")
    string(REPLACE ";" " " kconfig_projbuilds "${kconfig_projbuilds}")
    string(REPLACE ";" " " sdkconfig_renames "${sdkconfig_renames}")

	set(ICON_KCONFIGS_PROJBUILD ${PROJECT_BINARY_DIR}/PROJBUILD.kconf PARENT_SCOPE)
    set(ICON_KCONFIGS_PROJBUILD ${PROJECT_BINARY_DIR}/PROJBUILD.kconf)
    set(ICON_KCONFIGS_COMPONENTS ${PROJECT_BINARY_DIR}/COMPONENTSBUILD.kconf PARENT_SCOPE)
    set(ICON_KCONFIGS_COMPONENTS ${PROJECT_BINARY_DIR}/COMPONENTSBUILD.kconf)

    # These are the paths for files which will contain the generated "source" lines for COMPONENT_KCONFIGS and
    # COMPONENT_KCONFIGS_PROJBUILD
    set(kconfigs_projbuild_path "${CMAKE_CURRENT_BINARY_DIR}/kconfigs_projbuild.in")
    set(kconfigs_path "${CMAKE_CURRENT_BINARY_DIR}/kconfigs.in")

    # Place config-related environment arguments into config.env file
    # to work around command line length limits for execute_process
    # on Windows & CMake < 3.11
    set(config_env_path "${CMAKE_CURRENT_BINARY_DIR}/config.env")
    if(DEFINED ESP_SDK_KCONFIG)
        get_filename_component(CONF_ENV_PATH ${ESP_SDK_KCONFIG} DIRECTORY)
        message(STATUS "CONF_ENV_PATH: ${CONF_ENV_PATH}")
        if(BOOTLOADER_BUILD)
        set(TARGET_ICON_CONFIG ${CONF_ENV_PATH}/esp_bootloader.env.in)
        else()
            set(TARGET_ICON_CONFIG ${CONF_ENV_PATH}/config.env.in)
        endif(BOOTLOADER_BUILD)
        if(EXISTS ${TARGET_ICON_CONFIG})
            message(STATUS "using custom config.env.in")
            configure_file("${TARGET_ICON_CONFIG}" ${config_env_path})
        else()
            message(FATAL_ERROR "${TARGET_ICON_CONFIG} does not exist")
        endif(EXISTS ${TARGET_ICON_CONFIG})
    else()
        message(FATAL_ERROR "Usinng the ESP SDK config.env.in")
        configure_file("${idf_path}/tools/kconfig_new/config.env.in" ${config_env_path})
    endif(DEFINED ESP_SDK_KCONFIG)
    message(STATUS "config_env_path: ${config_env_path}")
    idf_build_set_property(CONFIG_ENV_PATH ${config_env_path})

    if(sdkconfig_defaults)
        foreach(sdkconfig_default ${sdkconfig_defaults})
            list(APPEND defaults_arg --defaults "${sdkconfig_default}")
        endforeach()
    endif()

    if(sdkconfig_defaults)
        foreach(sdkconfig_default ${sdkconfig_defaults})
            if(EXISTS "${sdkconfig_default}.${idf_target}")
                list(APPEND defaults_arg --defaults "${sdkconfig_default}.${idf_target}")
            endif()
        endforeach()
    endif()

    idf_build_get_property(root_kconfig __ROOT_KCONFIG)
    idf_build_get_property(root_sdkconfig_rename __ROOT_SDKCONFIG_RENAME)
    idf_build_get_property(python PYTHON)

    message(STATUS "root_kconfig: ${root_kconfig}")

    if(DEFINED ICON_GEN_KCONFIG_PY)
        set(gen_kconfig_base_command
            ${PYTHON} ${ICON_GEN_KCONFIG_PY}
        )
    endif()

    idf_build_get_property(local_kconfigs_projbuild KCONFIG_PROJBUILDS)
	string(REPLACE ";" " " kconfig_projbuilds_space "${local_kconfigs_projbuild}")
	string(STRIP ${kconfig_projbuilds_space} kconfig_projbuilds_space)
	idf_build_get_property(local_kconfigs KCONFIGS)
	string(REPLACE ";" " " kconfigs_space "${local_kconfigs}")
	string(STRIP ${kconfigs_space} kconfigs_space)

	if(DEFINED ICON_GEN_KCONFIG_PY)
	    #Generate the KCONFIG file for the PROJBUILD
        message(STATUS "Generating ${ICON_KCONFIGS_PROJBUILD}")
        if(BOOTLOADER_BUILD)
            message(STATUS "\tBOOTLOADER BUILD")
        endif()
		execute_process(
			COMMAND ${gen_kconfig_base_command}
			--out_name ${ICON_KCONFIGS_PROJBUILD}
			--sources ${kconfig_projbuilds_space}
			RESULT_VARIABLE gen_result
		)
		if(gen_result)
	        message(FATAL_ERROR "Failed to run kconfig gen (${gen_kconfig_base_command}). Error ${gen_result}")
		endif()
	
		message(STATUS "Generating ${ICON_KCONFIGS_COMPONENTS}")
        #Generate Kconfig for the Components
		execute_process(
			COMMAND ${gen_kconfig_base_command}
			--out_name ${ICON_KCONFIGS_COMPONENTS}
			--sources ${kconfigs_space}
			RESULT_VARIABLE gen_result
		)
		if(gen_result)
	        message(FATAL_ERROR "Failed to run kconfig gen (${gen_kconfig_base_command}). Error ${gen_result}")
		endif()
    endif()

    if(EXISTS ${ESP_SDK_KCONFIG})
		set(menuconfig_command
        "IDF_CMAKE=y"
        "KCONFIG_CONFIG=${sdkconfig}"
        "IDF_TARGET=${idf_target}"
        "ESP_SDK_KCONFIG=${ESP_SDK_KCONFIG}"
        "ICON_KCONFIGS_PROJBUILD=${ICON_KCONFIGS_PROJBUILD}"
    	"ICON_KCONFIGS_COMPONENTS=${ICON_KCONFIGS_COMPONENTS}"
        "ICON_HAL_KCONF=${ICON_HAL_KCONF}"
        "AWS_KCONFIG=${AWS_KCONFIG}"
    	"ICON_HAL_DIR=${ICON_HAL_DIR}"
    	"IDF_PATH=${IDF_PATH}"
        ${PYTHON} -m menuconfig ${root_kconfig}
        )
    else()
		set(menuconfig_command
		${CMAKE_COMMAND} -E env
        "COMPONENT_KCONFIGS=${kconfigs}"
        "COMPONENT_KCONFIGS_PROJBUILD=${kconfig_projbuilds}"
        "IDF_CMAKE=y"
        "KCONFIG_CONFIG=${sdkconfig}"
        "IDF_TARGET=${idf_target}"
        ${MCONF} ${root_kconfig})
	endif()


	if( EXISTS ${KCONF_CONFGEN_PY})
		message(FATAL_ERROR "Using override confgen")
	    set(confgen_basecommand
	        ${PYTHON} ${KCONF_CONFGEN_PY}
	        --kconfig ${ROOT_KCONFIG}
	        --config ${SDKCONFIG}
	        ${defaults_arg}
	        --env "COMPONENT_KCONFIGS=${kconfigs}"
	        --env "COMPONENT_KCONFIGS_PROJBUILD=${kconfigs_projbuild}"
	        --env "IDF_CMAKE=y"
	        --env "ICON_KCONFIGS_PROJBUILD=${ICON_KCONFIGS_PROJBUILD}"
	        --env "ICON_KCONFIGS_COMPONENTS=${ICON_KCONFIGS_COMPONENTS}"
	        --env "ESP_SDK_KCONFIG=${ESP_SDK_KCONFIG}"
	        --env "ICON_HAL_DIR=${ICON_HAL_DIR}"
            --env "ICON_HAL_KCONF=${ICON_HAL_KCONF}"
            --env "AWS_KCONFIG=${AWS_KCONFIG}")
    else()
    message(STATUS "Using confgen ${config_env_path}")
    set(confgen_basecommand
        ${python} ${idf_path}/tools/kconfig_new/confgen.py
        --kconfig ${root_kconfig}
        --sdkconfig-rename ${root_sdkconfig_rename}
        --config ${sdkconfig}
        ${defaults_arg}
        --env-file ${config_env_path})
    endif()

    idf_build_get_property(build_dir BUILD_DIR)
    set(config_dir ${build_dir}/config)
    file(MAKE_DIRECTORY "${config_dir}")

    message(STATUS "Project sdkconfig file ${sdkconfig}")

    set(prepare_kconfig_files_command
        ${python} ${idf_path}/tools/kconfig_new/prepare_kconfig_files.py
        --env-file ${config_env_path})

    set(confgen_basecommand
        ${python} ${idf_path}/tools/kconfig_new/confgen.py
        --kconfig ${root_kconfig}
        --sdkconfig-rename ${root_sdkconfig_rename}
        --config ${sdkconfig}
        ${defaults_arg}
        --env-file ${config_env_path})

    # Generate the config outputs
    set(sdkconfig_cmake ${config_dir}/sdkconfig.cmake)
    set(sdkconfig_header ${config_dir}/sdkconfig.h)
    set(AUTOCONF_H ${sdkconfig_header} PARENT_SCOPE)
	set(AUTOCONF_H ${sdkconfig_header})
	message(STATUS "set AUTOCONF_H to ${AUTOCONF_H}")
    set(sdkconfig_json ${config_dir}/sdkconfig.json)
    set(sdkconfig_json_menus ${config_dir}/kconfig_menus.json)

    message(STATUS "sdkconfig_header: ${sdkconfig_header}")

    idf_build_get_property(output_sdkconfig __OUTPUT_SDKCONFIG)
    message(STATUS "output_sdkconfig: ${output_sdkconfig}")
    if(output_sdkconfig)
        execute_process(
            COMMAND ${prepare_kconfig_files_command})
        message(STATUS "Generating Kconfig")
        execute_process(
            COMMAND ${confgen_basecommand}
            --output header ${sdkconfig_header}
            --output cmake ${sdkconfig_cmake}
            --output json ${sdkconfig_json}
            --output json_menus ${sdkconfig_json_menus}
            --output config ${sdkconfig}
            RESULT_VARIABLE config_result)
    else()
        execute_process(
            COMMAND ${prepare_kconfig_files_command})
        message(STATUS "output_sdkconfig: ${output_sdkconfig}")
        execute_process(
            COMMAND ${confgen_basecommand}
            --output header ${sdkconfig_header}
            --output cmake ${sdkconfig_cmake}
            --output json ${sdkconfig_json}
            --output json_menus ${sdkconfig_json_menus}
            RESULT_VARIABLE config_result)
    endif()

    if(config_result)
        message(FATAL_ERROR "Failed to run confgen.py (${confgen_basecommand}). Error ${config_result}")
    endif()
    message(STATUS "sdkconfig: ${sdkconfig}")
    # Add the generated config header to build specifications.
    idf_build_set_property(INCLUDE_DIRECTORIES ${config_dir} APPEND)

    # When sdkconfig file changes in the future, trigger a cmake run
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${sdkconfig}")

    # Ditto if either of the generated files are missing/modified (this is a bit irritating as it means
    # you can't edit these manually without them being regenerated, but I don't know of a better way...)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${sdkconfig_header}")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${sdkconfig_cmake}")

    # Or if the config generation tool changes
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${idf_path}/tools/kconfig_new/confgen.py")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${idf_path}/tools/kconfig_new/kconfiglib.py")

    set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" APPEND PROPERTY
                ADDITIONAL_MAKE_CLEAN_FILES "${sdkconfig_header}" "${sdkconfig_cmake}")

    idf_build_set_property(SDKCONFIG_HEADER ${sdkconfig_header})
    idf_build_set_property(SDKCONFIG_JSON ${sdkconfig_json})
    idf_build_set_property(SDKCONFIG_CMAKE ${sdkconfig_cmake})
    idf_build_set_property(SDKCONFIG_JSON_MENUS ${sdkconfig_json_menus})
    idf_build_set_property(CONFIG_DIR ${config_dir})

    if(CMAKE_HOST_WIN32 AND DEFINED ENV{MSYSTEM})
        idf_build_get_property(menuconfig_depends __MENUCONFIG_DEPENDS)
        idf_build_get_property(mconf __MCONF)

        set(MENUCONFIG_CMD ${mconf})
    else()
        set(MENUCONFIG_CMD ${python} ${idf_path}/tools/kconfig_new/menuconfig.py)
        set(TERM_CHECK_CMD ${python} ${idf_path}/tools/check_term.py)
    endif()

    if( NOT DEFINED ICON_HAL_KCONF AND NOT BOOTLOADER_BUILD)
        message(FATAL_ERROR "ICON_HAL_KCONF must be set")
    endif()

    # Generate the menuconfig target (uses C-based mconf-idf tool, either prebuilt or via mconf-idf target above)
    add_custom_target(menuconfig
        ${menuconfig_depends}
        # create any missing config file, with defaults if necessary
        COMMAND ${prepare_kconfig_files_command}
        COMMAND ${confgen_basecommand}
        --env "IDF_TARGET=${idf_target}"
        --dont-write-deprecated
        --output config ${sdkconfig}
        COMMAND ${TERM_CHECK_CMD}
        COMMAND ${CMAKE_COMMAND} -E env
        "COMPONENT_KCONFIGS_SOURCE_FILE=${ICON_KCONFIGS_COMPONENTS}"
        "COMPONENT_KCONFIGS_PROJBUILD_SOURCE_FILE=${ICON_KCONFIGS_PROJBUILD}"
        "IDF_CMAKE=y"
        "KCONFIG_CONFIG=${sdkconfig}"
        "IDF_TARGET=${idf_target}"
        "ESP_SDK_KCONFIG=${ESP_SDK_KCONFIG}"
        "ICON_KCONFIGS_PROJBUILD=${ICON_KCONFIGS_PROJBUILD}"
    	"ICON_KCONFIGS_COMPONENTS=${ICON_KCONFIGS_COMPONENTS}"
        "ICON_HAL_KCONF=${ICON_HAL_KCONF}"
        "AWS_KCONFIG=${AWS_KCONFIG}"
    	"ICON_HAL_DIR=${ICON_HAL_DIR}"
    	"IDF_PATH=${IDF_PATH}"
        ${MENUCONFIG_CMD} ${root_kconfig}
        # VERBATIM cannot be used here because it cannot handle ${mconf}="winpty mconf-idf" and the escaping must be
        # done manually
        USES_TERMINAL
        # additional run of confgen esures that the deprecated options will be inserted into sdkconfig (for backward
        # compatibility)
        COMMAND ${confgen_basecommand} --env "IDF_TARGET=${idf_target}" --output config ${sdkconfig}
        )
        
	add_custom_target(just_menuconfig
		${menuconfig_depends}
		COMMAND ${menuconfig_command}
		USES_TERMINAL
		#COMMAND_EXPAND_LISTS
		)

    # Custom target to run confserver.py from the build tool
    add_custom_target(confserver
        COMMAND ${prepare_kconfig_files_command}
        COMMAND ${PYTHON} ${IDF_PATH}/tools/kconfig_new/confserver.py
        --env-file ${config_env_path}
        --kconfig ${IDF_PATH}/Kconfig
        --sdkconfig-rename ${root_sdkconfig_rename}
        --config ${sdkconfig}
        VERBATIM
        USES_TERMINAL)
endfunction()
