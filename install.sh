#!/usr/bin/env bash
# Author: rocsparse-maintainer@amd.com

#set -x #echo on

# #################################################
# helper functions
# #################################################
function display_help()
{
  echo "rocSPARSE build & installation helper script"
  echo "./install [-h|--help] "
  echo "    [-h|--help] prints this help message"
#  echo "    [--prefix] Specify an alternate CMAKE_INSTALL_PREFIX for cmake"
  echo "    [-i|--install] install after build"
  echo "    [-d|--dependencies] install build dependencies"
  echo "    [-a|--architecture] Set GPU architecture target(s), e.g., all, gfx000, gfx900, gfx906:xnack-;gfx908:xnack-"
  echo "    [-c|--clients] build library clients too (combines with -i & -d)"
  echo "    [-r]--relocatable] create a package to support relocatable ROCm"
  echo "    [-g|--debug] -DCMAKE_BUILD_TYPE=Debug (default is =Release)"
  echo "    [-k|--relwithdebinfo] -DCMAKE_BUILD_TYPE=RelWithDebInfo"
  echo "    [--hip-clang] build library for amdgpu backend using hip-clang"
  echo "    [--static] build static library"
  echo "    [--address-sanitizer] build with address sanitizer"
  echo "    [--codecoverage] build with code coverage profiling enabled"
  echo "    [--matrices-dir] existing client matrices directory"
  echo "    [--matrices-dir-install] install client matrices directory"
  echo "    [--rm-legacy-include-dir] Remove legacy include dir Packaging added for file/folder reorg backward compatibility."
}

# This function is helpful for dockerfiles that do not have sudo installed, but the default user is root
# true is a system command that completes successfully, function returns success
# prereq: ${ID} must be defined before calling
supported_distro( )
{
  if [ -z ${ID+foo} ]; then
    printf "supported_distro(): \$ID must be set\n"
    exit 2
  fi

  case "${ID}" in
    ubuntu|centos|rhel|fedora|sles|opensuse-leap)
        true
        ;;
    *)  printf "This script is currently supported on Ubuntu, CentOS, RHEL, Fedora and SLES\n"
        exit 2
        ;;
  esac
}

# checks the exit code of the last call, requires exit code to be passed in to the function
check_exit_code( )
{
  if (( $1 != 0 )); then
    exit $1
  fi
}

# This function is helpful for dockerfiles that do not have sudo installed, but the default user is root
elevate_if_not_root( )
{
  local uid=$(id -u)

  if (( ${uid} )); then
    sudo $@
    check_exit_code "$?"
  else
    $@
    check_exit_code "$?"
  fi
}

# Take an array of packages as input, and install those packages with 'apt' if they are not already installed
install_apt_packages( )
{
  package_dependencies=("$@")
  for package in "${package_dependencies[@]}"; do
    if [[ $(dpkg-query --show --showformat='${db:Status-Abbrev}\n' ${package} 2> /dev/null | grep -q "ii"; echo $?) -ne 0 ]]; then
      printf "\033[32mInstalling \033[33m${package}\033[32m from distro package manager\033[0m\n"
      elevate_if_not_root apt install -y --no-install-recommends ${package}
    fi
  done
}

# Take an array of packages as input, and install those packages with 'yum' if they are not already installed
install_yum_packages( )
{
  package_dependencies=("$@")
  for package in "${package_dependencies[@]}"; do
    if [[ $(yum list installed ${package} &> /dev/null; echo $? ) -ne 0 ]]; then
      printf "\033[32mInstalling \033[33m${package}\033[32m from distro package manager\033[0m\n"
      elevate_if_not_root yum -y --nogpgcheck install ${package}
    fi
  done
}

# Take an array of packages as input, and install those packages with 'dnf' if they are not already installed
install_dnf_packages( )
{
  package_dependencies=("$@")
  for package in "${package_dependencies[@]}"; do
    if [[ $(dnf list installed ${package} &> /dev/null; echo $? ) -ne 0 ]]; then
      printf "\033[32mInstalling \033[33m${package}\033[32m from distro package manager\033[0m\n"
      elevate_if_not_root dnf install -y ${package}
    fi
  done
}

