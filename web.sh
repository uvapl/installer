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
  start_spinner
}

clear_wait() {
  stop_spinner
  echo -ne "\033[1K"
  printf "\r"
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
    echo "\nYou did not press RETURN so we will stop!"
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
            sp='*+x'
            delay=${SPINNER_DELAY:-0.15}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${2} ]]; then
                echo ""
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
    trap 'stop_spinner; wait' SIGINT
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
if [[ "${OS}" =~ "^MINGW" ]]
then
  ohai "Let's install some tools in your Git Bash!"
elif [[ "${OS}" == "Darwin" ]]
then
  ohai "Let's install some development tools on your Mac!"
else
  ohai "You can't use this on anything other than either macOS or Git Bash!"
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
# Find user's default shell config and save in shell_rc variable
# ----------------------------------------------------------------------------

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

# ----------------------------------------------------------------------------
# Install Homebrew, libmagic (for style50), libcs50 and Python on Mac
# ----------------------------------------------------------------------------

if [[ "${OS}" == "Darwin" ]]
then

  # ----------- Check software updates -----------

  if [[ -z $1 ]] # skip if any command line parameter is present
  then
    waitforit "Checking software updates...  "
    no_sw_updates=`softwareupdate -l 2>&1 | grep "No new software available."`
    clear_wait
    if [[ -n $no_sw_updates ]]
    then
      tick "All software updates installed"
    else
      cross "Some system updates are not installed, please do this before continuing."
      wait_for_user
    fi
  fi

  # ----------- Homebrew -----------

  # Let Homebrew complainbrag less
  export HOMEBREW_NO_ENV_HINTS=true

  waitforit "Checking Homebrew installation..."

  # after macOS upgrades, command line developer tools will be missing
  # we then defer to Homebrew to install it
  xcrun --version &> /dev/null
  xcrun_ok=$?

  # check for Homebrew itself
  which brew &> /dev/null
  which_brew_ok=$?

  clear_wait

  # install homebrew and use it to install the command line tools, too
  if [[ $xcrun_ok -eq 0 && $which_brew_ok -eq 0 ]]
  then
    homebrew_version=`brew -v | cut -d\  -f2 | head -1`
    tick "Homebrew ${homebrew_version} is installed"
  else
    ohai "Homebrew must be installed. It is a 'package manager' that helps install software for development."
    wait_for_user
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ ($? -ne 0) ]]
    then
      echo 'Homebrew install failed. Please ask for help!'
      exit 1
    fi
  fi

  # double check if Homebrew is actually functioning
  brew_diagnostics=`brew tap-info homebrew/core 2>&1`
  if [[ $brew_diagnostics =~ (no commands|Not installed) ]]
  then
    ohai "Homebrew seems to be misconfigured. Shall we try to repair it?"
    wait_for_user
    rm -rf $(brew --prefix)/Library/Taps/homebrew/homebrew-core
    brew tap homebrew/core
    brew_diagnostics=`brew tap-info homebrew/core 2>&1`
    if [[ $brew_diagnostics =~ (no commands|Not installed) ]]
    then
      ohai "Homebrew STILL seems to be misconfigured. Shall we try to repair it by reinstalling?"
      wait_for_user
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      if [[ ($? -ne 0) ]]
      then
        echo 'Homebrew install failed. Please ask for help!'
        exit 1
      fi
    fi
  fi

  # ----------------------------------------------------------------------------
  # For Homebrew on M1 Macs, where everything is installed into /opt
  # ----------------------------------------------------------------------------

  # Based on the `brew` command being in /opt we assume that this is it
  if [[ -f "/opt/homebrew/bin/brew" ]]
  then
    waitforit "Checking Homebrew install on M1/2 mac..."
    # add homebrew to shell profile because /opt is not on the default path
    homebrew_in_zprofile=$(grep "/opt/homebrew/bin/brew" ~/.zprofile 2> /dev/null | grep -v "^\s*#")
    homebrew_in_zshrc=$(grep "/opt/homebrew/bin/brew" ~/.zshrc 2> /dev/null | grep -v "^\s*#")
    if [[ (-z $homebrew_in_zprofile) && (-z $homebrew_in_zshrc) ]]
    then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
      # also add the environment to the current shell so we can use homebrew to install
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    clear_wait
    tick "Homebrew is in /opt/homebrew and configured correctly"

    # Install library PATHs in the current shell's config files
    #  * we prefer to install in .bashrc or .zshrc to ensure this is only applied to
    #    interactive shells
    include_path_in_shrc=$(grep "C_INCLUDE_PATH" ${shell_rc} 2> /dev/null | grep -v "^\s*#")
    if [[ ! -z $include_path_in_shrc ]]
    then
      tick "Library path is configured correctly in ${shell_rc/$HOME/~}"
    else
      cross "Library path is not configured correctly in ${shell_rc/$HOME/~}"
      ohai "Configuring library path..."
      wait_for_user
      echo -e "\nexport C_INCLUDE_PATH=${HOMEBREW_PREFIX}/include" >> ${shell_rc}
      echo "export LIBRARY_PATH=${HOMEBREW_PREFIX}/lib" >> ${shell_rc}
      ohai "When done, please close your terminal window and reopen to activate!"
    fi
  fi

  install_via_brew () {
    command_to_install=$1
    package_path=$2

    waitforit "Checking ${command_to_install} installation..."
    brew list -1 | grep ${command_to_install} > /dev/null
    result=$?
    clear_wait

    if [[ ($result -eq 0) ]]
    then
      tick "${command_to_install} is installed"
    else
      cross "${command_to_install} is not installed"
      wait_for_user
      ohai "Installing ${command_to_install}..."
      brew install ${package_path:-$command_to_install}
    fi
  }

  install_via_brew pup

fi

# ----------------------------------------------------------------------------
# Install on Git Bash
# ----------------------------------------------------------------------------

if [[ "${OS}" =~ "^MINGW" ]]
then

  mkdir -p bin
  mkdir -p tmp
  cd tmp

  echo "- pup for scraping web pages"
  curl -LOs https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_windows_386.zip
  unzip pup_v0.4.0_windows_386.zip
  mv pup.exe ~/bin
  
  echo "- sqlite tools for database access"
  curl -LOs https://www.sqlite.org/2022/sqlite-tools-win32-x86-3400100.zip
  unzip sqlite-tools-win32-x86-3400100.zip
  mv sqlite-tools-win32-x86-3400100/* ~/bin

fi

echo
echo "Note: it is recommended to run this script multiple times until everything checks out."
echo "When everything seems in order, you may need to close and re-open the terminal."
echo
