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

waitforit() {
  printf "${tty_bold}%s${tty_reset}" "$(shell_join "$@")"
}

bold() {
  printf "${tty_bold}%s${tty_reset}\n" "$(shell_join "$@")"
}

tick() {
  printf "${tty_green}v${tty_reset} %s\n" "$(shell_join "$@")"
}

cross() {
  printf "${tty_red}x${tty_reset} %s\n" "$(shell_join "$@")"
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
  echo -n "Press ${tty_bold}RETURN${tty_reset} to continue install or any other key to abort:"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]
  then
    echo "You did not press RETURN so we will stop!"
    exit 1
  fi
  echo
}

# ----------------------------------------------------------------------------
# Spinner https://github.com/tlatsas/bash-spinner
# ----------------------------------------------------------------------------

function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="DONE"
    local on_fail="FAIL"
    local white="\033[1;37m"
    local green="\033[1;32m"
    local red="\033[1;31m"
    local nc="\033[0m"

    case $1 in
        start)
            # start spinner
            i=1
            sp='\|/-'
            delay=${SPINNER_DELAY:-0.15}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${2} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $2 > /dev/null 2>&1

            # backspace spinner
            echo -en "\b"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner {
    # $1 : msg to display
    _spinner "start" &
    # set global spinner pid
    _sp_pid=$!
    disown
}

function stop_spinner {
    # $1 : command exit status
    _spinner "stop" $_sp_pid
    unset _sp_pid
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
# Check that user is not root before continuing
# ----------------------------------------------------------------------------

user_name=`whoami`
if [[ "${user_name}" == "root" ]]
then
  if [[ "${OS}" == "Linux" ]]
  then
    echo "If running WSL on Windows, please reset your install as per https://askubuntu.com/a/1082091"
    echo "Then restart Ubuntu and create a new user, and run this script again."
    exit 1
  elif [[ "${OS}" == "Darwin" ]]
  then
    echo "Please do not run this script using sudo!"
    exit 1
  fi
fi

# ----------------------------------------------------------------------------
# Install Homebrew, libmagic (for style50), libcs50 and Python on Mac
# ----------------------------------------------------------------------------

if [[ "${OS}" == "Darwin" ]]
then
  waitforit "Checking software updates..."
  start_spinner
  no_sw_updates=`softwareupdate -l 2>&1 | grep "No new software available." | wc -l`
  stop_spinner
  echo -ne "\033[1K"
  printf "\r"
  if [[ "${no_sw_updates}" == "       1" ]]
  then
    tick "All software updates installed"
  else
    cross "Some software updates are not installed, you may need to do this before continuing."
    wait_for_user
  fi

  # Let Homebrew complainbrag less
  export HOMEBREW_NO_ENV_HINTS=true

  ohai "Checking Homebrew installation..."
  which brew > /dev/null
  if [[ ($? -eq 0) ]]
  then
    homebrew_version=`brew -v | cut -d\  -f2 | head -1`
    tick "Homebrew ${homebrew_version} is installed"
  else
    ohai "Homebrew must be installed. It is a 'package manager' that helps to install software that we need for development."
    wait_for_user
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ ($? -eq 0) ]]
    then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> .zprofile
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi

  ohai "Checking libmagic..."
  brew list -1 | grep libmagic > /dev/null
  if [[ ($? -eq 0) ]]
  then
    python_version=`python3 -V | cut -d\  -f2`
    tick "libmagic is installed"
  else
    cross "libmagic is not installed"
    wait_for_user
    ohai "Installing libmagic..."
    brew install libmagic
  fi

  ohai "Checking libcs50..."
  brew list -1 | grep libcs50 > /dev/null
  if [[ ($? -eq 0) ]]
  then
    tick "libcs50 is installed"
  else
    cross "libcs50 is not installed"
    ohai "Installing libcs50..."
    wait_for_user
    brew install minprog/pkg/libcs50
  fi

  ohai "Checking Python installation..."
  which python3 > /dev/null
  if [[ ($? -eq 0) ]]
  then
    python_version=`python3 -V | cut -d\  -f2`
    tick "Python ${python_version} is installed"
  else
    cross "Python is not installed"
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
    tick "Python and pip are on the same path"
  else
    cross "Python and pip are not on the same path"
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

  # Update ubuntu packages, but only if clang is NOT already installed
  ohai "Checking software updates..."
  which clang > /dev/null
  if [[ ($? -ne 0) ]]
  then
    ohai "Updating Ubuntu..."
    echo "Please enter your sudo password if needed..."
    sudo true
    echo "Installing updates. This will take a few minutes!"
    sudo apt-get update 1> /dev/null && sudo apt-get upgrade -y 1> /dev/null
  fi

  ohai "Checking installed packages..."

  dpkg -s make clang astyle &> /dev/null
  if [[ ($? -eq 0) ]]
  then
    tick "clang is installed"
  else
    cross "clang is not installed"
    ohai "Installing make and clang..."
    wait_for_user
    sudo apt-get install make clang astyle -y
  fi

  which pip3 > /dev/null
  if [[ ($? -eq 0) ]]
  then
    python_version=`python3 -V | cut -d\  -f2`
    tick "Python ${python_version} and pip are installed"
  else
    cross "Python and/or pip are not installed"
    ohai "Installing Python 3 and pip..."
    wait_for_user
    sudo apt-get install python3-pip -y
  fi

  dpkg -s libcs50 &> /dev/null
  if [[ ($? -eq 0) ]]
  then
    tick "libcs50 is installed"
  else
    cross "libcs50 is not installed"
    ohai "Installing libcs50..."
    wait_for_user
    curl -s https://packagecloud.io/install/repositories/cs50/repo/script.deb.sh | sudo bash
    sudo apt-get install libcs50 -y
  fi