# Take an array of packages as input, and install those packages with 'zypper' if they are not already installed
install_zypper_packages( )
{
  package_dependencies=("$@")
  for package in "${package_dependencies[@]}"; do
    if [[ $(rpm -q ${package} &> /dev/null; echo $? ) -ne 0 ]]; then
      printf "\033[32mInstalling \033[33m${package}\033[32m from distro package manager\033[0m\n"
      elevate_if_not_root zypper -n --no-gpg-checks install ${package}
    fi
  done
}

# Take an array of packages as input, and delegate the work to the appropriate distro installer
# prereq: ${ID} must be defined before calling
# prereq: ${build_clients} must be defined before calling
install_packages( )
{
  if [ -z ${ID+foo} ]; then
    printf "install_packages(): \$ID must be set\n"
    exit 2
  fi

  if [ -z ${build_clients+foo} ]; then
    printf "install_packages(): \$build_clients must be set\n"
    exit 2
  fi

  # dependencies needed for library and clients to build
  local library_dependencies_ubuntu=( "gfortran" "make" "pkg-config" "libnuma1" )
  local library_dependencies_centos=( "devtoolset-7-gcc-gfortran" "epel-release" "make" "cmake3" "gcc-c++" "rpm-build" )
  local library_dependencies_centos8=( "gcc-gfortran" "epel-release" "make" "cmake3" "gcc-c++" "rpm-build" "numactl-libs" )
  local library_dependencies_fedora=( "gcc-gfortran" "make" "cmake" "gcc-c++" "libcxx-devel" "rpm-build" "numactl-libs" )
  local library_dependencies_sles=( "gcc-fortran" "make" "cmake" "gcc-c++" "libcxxtools9" "rpm-build" )

  local client_dependencies_ubuntu=( "python3" "python3-yaml" )
  local client_dependencies_centos=( "python36" "python3-pip" )
  local client_dependencies_centos8=( "python36" "python3-pip" )
  local client_dependencies_fedora=( "python36" "PyYAML" "python3-pip" )
  local client_dependencies_sles=( "pkg-config" "dpkg" "python3-pip" )

  if [[ ( "${ID}" == "centos" ) || ( "${ID}" == "rhel" ) ]]; then
    if [[ "${VERSION_ID}" == "6" ]]; then
      library_dependencies_centos+=( "numactl" )
    else
      library_dependencies_centos+=( "numactl-libs" )
    fi
    if [[ "${VERSION_ID}" == "8" ]]; then
      client_dependencies_centos8+=( "python3-pyyaml" )
    else
      client_dependencies_centos8+=( "PyYAML" )
    fi
  fi

  case "${ID}" in
    ubuntu)
      elevate_if_not_root apt update
      install_apt_packages "${library_dependencies_ubuntu[@]}"

      if [[ "${build_clients}" == true ]]; then
        install_apt_packages "${client_dependencies_ubuntu[@]}"
      fi
      ;;

    centos|rhel)
#     yum -y update brings *all* installed packages up to date
#     without seeking user approval
#     elevate_if_not_root yum -y update
      if [[ "${VERSION_ID}" == "8" ]]; then
        install_yum_packages "${library_dependencies_centos8[@]}"
        if [[ "${build_clients}" == true ]]; then
          install_yum_packages "${client_dependencies_centos8[@]}"
          pip3 install pyyaml
        fi
      else
        install_yum_packages "${library_dependencies_centos[@]}"
        if [[ "${build_clients}" == true ]]; then
          install_yum_packages "${client_dependencies_centos[@]}"
          pip3 install pyyaml
        fi
      fi
      ;;

    fedora)
#     elevate_if_not_root dnf -y update
      install_dnf_packages "${library_dependencies_fedora[@]}"

      if [[ "${build_clients}" == true ]]; then
        install_dnf_packages "${client_dependencies_fedora[@]}"
        pip3 install pyyaml
      fi
      ;;

    sles|opensuse-leap)
