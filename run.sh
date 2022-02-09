#!/bin/bash

# ----------------------------------------------------------------------------
# UvA Programming lab development environment installer
#
# contributors:
#   * Martijn Stegeman (@stgm)
# ----------------------------------------------------------------------------



# ----------------------------------------------------------------------------
# Helper functions: thanks Homebrew! (https://github.com/Homebrew/install)
# ----------------------------------------------------------------------------

if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"
  do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

getc() {
  local save_state
  save_state="$(/bin/stty -g)"
  /bin/stty raw -echo
  IFS='' read -r -n 1 -d '' "$@"
  /bin/stty "${save_state}"
}

ring_bell() {
  # Use the shell's audible bell.
  if [[ -t 1 ]]
  then
    printf "\a"
  fi
}

wait_for_user() {
  local c
  echo
  echo "Press ${tty_bold}RETURN${tty_reset} to continue or any other key to abort:"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]
  then
    echo "You did not press ENTER so we will stop!"
    exit 1
  fi
}

# ----------------------------------------------------------------------------
# Check the operating system before continuing
# ----------------------------------------------------------------------------

OS="$(uname)"
if [[ "${OS}" == "Linux" ]]
then
  ohai "Let's install the UvA Programming Lab environment in your WSL!"
elif [[ "${OS}" == "Darwin" ]]
then
  ohai "Let's install the UvA Programming Lab environment on your Mac!"
else
  ohai "You can't use this on anything other than macOS or Linux!"
  exit 1
fi

# ----------------------------------------------------------------------------
# Install Homebrew, libmagic (for style50), libcs50 and Python on Mac
# ----------------------------------------------------------------------------

if [[ "${OS}" == "Darwin" ]]
then
  if [[ "${HOMEBREW_PREFIX}" == "" ]]
  then
    ohai "Homebrew must be installed. It is a 'package manager' that helps to install software that we need for development."
    wait_for_user
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ ($? -eq 0) ]]
    then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> .zprofile
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    echo "✅ Homebrew is installed"
  fi

  brew list -1 | grep libmagic > /dev/null
  if [[ ($? -eq 0) ]]
  then
    python_version=`python3 -V | cut -d\  -f2`
    echo "✅ libmagic is installed"
  else
    echo "❌ libmagic is not installed"
    ohai "Installing libmagic..."
    wait_for_user
    brew install libmagic
  fi

  brew list -1 | grep libcs50 > /dev/null
  if [[ ($? -eq 0) ]]
  then
    echo "✅ libcs50 is installed"
  else
    echo "❌ libcs50 is not installed"
    ohai "Installing libcs50..."
    wait_for_user
    brew install libcs50
  fi

  which python3 > /dev/null
  if [[ ($? -eq 0) ]]
  then
    python_version=`python3 -V | cut -d\  -f2`
    echo "✅ Python ${python_version} is installed"
  else
    echo "❌ Python is not installed"
    ohai "Installing Python 3 from Homebrew..."
    wait_for_user
    brew install python3
  fi

  python_path=`which python3`
  pip_path=`which pip3`
  python_dirname=`dirname ${python_path}`
  pip_dirname=`dirname ${pip_path}`
  if [[ "python_path" != "pip_path" ]]
  then
    echo "✅ Python and pip are on the same path"
  else
    echo "❌ Python and pip are on the same path"
    ohai "You will have to fix manually (ask for help!)..."
    echo ${python_path}
    echo ${pip_path}
    exit 1
  fi
fi

# ----------------------------------------------------------------------------
# Install Clang, Python and libcs50 on Linux
# ----------------------------------------------------------------------------

if [[ "${OS}" == "Linux" ]]
then
  which clang > /dev/null
  if [[ ($? -eq 0) ]]
  then
    echo "✅ clang is installed"
  else
    echo "❌ clang is not installed"
    ohai "Installing make and clang..."
    wait_for_user
    sudo apt update && sudo apt upgrade -y
    sudo apt install make clang -y
  fi

  which pip3 > /dev/null
  if [[ ($? -eq 0) ]]
  then
    python_version=`python3 -V | cut -d\  -f2`
    echo "✅ Python ${python_version} and pip are installed"
  else
    echo "❌ Python and/or pip are not installed"
    ohai "Installing Python 3 and pip..."
    wait_for_user
    sudo apt update && sudo apt upgrade -y
    sudo apt install python3-pip -y
  fi

  apt list --installed | grep libcs50
  if [[ ($? -eq 0) ]]
  then
    echo "✅ libcs50 is installed"
  else
    echo "❌ libcs50 is not installed"
    ohai "Installing libcs50..."
    wait_for_user
    curl -s https://packagecloud.io/install/repositories/cs50/repo/script.deb.sh | sudo bash
    sudo apt install libcs50
  fi