fi

# ----------------------------------------------------------------------------
# Install check50 and style50 via Pip
# ----------------------------------------------------------------------------

ohai "Checking check50 and style50 installation..."
pip3 -q show check50 2> /dev/null
if [[ ($? -eq 0) ]]
then
  check50_version=`check50 -V | cut -d\  -f2`
  tick "check50 ${check50_version} is installed"
else
  cross "check50 is not installed"
  ohai "Installing check50..."
  wait_for_user
  pip3 install check50 2>&1 | grep -Ev "(DEPRECATION|satisfied)"
fi

pip3 -q show style50 2> /dev/null
if [[ ($? -eq 0) ]]
then
  style50_version=`style50 -V | cut -d\  -f2`
  tick "style50 ${style50_version} is installed"
else
  cross "style50 is not installed"
  ohai "Installing style50..."
  wait_for_user
  pip3 install style50 2>&1 | grep -Ev "(DEPRECATION|satisfied)"
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

# check if config already contains include line
ohai "Checking configuration..."
if [[ "${HOMEBREW_PREFIX}" == "/opt/homebrew" ]]
then
  cat ${shell_rc} | grep C_INCLUDE_PATH | grep -qv "^\s*#" > /dev/null
  if [[ ($? -eq 0) ]]
  then
      tick "Library path is configured correctly in ${shell_rc/$HOME/~}"
  else
      cross "Library path is not configured correctly in ${shell_rc/$HOME/~}"
      ohai "Configuring library path..."
      wait_for_user
      echo "export C_INCLUDE_PATH=${HOMEBREW_PREFIX}/include" >> ${shell_rc}
      echo "export LIBRARY_PATH=${HOMEBREW_PREFIX}/lib" >> ${shell_rc}
      ohai "When done, please close your terminal window and reopen to activate!"
  fi
fi

# check if config already contains include line
cat ${shell_rc} | grep EDITOR | grep -qv "^\s*#" > /dev/null
if [[ ($? -eq 0) ]]
then
    tick "Editor path is configured correctly in ${shell_rc/$HOME/~}"
else
    cross "Editor path is not configured correctly in ${shell_rc/$HOME/~}"
    ohai "Configuring editor path..."
    wait_for_user
    echo "export EDITOR=nano" >> ${shell_rc}
fi

# ----------------------------------------------------------------------------
# Create a development directory
# ----------------------------------------------------------------------------

if [[ "${OS}" == "Linux" ]]
then
  homedir=`wslpath "$(wslvar USERPROFILE)"`
elif [[ "${OS}" == "Darwin" ]]
then
  # ~ is automatically expanded here
  homedir=~
fi
programming_dir="${homedir}/Documents/Programming"
programming_dir_display="${programming_dir/$HOME/~}"

if [[ -d ${programming_dir} ]]
then
  # print path using ~ to enhance usability
  tick "${programming_dir_display} exists"
else
  cross "${programming_dir_display} does not exist"
  ohai "Creating ${programming_dir_display} directory"
  wait_for_user
  mkdir ${programming_dir}
fi

# ----------------------------------------------------------------------------
# Create Makefile in root development directory
# ----------------------------------------------------------------------------

cd ${programming_dir}
if [[ -f Makefile && -s Makefile ]]
then
  tick "Makefile is present in ${programming_dir_display}"
else
  cross "Makefile is not present in ${programming_dir_display}"
  ohai "Creating Makefile in ${programming_dir_display}"
  wait_for_user
  cat > Makefile << EOF
# Makefile for CS50-type assignments

%: %.c
	clang -O0 -std=c11 -Wall -Werror -Wextra -Wno-sign-compare -Wno-unused-parameter -Wno-unused-variable -Wshadow -o \$@ \$< -lcs50 -lm

clean:
	rm -f *.o a.out core
EOF
fi

ohai "Everything's done now!"