#     elevate_if_not_root zypper -y update
      install_zypper_packages "${library_dependencies_sles[@]}"

      if [[ "${build_clients}" == true ]]; then
        install_zypper_packages "${client_dependencies_sles[@]}"
        pip3 install pyyaml
      fi
      ;;
    *)
      echo "This script is currently supported on Ubuntu, CentOS, RHEL and Fedora"
      exit 2
      ;;
  esac
}

# #################################################
# Pre-requisites check
# #################################################
# Exit code 0: alls well
# Exit code 1: problems with getopt
# Exit code 2: problems with supported platforms

# check if getopt command is installed
type getopt > /dev/null
if [[ $? -ne 0 ]]; then
  echo "This script uses getopt to parse arguments; try installing the util-linux package";
  exit 1
fi

# os-release file describes the system
if [[ -e "/etc/os-release" ]]; then
  source /etc/os-release
else
  echo "This script depends on the /etc/os-release file"
  exit 2
fi

# The following function exits script if an unsupported distro is detected
supported_distro

# #################################################
# global variables
# #################################################
install_package=false
install_dependencies=false
build_clients=false
build_release=true
build_hip_clang=true
build_static=false
build_release_debug=false
build_codecoverage=false
install_prefix=rocsparse-install
rocm_path=/opt/rocm
build_relocatable=false
build_address_sanitizer=false
matrices_dir=
matrices_dir_install=
gpu_architecture=all
build_freorg_bkwdcomp=true

# #################################################
# Parameter parsing
# #################################################

# check if we have a modern version of getopt that can handle whitespace and long parameters
getopt -T
if [[ $? -eq 4 ]]; then
  GETOPT_PARSE=$(getopt --name "${0}" --longoptions help,install,clients,dependencies,debug,hip-clang,static,relocatable,codecoverage,relwithdebinfo,address-sanitizer,matrices-dir:,matrices-dir-install:,architecture:,rm-legacy-include-dir --options hicdgrka: -- "$@")
else
  echo "Need a new version of getopt"
  exit 1
fi

if [[ $? -ne 0 ]]; then
  echo "getopt invocation failed; could not parse the command line";
  exit 1
fi

eval set -- "${GETOPT_PARSE}"

while true; do
    case "${1}" in
        -h|--help)
            display_help
            exit 0
            ;;
        -i|--install)
            install_package=true
            shift ;;
        -d|--dependencies)
            install_dependencies=true
            shift ;;
        -c|--clients)
            build_clients=true
            shift ;;
        -r|--relocatable)
            build_relocatable=true
            shift ;;
        -g|--debug)
            build_release=false
            shift ;;
        --hip-clang)
            build_hip_clang=true
            shift ;;
        --static)
            build_static=true
            shift ;;
        --address-sanitizer)
            build_address_sanitizer=true
            shift ;;
        -k|--relwithdebinfo)
            build_release=false
            build_release_debug=true
            shift ;;
        --codecoverage)
            build_codecoverage=true
            shift ;;
        --rm-legacy-include-dir)
            build_freorg_bkwdcomp=false
            shift ;;
        -a|--architecture)
            gpu_architecture=${2}
            shift 2 ;;
        --matrices-dir)
            matrices_dir=${2}
            if [[ "${matrices_dir}" == "" ]];then
                echo "Missing argument from command line parameter --matrices-dir; aborting"
                exit 1
            fi
            shift 2 ;;
        --matrices-dir-install)
            matrices_dir_install=${2}
            if [[ "${matrices_dir_install}" == "" ]];then
                echo "Missing argument from command line parameter --matrices-dir-install; aborting"
                exit 1
            fi
            shift 2 ;;
        --prefix)
            install_prefix=${2}
            shift 2 ;;
        --) shift ; break ;;
        *)  echo "Unexpected command line parameter received: '${1}'; aborting";
            exit 1
            ;;
    esac
done

#
# If matrices_dir_install has been set up then install matrices dir and exit.
#
if ! [[ "${matrices_dir_install}" == "" ]];then
    cmake -DCMAKE_MATRICES_DIR=${matrices_dir_install} -P ./cmake/ClientMatrices.cmake
    exit 0
