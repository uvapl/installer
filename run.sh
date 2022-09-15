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
# Create Makefile in root development directory
# ----------------------------------------------------------------------------

create_makefile() {
  # go to the user's programming directory to perform the next parts

  programming_dir=$1
  cd "${programming_dir}"

  if [[ -f Makefile && -s Makefile ]]
  then
    tick "Makefile is present in ${programming_dir_display}"
  else
    ohai "Creating Makefile in ${programming_dir_display}"
    cat > Makefile << EOF
# Makefile for CS50-type assignments

%: %.c
	clang -O0 -std=c11 -Wall -Werror -Wextra -Wno-sign-compare -Wno-unused-parameter -Wno-unused-variable -Wshadow -o \$@ \$< -lcs50 -lm

clean:
	rm -f *.o a.out core
EOF
  fi
}

test_install() {
  if [[ -f test.c && -s test.c ]]
  then
    tick "test.c is present in ${programming_dir_display}"
  else
    ohai "Creating test.c in ${programming_dir_display}"
    cat > test.c << EOF
#include <stdio.h>
#include <cs50.h>

int main() {
    int count = get_int("");
    printf("%d", count);
}
EOF
  fi
}

# ----------------------------------------------------------------------------
# Check the operating system before continuing
# ----------------------------------------------------------------------------

OS="$(uname)"
if [[ "${OS}" == "Linux" ]] && which wslpath > /dev/null
then
  ohai "Let's install the UvA Programming Lab environment in your WSL!"
elif [[ "${OS}" == "Linux" ]]
then
  ohai "Let's install the UvA Programming Lab environment on your Chromebook Linux!"
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
# Present menu if run without command-line arguments
# ----------------------------------------------------------------------------

