set(regalloc_flags "-mllvm=-regalloc=pbqb -Wno-unused-command-line-argument")
set(OPTFLAGS "${OPTFLAGS} -O3 -fomit-frame-pointer -DNDEBUG")

set(CMAKE_C_FLAGS_RELEASE "${OPTFLAGS} ${regalloc_flags}" CACHE STRING "")
set(CMAKE_CXX_FLAGS_RELEASE "${OPTFLAGS} ${regalloc_flags}" CACHE STRING "")
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "")