fi

# ----------------------------------------------------------------------------
# Install check50 and style50 via Pip
# ----------------------------------------------------------------------------

pip3 -q show check50 2> /dev/null
if [[ ($? -eq 0) ]]
then
  check50_version=`check50 -V | cut -d\  -f2`
  echo "✅ check50 ${check50_version} is installed"
else
  echo "❌ check50 is not installed"
  ohai "Installing check50..."
  wait_for_user
  pip3 install check50
fi

pip3 -q show style50 2> /dev/null
if [[ ($? -eq 0) ]]
then
  style50_version=`style50 -V | cut -d\  -f2`
  echo "✅ style50 ${style50_version} is installed"
else
  echo "❌ style50 is not installed"
  ohai "Installing style50..."
  wait_for_user
  pip3 install style50
fi

# ----------------------------------------------------------------------------
# Install library PATHs in the current shell's config files
#  * we prefer to install in .bashrc or .zshrc to ensure this is only applied to
#    interactive shells
# ----------------------------------------------------------------------------

# find user's default shell config
case "${SHELL}" in
  */bash*)
    if [[ -r "${HOME}/.bashrc" ]]
    then
      shell_rc="${HOME}/.bashrc"
    else
      shell_rc="${HOME}/.profile"
    fi
    ;;
  */zsh*)
    shell_rc="${HOME}/.zshrc"
    ;;
  *)
    shell_rc="${HOME}/.profile"
    ;;
esac

# echo ${shell_profile}

# check if config already contains include line
if [[ "${HOMEBREW_PREFIX}" == "/opt/homebrew" ]]
then
  cat ${shell_rc} | grep C_INCLUDE_PATH | grep -qv "^\s*#" > /dev/null
  if [[ ($? -eq 0) ]]
  then
      echo "✅ Library path is configured correctly in ${shell_rc}"
  else
      echo "❌ Library path is configured correctly in ${shell_rc}"
      ohai "Configuring library path..."
      wait_for_user
      echo "export C_INCLUDE_PATH=${HOMEBREW_PREFIX}/include" >> ${shell_rc}
      echo "export LIBRARY_PATH=${HOMEBREW_PREFIX}/lib" >> ${shell_rc}
      ohai "When done, please close your terminal window and reopen to activate!"
  fi
fi


# ----------------------------------------------------------------------------
# Create a development directory
# ----------------------------------------------------------------------------


if [[ "${OS}" == "Linux" ]]
then
  ohai "Create dir on Linux"
  crash mkdir /mnt/c/Users/.../Documents/Programming
elif [[ "${OS}" == "Darwin" ]]
then
  mac_docdir=~/Documents/Programming
  if [[ -d ${mac_docdir} ]]
  then
    echo "✅ ~/Documents/Programming exists"
  else
    echo "❌ ~/Documents/Programming exists"
    ohai "Creating ~/Documents/Programming directory"
    wait_for_user
    mkdir ~/Documents/Programming
  fi
  cd ${mac_docdir}
  if [[ -f Makefile ]]
  then
    echo "✅ Makefile is present in ~/Documents/Programming"
  else
    echo "❌ Makefile is present in ~/Documents/Programming"
    ohai "Creating Makefile in ~/Documents/Programming"
    wait_for_user
    touch Makefile
  fi
fi


# ----------------------------------------------------------------------------
# Create makefile on request
# ----------------------------------------------------------------------------


# # Makefile for CS50-type assignments
#
# INCLUDE_PATH=${HOMEBREW_PREFIX}/opt/libcs50/include
# LIBRARY_PATH=${HOMEBREW_PREFIX}/opt/libcs50/lib
#
# %: %.c
#   clang -O0 -std=c11 -Wall -Werror -Wextra -Wno-sign-compare -Wno-unused-parameter -Wno-unused-variable -Wshadow -I${INCLUDE_PATH} -o $@ $< -L${LIBRARY_PATH} -lcs50 -lcrypt -lm