if [[ -z $1 ]]
then
  PS3="Select the operation: "
  select opt in install create_makefile create_testfile quit; do

    case $opt in
      install)
        break
        ;;
      create_makefile)
        create_makefile
        ;;
      create_testfile)
        test_install
        ;;
      quit)
        exit 0
        ;;
      *)
        echo "Invalid option $REPLY"
        ;;
    esac
  done
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
      cross "Some software updates are not installed, you may need to do this before continuing."
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

  install_via_brew libmagic
  install_via_brew astyle
  install_via_brew libcs50 minprog/pkg/libcs50

  # ----------- Python -----------

  waitforit "Checking Python installation..."
  python_path=`which python3`
  python_exists=$?
  clear_wait

  # python musn't be the system Python
  if [[ ($python_exists -eq 0) && $python_path != /usr/bin/* && $python_path != *Library* ]]
  then
    python_version=`python3 -V | cut -d\  -f2`
    tick "Python ${python_version} from Homebrew is installed"
  else
    cross "Python from Homebrew is not installed"
    ohai "Installing Python 3 from Homebrew..."
    wait_for_user
    brew install python3
  fi

  pip_path=`which pip3`
  python_dirname=`dirname ${python_path}`
  pip_dirname=`dirname ${pip_path}`
  if [[ ${python_dirname} == ${pip_dirname} ]]
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

  # ----------- Check software updates -----------

  # Update ubuntu packages, but only if clang is NOT already installed
  # waitforit "Checking software updates..."
  which clang > /dev/null
  if [[ ($? -ne 0) ]]
  then
    ohai "Updating Ubuntu..."
    echo "Please enter your sudo password if needed..."
    sudo true
    waitforit "Installing updates. This will take a few minutes!"
    sudo apt-get update 1> /dev/null && sudo apt-get dist-upgrade -y 1> /dev/null
    clear_wait
  fi

  waitforit "Checking installed packages..."
  dpkg -s make clang astyle unzip &> /dev/null
  result=$?
  clear_wait

  if [[ ($result -eq 0) ]]
  then
    tick "clang is installed"
  else
    cross "clang is not installed"
    ohai "Installing make and clang..."
    wait_for_user
    sudo apt-get install make clang astyle unzip -y
  fi

  if which python3 > /dev/null && which pip3 > /dev/null
  then
    python_version=`python3 -V | cut -d\  -f2`
    tick "Python ${python_version} and pip are installed"
  else
    cross "Python and/or pip are not installed"
    ohai "Installing Python 3 and pip..."
    wait_for_user
    sudo apt-get install python3-pip -y
  fi

  # hardcoded likely install path for libcs50
  if [[ -f /usr/local/include/cs50.h || -f /usr/include/cs50.h ]]
  then
    tick "libcs50 is installed"
  else
    cross "libcs50 is not installed"
    ohai "Installing libcs50..."
    wait_for_user
    tmpdir=$(mktemp -dq /tmp/libcs50-XXXXXXXX)
    if [[ $? -ne 0 ]]
    then
      echo "Could not create temp dir $tmpdir"
      exit 1
    else
      curl -Lo $tmpdir/libcs50.zip $(curl -s https://api.github.com/repos/cs50/libcs50/releases/latest | grep 'zipball_url' | cut -d\" -f4)
      unzip -d $tmpdir $tmpdir/libcs50.zip
      unzipped_dir=$(unzip -l $tmpdir/libcs50.zip | grep Makefile | tr -s ' ' | cut -d\  -f 5 | cut -d/ -f 1)
      make -C $tmpdir/$unzipped_dir || exit 1
      sudo make -C $tmpdir/$unzipped_dir install
    fi
  fi

fi

# ----------------------------------------------------------------------------
# Install check50 and style50 via Pip
# ----------------------------------------------------------------------------

waitforit "Updating pip..."
pip3 install --upgrade pip &> /dev/null
clear_wait

install_via_pip () {
  command_to_install=$1

  waitforit "Checking ${command_to_install} installation..."
  pip3 -q show ${command_to_install} 2> /dev/null
  install_result=$?
  clear_wait

  if [[ (${install_result} -eq 0) ]]
  then
    tick "${command_to_install} is installed"
  else
    cross "${command_to_install} is not installed"
    ohai "Installing ${command_to_install}..."
    wait_for_user
    # install while removing irrelevant output
    pip3 install ${command_to_install} -U 2>&1 | grep -Ev "(DEPRECATION|satisfied)"
  fi
  
  # try to run it, catch error to see if reinstall might be needed
  $command_to_install 2>&1 | grep ModuleNotFoundError > /dev/null
  if (($? == 0))
  then
    cross "It seems that $command_to_install doesn't work"
    echo "Trying to re-install"
    wait_for_user
    pip3 install $command_to_install --force-reinstall -U 2>&1 | grep -Ev "(DEPRECATION|satisfied)"
  fi
}

install_via_pip check50
install_via_pip style50

# ----------------------------------------------------------------------------
# Choose Nano for ad-hoc editing in the shell (like with git commit messages)
# ----------------------------------------------------------------------------

# check if shellrc already contains editor config
touch ${shell_rc}
cat ${shell_rc} | grep EDITOR | grep -qv "^\s*#" > /dev/null
if [[ ($? -eq 0) ]]
then
    tick "Editor path is configured correctly in ${shell_rc/$HOME/~}"
else
    cross "Editor path is not configured correctly in ${shell_rc/$HOME/~}"
    ohai "Configuring editor path..."
    wait_for_user
    echo -e "\nexport EDITOR=nano" >> ${shell_rc}
fi

waitforit "Patching check50..."

# on WSL, check if check50 shell function override is defined
if [[ "$OS" == "Linux" ]] && which wslpath > /dev/null
then
  sed -i.check50_hack '/^function check50/,/^}$/d' $shell_rc
  cat >> $shell_rc <<-"EOF"
function check50 ()
{
  check50_cmd=$(which check50)
  output=$($check50_cmd -l $* | sed '\$s/file:\/\//\\\\\\\\wsl\\\\\$\\\\Ubuntu/;\$s/\\//\\\\/g')
  echo "${output}"
}
EOF
fi

clear_wait

# ----------------------------------------------------------------------------
# Create a development directory
# ----------------------------------------------------------------------------

if [[ "$OS" == "Linux" ]] && which wslpath > /dev/null
then
  homedir=$(wslpath "$(wslvar USERPROFILE)")
  # construct full path to programming dir
  programming_dir="${homedir}/Documents/Programming"
  # replace expanded homedir by ~ again for display purposes
  programming_dir_display="$programming_dir"
else
  # Note: ~ is automatically expanded here which is not nice for display
  homedir=~
  # construct full path to programming dir
  programming_dir="${homedir}/Documents/Programming"
  # replace expanded homedir by ~ again for display purposes
  programming_dir_display="${programming_dir/$homedir/~}"
fi

if [[ -d $programming_dir ]]
then
  # print path using ~ to enhance usability
  tick "$programming_dir_display exists"
else
  cross "$programming_dir_display does not exist"
  ohai "Creating $programming_dir_display directory"
  wait_for_user
  mkdir -p "$programming_dir"
fi

create_makefile "$programming_dir"
