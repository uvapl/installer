#!/bin/bash

# ----------------------------------------------------------------------------
# UvA Programming lab development environment installer
#
# contributors:
#   * Martijn Stegeman (@stgm)
#   * Marijn Doeve (@TheRijn)
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
tty_green="$(tty_mkbold 32)"
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
  tick="${tty_green}v${tty_reset}"
  cross="${tty_red}x${tty_reset}"
elif [[ "${OS}" == "Darwin" ]]
then
  ohai "Let's install the UvA Programming Lab environment on your Mac!"
  tick="✅"
  cross="❌"
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
    echo "❌ Python and pip are not on the same path"
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
  ohai "Updating Ubuntu..."
  wait_for_user
  echo "This may take a few minutes..."
  sudo apt-get update 1> /dev/null && sudo apt-get upgrade -y 1> /dev/null

  which clang > /dev/null
  if [[ ($? -eq 0) ]]
  then
    echo "${tick} clang is installed"
  else
    echo "${cross} clang is not installed"
    ohai "Installing make and clang..."
    wait_for_user
    sudo apt-get install make clang -y
  fi

  which pip3 > /dev/null
  if [[ ($? -eq 0) ]]
  then
    python_version=`python3 -V | cut -d\  -f2`
    echo "${tick} Python ${python_version} and pip are installed"
  else
    echo "${cross} Python and/or pip are not installed"
    ohai "Installing Python 3 and pip..."
    wait_for_user
    sudo apt-get install python3-pip -y
  fi

  dpkg --list | grep libcs50 > /dev/null
  if [[ ($? -eq 0) ]]
  then
    echo "${tick} libcs50 is installed"
  else
    echo "${cross} libcs50 is not installed"
    ohai "Installing libcs50..."
    wait_for_user
    curl -s https://packagecloud.io/install/repositories/cs50/repo/script.deb.sh | sudo bash
    sudo apt-get install libcs50 -y
  fi

fi

# ----------------------------------------------------------------------------
# Install check50 and style50 via Pip
# ----------------------------------------------------------------------------

pip3 -q show check50 2> /dev/null
if [[ ($? -eq 0) ]]
then
  check50_version=`check50 -V | cut -d\  -f2`
  echo "${tick} check50 ${check50_version} is installed"
else
  echo "${cross} check50 is not installed"
  ohai "Installing check50..."
  wait_for_user
  pip3 install check50
fi

pip3 -q show style50 2> /dev/null
if [[ ($? -eq 0) ]]
then
  style50_version=`style50 -V | cut -d\  -f2`
  echo "${tick} style50 ${style50_version} is installed"
else
  echo "${cross} style50 is not installed"
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
      echo "❌ Library path is not configured correctly in ${shell_rc}"
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
  homedir=`wslpath "$(wslvar USERPROFILE)"`
  docdir="${homedir}/Documents/Programming"
elif [[ "${OS}" == "Darwin" ]]
then
  docdir=~/Documents/Programming
fi
if [[ -d ${docdir} ]]
then
  echo "${tick} ${docdir} exists"
else
  echo "${cross} ${docdir} does not exist"
  ohai "Creating ${docdir} directory"
  wait_for_user
  mkdir ${docdir}
fi

# ----------------------------------------------------------------------------
# Create Makefile in root development directory
# ----------------------------------------------------------------------------

cd ${docdir}
if [[ -f Makefile && -s Makefile ]]
then
  echo "${tick} Makefile is present in ${docdir}"
else
  echo "${cross} Makefile is not present in ${docdir}"
  ohai "Creating Makefile in ${docdir}"
  wait_for_user
  cat > Makefile << EOF
# Makefile for CS50-type assignments

%: %.c
	clang -O0 -std=c11 -Wall -Werror -Wextra -Wno-sign-compare -Wno-unused-parameter -Wno-unused-variable -Wshadow -o \$@ \$< -lcs50 -lm

clean:
	rm -f *.o a.out core
EOF
fi
