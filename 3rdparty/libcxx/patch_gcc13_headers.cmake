# Copyright (c) Open Enclave SDK contributors.
# Licensed under the MIT License.

# GCC 13 recognizes __is_convertible as a builtin. libc++ 10's fallback
# template uses that same spelling. Rename only the internal template, not
# the public is_convertible trait or Clang's __is_convertible_to builtin.
file(READ "${HEADER}" contents)
string(REGEX MATCHALL "__is_convertible[< \r\n]" matches "${contents}")
list(LENGTH matches count)
if (count EQUAL 14)
  string(REGEX REPLACE "__is_convertible([< \r\n])"
                       "__oe_is_convertible_fallback\\1" contents "${contents}")
  file(WRITE "${HEADER}" "${contents}")
elseif (count EQUAL 0)
  string(REGEX MATCHALL "__oe_is_convertible_fallback[< \r\n]" matches
               "${contents}")
  list(LENGTH matches patched_count)
  if (NOT patched_count EQUAL 14)
    message(
      FATAL_ERROR
        "Unexpected libc++ type_traits revision; review GCC 13 compatibility patch"
    )
  endif ()
else ()
  message(
    FATAL_ERROR "Expected 14 libc++ __is_convertible references; found ${count}"
  )
endif ()
