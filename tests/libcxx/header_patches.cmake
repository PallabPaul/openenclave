# Copyright (c) Open Enclave SDK contributors.
# Licensed under the MIT License.

set(upstream "${LIBCXX_DIR}/libcxx/include")
set(output "${TEST_DIR}/collected")
include("${LIBCXX_DIR}/patches/series.cmake")
set(patches ${LIBCXX_HEADER_PATCHES})
set(headers)
foreach (patch IN LISTS patches)
  get_filename_component(header "${patch}" NAME_WE)
  list(APPEND headers "${header}")
  file(SHA256 "${upstream}/${header}" "source_${header}")
endforeach ()

function (prepare source patch_files expect_success)
  execute_process(
    COMMAND
      "${CMAKE_COMMAND}" "-DSOURCE_DIR=${source}" "-DOUTPUT_DIR=${output}"
      "-DCONFIG_HEADER=${LIBCXX_DIR}/__config"
      "-DGIT_EXECUTABLE=${GIT_EXECUTABLE}" "-DPATCH_FILES=${patch_files}" -P
      "${LIBCXX_DIR}/prepare_headers.cmake"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err)
  if (expect_success AND NOT result EQUAL 0)
    message(FATAL_ERROR "Header preparation failed: ${out}${err}")
  elseif (NOT expect_success)
    if (result EQUAL 0 OR NOT err MATCHES "libc\\+\\+ patch check failed")
      message(
        FATAL_ERROR "Expected an incompatible-patch failure: ${out}${err}")
    endif ()
  endif ()
endfunction ()

prepare("${upstream}" "${patches}" TRUE)
foreach (header IN LISTS headers)
  file(SHA256 "${output}/${header}" "patched_${header}")
  if ("${patched_${header}}" STREQUAL "${source_${header}}")
    message(FATAL_ERROR "Patch did not change ${header}")
  endif ()
endforeach ()

# Repeatability without modifying the checksum-verified vendor source.
prepare("${upstream}" "${patches}" TRUE)
foreach (header IN LISTS headers)
  file(SHA256 "${output}/${header}" actual)
  file(SHA256 "${upstream}/${header}" original)
  if (NOT actual STREQUAL "${patched_${header}}" OR NOT original STREQUAL
                                                    "${source_${header}}")
    message(FATAL_ERROR "Header preparation is not repeatable for ${header}")
  endif ()
endforeach ()

# Removing a patch must restore pristine output, not leave stale modifications.
prepare("${upstream}" "" TRUE)
foreach (header IN LISTS headers)
  file(SHA256 "${output}/${header}" actual)
  if (NOT actual STREQUAL "${source_${header}}")
    message(FATAL_ERROR "Stale patch left in ${header}")
  endif ()
endforeach ()
prepare("${upstream}" "${patches}" TRUE)

# An incompatible source must fail before publishing any changed headers.
file(MAKE_DIRECTORY "${TEST_DIR}/incompatible")
file(COPY "${upstream}/" DESTINATION "${TEST_DIR}/incompatible")
file(WRITE "${TEST_DIR}/incompatible/regex" "incompatible vendor revision\n")
prepare("${TEST_DIR}/incompatible" "${patches}" FALSE)
foreach (header IN LISTS headers)
  file(SHA256 "${output}/${header}" actual)
  if (NOT actual STREQUAL "${patched_${header}}")
    message(FATAL_ERROR "Failed patch changed collected ${header}")
  endif ()
endforeach ()
file(REMOVE_RECURSE "${TEST_DIR}")
