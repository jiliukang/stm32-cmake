function(get_list_std_drivers out_list_std_drivers std_drivers_path)
    #The pattern to retrieve a driver from a file name depends on the std_driver_type field
    set(file_pattern ".+_([a-z0-9]+)\\.h$")

    #Retrieving all the .c files from std_drivers_path
    file(GLOB filtered_files
            RELATIVE "${std_drivers_path}/inc"
            "${std_drivers_path}/inc/*.h")
    # For all matched .c files keep only those with a driver name pattern (e.g. stm32xx_std_rcc.c)
    list(FILTER filtered_files INCLUDE REGEX ${file_pattern})
    # From the files names keep only the driver type part using the regex (stm32xx_std_(rcc).c or stm32xx_ll_(rcc).c => catches rcc)
    list(TRANSFORM filtered_files REPLACE ${file_pattern} "\\1")
    #Making a return by reference by seting the output variable to PARENT_SCOPE
    set(${out_list_std_drivers} ${filtered_files} PARENT_SCOPE)
endfunction()

################################################################################
# Checking the parameters provided to the find_package(STD ...) call
# The expected parameters are families and or drivers in *any orders*
# Families are valid if on the list of known families.
# Drivers are valid if on the list of valid driver of any family. For this
# reason the requested families must be processed in two steps
#  - Step 1 : Checking all the requested families
#  - Step 2 : Generating all the valid drivers from requested families
#  - Step 3 : Checking the other requested components (Expected to be drivers)
################################################################################
# Step 1 : Checking all the requested families
foreach(COMP ${StdPeriph_FIND_COMPONENTS})
    string(TOUPPER ${COMP} COMP_U)
    string(REGEX MATCH "^STM32([CFGHLMUW]P?[0-9BL])([0-9A-Z][0-9M][A-Z][0-9A-Z])?_?(M0PLUS|M4|M7)?.*$" COMP_U ${COMP_U})
    if(CMAKE_MATCH_1) #Matches the family part of the provided STM32<FAMILY>[..] component
        list(APPEND STD_FIND_COMPONENTS_FAMILIES ${COMP})
        message(TRACE "FindSTD: append COMP ${COMP} to STD_FIND_COMPONENTS_FAMILIES")
    else()
        list(APPEND STD_FIND_COMPONENTS_UNHANDLED ${COMP})
    endif()
endforeach()

# If no family requested look for all families
if(NOT STD_FIND_COMPONENTS_FAMILIES)
    set(STD_FIND_COMPONENTS_FAMILIES ${STM32_SUPPORTED_FAMILIES_LONG_NAME})
endif()

# Step 2 : Generating all the valid drivers from requested families
foreach(family_comp ${STD_FIND_COMPONENTS_FAMILIES})
    string(TOUPPER ${family_comp} family_comp)
    string(REGEX MATCH "^STM32([CFGHLMUW]P?[0-9BL])([0-9A-Z][0-9M][A-Z][0-9A-Z])?_?(M0PLUS|M4|M7)?.*$" family_comp ${family_comp})
    if(CMAKE_MATCH_1) #Matches the family part of the provided STM32<FAMILY>[..] component
        set(FAMILY ${CMAKE_MATCH_1})
        string(TOLOWER ${FAMILY} FAMILY_L)
    endif()
    find_path(STD_${FAMILY}_PATH
            NAMES inc/stm32${FAMILY_L}xx_gpio.h
            PATHS "${STM32_HAL_${FAMILY}_PATH}" "${STM32_STD_${FAMILY}_PATH}/Libraries/STM32${FAMILY}xx_StdPeriph_Driver"
            NO_DEFAULT_PATH
    )
    if(NOT STD_${FAMILY}_PATH)
        message(FATAL_ERROR "could not find STD for family ${FAMILY}")
    else()
        set(STD_${family_comp}_FOUND TRUE)
    endif()
    if(CMAKE_MATCH_1) #Matches the family part of the provided STM32<FAMILY>[..] component
        get_list_std_drivers(STD_DRIVERS_${FAMILY} ${STD_${FAMILY}_PATH})
        list(APPEND STD_DRIVERS ${STD_DRIVERS_${FAMILY}})
    else()
    endif()