fi

#
# If matrices_dir has been set up then check if it exists and it contains expected files.
# If it doesn't contain expected file, it will create them.
#
if ! [[ "${matrices_dir}" == "" ]];then
    if ! [ -e ${matrices_dir} ];then
        echo "Invalid dir from command line parameter --matrices-dir: ${matrices_dir}; aborting";
        exit 1
    fi

    # Let's 'reinstall' to the specified location to check if all good
    # Will be fast if everything already exists as expected.
    # This is to prevent any empty directory.
    cmake -DCMAKE_MATRICES_DIR=${matrices_dir} -P ./cmake/ClientMatrices.cmake
fi

build_dir=./build
printf "\033[32mCreating project build directory in: \033[33m${build_dir}\033[0m\n"

# #################################################
# prep
# #################################################
# ensure a clean build environment
if [[ "${build_release}" == true ]]; then
  rm -rf ${build_dir}/release
elif [[ "${build_release_debug}" == true ]]; then
  rm -rf ${build_dir}/release-debug
else
  rm -rf ${build_dir}/debug
fi

# Default cmake executable is called cmake
cmake_executable=cmake

case "${ID}" in
  centos|rhel)
  cmake_executable=cmake3
  ;;
esac

# If user provides custom ${rocm_path} path for hcc it has lesser priority,
# but with hip-clang existing path has lesser priority to avoid use of installed clang++
if [[ "${build_hip_clang}" == true ]]; then
  export PATH=${rocm_path}/bin:${rocm_path}/hip/bin:${rocm_path}/llvm/bin:${PATH}
fi

# #################################################
# dependencies
# #################################################
if [[ "${install_dependencies}" == true ]]; then

  install_packages

  # The following builds googletest from source, installs into cmake default /usr/local
  pushd .
    printf "\033[32mBuilding \033[33mgoogletest\033[32m from source; installing into \033[33m/usr/local\033[0m\n"
    mkdir -p ${build_dir}/deps && cd ${build_dir}/deps
    ${cmake_executable} ../../deps
    make -j$(nproc)
    elevate_if_not_root make install
  popd
fi

if [[ "${build_relocatable}" == true ]]; then
    if ! [ -z ${ROCM_PATH+x} ]; then
        rocm_path=${ROCM_PATH}
    fi

    rocm_rpath=" -Wl,--enable-new-dtags -Wl,--rpath,/opt/rocm/lib:/opt/rocm/lib64"
    if ! [ -z ${ROCM_RPATH+x} ]; then
        rocm_rpath=" -Wl,--enable-new-dtags -Wl,--rpath,${ROCM_RPATH}"
    fi
fi

# We append customary rocm path; if user provides custom rocm path in ${path}, our
# hard-coded path has lesser priority
if [[ "${build_relocatable}" == true ]]; then
    export PATH=${rocm_path}/bin:${PATH}
else
    export PATH=${PATH}:/opt/rocm/bin
fi

