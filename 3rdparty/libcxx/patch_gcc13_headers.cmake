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

# Replace exactly one known upstream fragment, allowing incremental reruns.
function (patch_header name before after)
  set(path "${header_dir}/${name}")
  file(READ "${path}" text)
  string(FIND "${text}" "${before}" old_position)
  string(FIND "${text}" "${after}" new_position)
  if (old_position GREATER_EQUAL 0 AND new_position EQUAL -1)
    string(REPLACE "${before}" "" remainder "${text}")
    string(LENGTH "${text}" original_length)
    string(LENGTH "${remainder}" remaining_length)
    string(LENGTH "${before}" fragment_length)
    math(EXPR removed_length "${original_length} - ${remaining_length}")
    if (NOT removed_length EQUAL fragment_length)
      message(
        FATAL_ERROR "Ambiguous libc++ ${name} patch; review source revision")
    endif ()
    string(REPLACE "${before}" "${after}" text "${text}")
    file(WRITE "${path}" "${text}")
  elseif (NOT old_position EQUAL -1 OR new_position EQUAL -1)
    message(
      FATAL_ERROR "Unexpected libc++ ${name} revision; review GCC 13 patch")
  endif ()
endfunction ()

get_filename_component(header_dir "${HEADER}" DIRECTORY)

# Moving the initial regex state must not read an indeterminate bool.
patch_header(regex "          __node_(nullptr), __flags_() {}"
             "          __node_(nullptr), __flags_(), __at_first_(false) {}")

# Match the input-iterator overload: initialize the string representation
# before querying max_size() on the partially constructed object. The allocator
# is already constructed and is not modified by __zero().
patch_header(
  string
  [=[basic_string<_CharT, _Traits, _Allocator>::__init(_ForwardIterator __first, _ForwardIterator __last)
{
    size_type __sz]=]
  [=[basic_string<_CharT, _Traits, _Allocator>::__init(_ForwardIterator __first, _ForwardIterator __last)
{
    __zero();
    size_type __sz]=])

# Make the null case explicit before dispatching to either storage variant.
patch_header(
  functional
  [=[    ~__value_func()
    {
        if ((void*)__f_ == &__buf_)
            __f_->destroy();
        else if (__f_)
            __f_->destroy_deallocate();
    }]=]
  [=[    ~__value_func()
    {
        if (!__f_)
            return;
        if ((void*)__f_ == &__buf_)
            __f_->destroy();
        else
            __f_->destroy_deallocate();
    }]=])
