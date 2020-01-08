if(NOT IDF_PATH)
    message(FATAL_ERROR "IDF_PATH not set.")
endif()

if( ESP_CMAKE_TOOL_DIR AND EXISTS ${ESP_CMAKE_TOOL_DIR})
    include("${ESP_CMAKE_TOOL_DIR}/utilities.cmake")
else()
    include("${IDF_PATH}/tools/cmake/utilities.cmake")
endif()
spaces2list(CMD)

execute_process(COMMAND ${CMD}
    WORKING_DIRECTORY "${WORKING_DIRECTORY}"
    RESULT_VARIABLE result
    )

if(${result})
    # No way to have CMake silently fail, unfortunately
    message(FATAL_ERROR "${TOOL} failed")
endif()
