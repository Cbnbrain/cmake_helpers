# This file is part of Desktop App Toolkit,
# a set of libraries for developing nice desktop applications.
#
# For license and copyright information please follow this link:
# https://github.com/desktop-app/legal/blob/master/LEGAL

function(nuget_add_package package_name package package_version)
    if (NOT DEFINED NUGET_EXE_PATH)
        # Thanks https://github.com/clarkezone/flutter_win_webview/blob/master/webview_popupauth/windows/CMakeLists.txt
        find_program(NUGET_EXE NAMES nuget)
        if (NOT NUGET_EXE)
            message("NUGET.EXE not found.")
            message(FATAL_ERROR "Please install this executable, and run CMake again.")
        endif()
        set(NUGET_EXE_PATH ${NUGET_EXE} PARENT_SCOPE)
    else()
        set(NUGET_EXE ${NUGET_EXE_PATH})
    endif()

    set(package_key NUGET_${package_name}_VERSION)
    if (NOT DEFINED ${package_key})
        set(packages_loc ${CMAKE_BINARY_DIR}/packages)
        file(MAKE_DIRECTORY ${packages_loc})

        set(${package_key} ${package_version})
        execute_process(
        COMMAND
            ${NUGET_EXE}
            install
            ${package}
            -Version ${package_version}
            -ExcludeVersion
            -OutputDirectory ${packages_loc}
        )
        set(${package_name}_loc ${CMAKE_BINARY_DIR}/packages/${package} PARENT_SCOPE)
    elseif ("${${package_key}}" != ${package_version})
        message(FATAL_ERROR "Package ${package_name} requested with both ${${package_key}} and ${package_version}")
    endif()
endfunction()

function(nuget_add_webview target_name)
    nuget_add_package(webview2 "Microsoft.Web.WebView2" 1.0.864.35)

    set(webview2_loc_native ${webview2_loc}/build/native)
    # target_link_libraries(${target_name}
    # PRIVATE
    #     ${webview2_loc_native}/Microsoft.Web.WebView2.targets
    #     ${src_loc}/ForceStaticLink.targets
    # )
    #
    # This works, but just to be sure, manually link to static library.
    #
    target_include_directories(${target_name}
    PRIVATE
        ${webview2_loc_native}/include
    )
    if (build_win64)
        set(webview2_lib_folder x64)
    else()
        set(webview2_lib_folder x86)
    endif()
    target_link_libraries(${target_name}
    PRIVATE
        ${webview2_loc_native}/${webview2_lib_folder}/WebView2LoaderStatic.lib
    )

endfunction()

function(nuget_add_winrt target_name)
    nuget_add_package(winrt "Microsoft.Windows.CppWinRT" 2.0.210505.3)

    set(gen_dst ${CMAKE_BINARY_DIR}/packages/gen)
    file(MAKE_DIRECTORY ${gen_dst}/winrt)

    set(winrt_sdk_version ${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION})
    set(winrt_version_key ${gen_dst}/winrt/version_key)
    set(winrt_version_test ${winrt_version_key}_test)
    set(sdk_version_key ${gen_dst}/winrt/sdk_version_key)
    set(sdk_version_test ${sdk_version_key}_test)

    execute_process(
    COMMAND
        ${winrt_loc}/bin/cppwinrt
        /?
    OUTPUT_FILE
        ${winrt_version_test}
    )
    execute_process(
    COMMAND
        echo
        ${winrt_sdk_version}
    OUTPUT_FILE
        ${sdk_version_test}
    )
    execute_process(
    COMMAND
        ${CMAKE_COMMAND} -E compare_files ${winrt_version_key} ${winrt_version_test}
        RESULT_VARIABLE winrt_version_compare_result
    )
    execute_process(
    COMMAND
        ${CMAKE_COMMAND} -E compare_files ${sdk_version_key} ${sdk_version_test}
        RESULT_VARIABLE sdk_version_compare_result
    )
    if (winrt_version_compare_result EQUAL 0 AND sdk_version_compare_result EQUAL 0)
        message("Using existing WinRT headers.")
    else()
        message("Generating new WinRT headers.")

        execute_process(
        COMMAND
            ${winrt_loc}/bin/cppwinrt
            -input ${winrt_sdk_version}
            -output ${gen_dst}
        COMMAND
            cp ${winrt_version_test} ${winrt_version_key}
        COMMAND
            cp ${sdk_version_test} ${sdk_version_key}
        )
    endif()

    target_include_directories(${target_name}
    PRIVATE
        ${gen_dst}
    )
endfunction()