pushd .
  # #################################################
  # configure & build
  # #################################################
  cmake_common_options="-DAMDGPU_TARGETS=${gpu_architecture}"
  cmake_client_options=""

  # build type
  if [[ "${build_release}" == true ]]; then
    mkdir -p ${build_dir}/release/clients && cd ${build_dir}/release
    cmake_common_options="${cmake_common_options} -DCMAKE_BUILD_TYPE=Release"
  elif [[ "${build_release_debug}" == true ]]; then
    mkdir -p ${build_dir}/release-debug/clients && cd ${build_dir}/release-debug
    cmake_common_options="${cmake_common_options}  -DCMAKE_BUILD_TYPE=RelWithDebInfo"
  else
    mkdir -p ${build_dir}/debug/clients && cd ${build_dir}/debug
    cmake_common_options="${cmake_common_options} -DCMAKE_BUILD_TYPE=Debug"
  fi

  # address sanitizer
  if [[ "${build_address_sanitizer}" == true ]]; then
    cmake_common_options="${cmake_common_options} -DBUILD_ADDRESS_SANITIZER=ON"
  fi

  # freorg backward compatible support enable
  if [[ "${build_freorg_bkwdcomp}" == true ]]; then
    cmake_common_options="${cmake_common_options} -DBUILD_FILE_REORG_BACKWARD_COMPATIBILITY=ON"
  else
    cmake_common_options="${cmake_common_options} -DBUILD_FILE_REORG_BACKWARD_COMPATIBILITY=OFF"
  fi

  # code coverage
  if [[ "${build_codecoverage}" == true ]]; then
      if [[ "${build_release}" == true ]]; then
          echo "Code coverage is disabled in Release mode, to enable code coverage select either Debug mode (-g | --debug) or RelWithDebInfo mode (-k | --relwithdebinfo); aborting";
          exit 1
      fi
      cmake_common_options="${cmake_common_options} -DBUILD_CODE_COVERAGE=ON"
  fi

  # library type
  if [[ "${build_static}" == true ]]; then
    cmake_common_options="{cmake_common_options} -DBUILD_SHARED_LIBS=OFF"
  fi

  # clients
  if [[ "${build_clients}" == true ]]; then
      cmake_client_options="${cmake_client_options} -DBUILD_CLIENTS_SAMPLES=ON -DBUILD_CLIENTS_TESTS=ON -DBUILD_CLIENTS_BENCHMARKS=ON"

      #
      # Add matrices_dir if exists.
      #
      if ! [[ "${matrices_dir}" == "" ]];then
          cmake_client_options="${cmake_client_options} -DCMAKE_MATRICES_DIR=${matrices_dir}"
      fi
  fi

  compiler="hcc"
  if [[ "${build_hip_clang}" == true ]]; then
    compiler="${rocm_path}/bin/hipcc"
  fi

  if [[ "${build_clients}" == false ]]; then
    cmake_client_options=""
  fi

  # Build library with AMD toolchain because of existense of device kernels
  if [[ "${build_relocatable}" == true ]]; then
    FC=gfortran CXX=${compiler} ${cmake_executable} ${cmake_common_options} ${cmake_client_options} -DCPACK_SET_DESTDIR=OFF \
      -DCMAKE_INSTALL_PREFIX=${install_prefix} \
      -DCPACK_PACKAGING_INSTALL_PREFIX=${rocm_path} \
      -DCMAKE_SHARED_LINKER_FLAGS="${rocm_rpath}" \
      -DCMAKE_PREFIX_PATH="${rocm_path} ${rocm_path}/hcc ${rocm_path}/hip" \
      -DCMAKE_MODULE_PATH="${rocm_path}/lib/cmake/hip ${rocm_path}/hip/cmake" \
      -DROCM_DISABLE_LDCONFIG=ON \
      -DROCM_PATH="${rocm_path}" ../..
  else
    FC=gfortran CXX=${compiler} ${cmake_executable} ${cmake_common_options} ${cmake_client_options} -DCPACK_SET_DESTDIR=OFF -DCMAKE_INSTALL_PREFIX=${install_prefix} -DCPACK_PACKAGING_INSTALL_PREFIX=${rocm_path} -DROCM_PATH="${rocm_path}" ../..
  fi
  check_exit_code "$?"

  make -j$(nproc) install VERBOSE=1
  check_exit_code "$?"

  # #################################################
  # install
  # #################################################
  # installing through package manager, which makes uninstalling easy
  if [[ "${install_package}" == true ]]; then
    make package
    check_exit_code "$?"

    case "${ID}" in
      ubuntu)
        elevate_if_not_root dpkg -i rocsparse[-\_]*.deb
      ;;
      centos|rhel)
        elevate_if_not_root yum -y localinstall rocsparse-*.rpm
      ;;
      fedora)
        elevate_if_not_root dnf install rocsparse-*.rpm
      ;;
      sles|opensuse-leap)
        elevate_if_not_root zypper -n --no-gpg-checks install rocsparse-*.rpm
      ;;
    esac

  fi
popd
