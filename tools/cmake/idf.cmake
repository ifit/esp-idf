get_property(__idf_env_set GLOBAL PROPERTY __IDF_ENV_SET)
if(NOT __idf_env_set)
    # Infer an IDF_PATH relative to the tools/cmake directory
    get_filename_component(_idf_path "${CMAKE_CURRENT_LIST_DIR}/../.." REALPATH)
    file(TO_CMAKE_PATH "${_idf_path}" _idf_path)

    # Get the path set in environment
    set(idf_path $ENV{IDF_PATH})
    file(TO_CMAKE_PATH "${idf_path}" idf_path)

    # Environment IDF_PATH should match the inferred IDF_PATH. If not, warn the user.
    # (Note: REALPATH is needed in both above steps to account for case on case
    # insensitive filesystems, or relative paths)
    if(idf_path)
        get_filename_component(idf_path "${idf_path}" REALPATH)
        file(TO_CMAKE_PATH "${idf_path}" idf_path)

        if(NOT idf_path STREQUAL _idf_path)
            message(WARNING "IDF_PATH environment variable is different from inferred IDF_PATH.
                            Check if your project's top-level CMakeLists.txt includes the right
                            CMake files. Environment IDF_PATH will be used for the build:
                            ${idf_path}")
        else()
            message(STATUS "Successfully set idf_path to ${idf_path}")
        endif()
    else()
        message(WARNING "IDF_PATH environment variable not found. Setting IDF_PATH to '${_idf_path}'.")
        set(idf_path ${_idf_path})
        set(ENV{IDF_PATH} ${_idf_path})
    endif()

    # Include other CMake modules required
    set(CMAKE_MODULE_PATH
        "${CMAKE_CURRENT_LIST_DIR}/tools/cmake"
        "${CMAKE_CURRENT_LIST_DIR}/tools/cmake/third_party"
        ${CMAKE_MODULE_PATH})
    include(${CMAKE_CURRENT_LIST_DIR}/build.cmake)

    set(IDF_PATH ${idf_path})

    message(STATUS "CMAKE_CURRENT_LIST_DIR: ${CMAKE_CURRENT_LIST_DIR}")
    
    include(${CMAKE_CURRENT_LIST_DIR}/third_party/GetGitRevisionDescription.cmake)
    include(${CMAKE_CURRENT_LIST_DIR}/git_submodules.cmake)
    include(${CMAKE_CURRENT_LIST_DIR}/crosstool_version_check.cmake)
    set(KCONFIG_CMAKE_DIR ${CMAKE_CURRENT_LIST_DIR})
    include(${KCONFIG_CMAKE_DIR}/kconfig.cmake)
    include(${CMAKE_CURRENT_LIST_DIR}/component.cmake)
    include(${CMAKE_CURRENT_LIST_DIR}/utilities.cmake)
    include(${CMAKE_CURRENT_LIST_DIR}/targets.cmake)
    include(${CMAKE_CURRENT_LIST_DIR}/ldgen.cmake)
    include(${CMAKE_CURRENT_LIST_DIR}/version.cmake)

    __build_init("${idf_path}")

    set_property(GLOBAL PROPERTY __IDF_ENV_SET 1)
    message(STATUS "IDF Setup Complete")
endif()