endforeach()
list(REMOVE_DUPLICATES STD_DRIVERS)


# Step 3 : Checking the other requested components (Expected to be drivers)
foreach(COMP ${STD_FIND_COMPONENTS_UNHANDLED})
    string(TOLOWER ${COMP} COMP_L)

    if(${COMP_L} IN_LIST STD_DRIVERS)
        list(APPEND STD_FIND_COMPONENTS_DRIVERS ${COMP})
        message(TRACE "FindSTD: append COMP ${COMP} to STD_FIND_COMPONENTS_DRIVERS")
        continue()
    endif()
    message(FATAL_ERROR "FindSTD: unknown STD component: ${COMP}")
endforeach()

list(REMOVE_DUPLICATES STD_FIND_COMPONENTS_FAMILIES)

# when no explicit driver and driver_ll is given to find_component(STD )
# then search for all supported driver and driver_ll
if((NOT STD_FIND_COMPONENTS_DRIVERS) AND (NOT STD_FIND_COMPONENTS_DRIVERS_LL))
    set(STD_FIND_COMPONENTS_DRIVERS ${STD_DRIVERS})
    set(STD_FIND_COMPONENTS_DRIVERS_LL ${STD_LL_DRIVERS})
endif()
list(REMOVE_DUPLICATES STD_FIND_COMPONENTS_DRIVERS)
list(REMOVE_DUPLICATES STD_FIND_COMPONENTS_DRIVERS_LL)

message(STATUS "Search for STD families: ${STD_FIND_COMPONENTS_FAMILIES}")
message(STATUS "Search for STD drivers: ${STD_FIND_COMPONENTS_DRIVERS}")
message(STATUS "Search for STD LL drivers: ${STD_FIND_COMPONENTS_DRIVERS_LL}")

foreach(COMP ${STD_FIND_COMPONENTS_FAMILIES})
    string(TOUPPER ${COMP} COMP_U)

    string(REGEX MATCH "^STM32([CFGHLMUW]P?[0-9BL])([0-9A-Z][0-9M][A-Z][0-9A-Z])?_?(M0PLUS|M4|M7)?.*$" COMP_U ${COMP_U})
    if(CMAKE_MATCH_3)
        set(CORE ${CMAKE_MATCH_3})
        set(CORE_C "::${CORE}")
        set(CORE_U "_${CORE}")
    else()
        unset(CORE)
        unset(CORE_C)
        unset(CORE_U)
    endif()

    set(FAMILY ${CMAKE_MATCH_1})
    string(TOLOWER ${FAMILY} FAMILY_L)

    if((NOT STM32_STD_${FAMILY}_PATH) AND (NOT STM32_CUBE_${FAMILY}_PATH) AND (DEFINED ENV{STM32_CUBE_${FAMILY}_PATH}))
        set(STM32_CUBE_${FAMILY}_PATH $ENV{STM32_CUBE_${FAMILY}_PATH} CACHE PATH "Path to STM32Cube${FAMILY}")
        message(STATUS "ENV STM32_CUBE_${FAMILY}_PATH specified, using STM32_CUBE_${FAMILY}_PATH: ${STM32_CUBE_${FAMILY}_PATH}")
    endif()

    if((NOT STM32_STD_${FAMILY}_PATH) AND (NOT STM32_CUBE_${FAMILY}_PATH))
        set(STM32_CUBE_${FAMILY}_PATH /opt/STM32Cube${FAMILY} CACHE PATH "Path to STM32Cube${FAMILY}")
        message(STATUS "Neither STM32_CUBE_${FAMILY}_PATH nor STM32_STD_${FAMILY}_PATH specified using default STM32_CUBE_${FAMILY}_PATH: ${STM32_CUBE_${FAMILY}_PATH}")
    endif()
endforeach()
