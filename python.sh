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
    echo
    echo
    echo "${tty_bold}You did not press RETURN so we will stop!${tty_reset}"
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

echo
echo "${tty_bold}Python install check${tty_reset}"

waitforit "Checking Python installation..."
python_path=`which python`
python_present=$?
if [[ $python_present -eq 0 ]]
then
  python_dirname=`dirname ${python_path}`
fi

python3_path=`which python3`
python3_present=$?
if [[ $python3_present -eq 0 ]]
then
  python3_dirname=`dirname ${python3_path}`
fi

pip3_path=`which pip3`
pip3_present=$?
if [[ $pip3_present -eq 0 ]]
then
  pip3_dirname=`dirname ${pip3_path}`
fi

pip_path=`which pip`
pip_present=$?
if [[ $pip_present -eq 0 ]]
then
  pip_dirname=`dirname $pip_path`
fi

clear_wait

echo

if [[ -n $python3_path && $(file $python3_path) = *$(uname -m)* ]]
then
  tick "Python is native for this machine"
else
  cross "Python is not native for this machine"
fi



if [[ ($python_present -eq 0) && ($python3_present -eq 0) ]]
then
  if [[ $python_dirname != $python3_dirname ]]
  then
    cross "The commands python and python3 are both present but not from the same distribution"
    echo  "  This must be fixed before you continue installing"
    echo  "  - $python3_path"
    echo  "  - $python_path"
    exit 1
  fi
  tick "The commands python and python3 are both present and from the same distribution"
  python_command=$python3_path
  python_dir=$python3_dirname
else
  if [[ ($python3_present -eq 0) ]]
  then
    tick "The command python3 is present"
    python_command=$python3_path
    python_dir=$python3_dirname
  else
    if [[ ($python_present -eq 0) ]]
    then
      tick "The command python is present"
      python_command=$python_path
      python_dir=$python_dirname
    else
      cross "No python commands are available on the system"
      echo  "Solution: install Python"
      exit 1
    fi
  fi
fi

if [[ ($pip_present -eq 0) && ($pip3_present -eq 0) ]]
then
  if [[ $pip_dirname != $pip3_dirname ]]
  then
    cross "The commands pip and pip3 are both present but not from the same distribution"
    echo  "  - $pip3_path"
    echo  "  - $pip_path"
    exit 1
  fi
  tick "The commands pip and pip3 are both present and from the same distribution"
  pip_command=$pip3_path
  pip_dir=$pip3_dirname
else
  if [[ ($pip3_present -eq 0) ]]
  then
    tick "The command pip3 is present"
    pip_command=$pip3_path
    pip_dir=$pip3_dirname
  else
    if [[ (${pip_present} -eq 0) ]]
    then
      tick "The command pip is present"
      pip_command=$pip_path
      pip_dir=$pip_dirname
    else
      cross "No pip commands are available on the system"
      exit 1
    fi
  fi
fi

echo
echo "python: $python_command"
echo "   pip: $pip_command"
echo

conda=`echo "$python_command" | grep miniconda`
if [[ $? -eq 0 ]]
then
  echo "You have installed miniconda Python. We would like to uninstall it now."
  echo "miniconda is installed in `dirname $python_dir`"
  wait_for_user
  conda init --all --reverse
  rm -r `dirname $python_dir`
fi

conda=`echo "$python_command" | grep anaconda`
if [[ $? -eq 0 ]]
then
  echo "You have installed anaconda Python. We would like to uninstall it now."
  echo "anaconda is installed in `dirname $python_dir`"
  wait_for_user
  conda init --all --reverse
  rm -rf `dirname $python_dir`
  rm /Applications/Anaconda*
fi

cd ~

if [ -d ~/anaconda* ]
then
  cross "Anaconda folder is present in ~"
  echo  "  We are now going to delete that folder"
  wait_for_user
  rm -rf ~/anaconda*
fi

if [ -d ~/miniconda3 ]
then
  cross "miniconda folder is present in ~/miniconda3"
  echo  "  We are now going to delete that folder"
  wait_for_user
  rm -rf ~/miniconda*
fi

if [ -d /opt/miniconda3 ]
then
  cross "miniconda folder is present at /opt"
  echo  "  We are now going to delete that folder"
  wait_for_user
  sudo rm -rf /opt/miniconda3
fi

conda_configured=`grep '>>> conda init >>>' .bash_profile .zshrc .tcshrc .xonshrc`
if [[ $? -eq 0 ]]
then
  cross "Anaconda is still present in shell config files"
  echo  "  We are now going to remove this shell integration"
  wait_for_user
  sed -I .anaconda_uninstalled '/^# >>> conda init[a-z]* >>>$/,/^# <<< conda init[a-z]* <<<$/d;/^# added by [A-Za-z]*conda/d' .bash_profile .zshrc .tcshrc .xonshrc
fi

if [ -h /Applications/Anaconda-Navigator.app ]
then
  cross "Anaconda Navigator is installed in the Applications folder"
  echo  "  We are now going to remove it"
  wait_for_user
  rm /Applications/Anaconda-Navigator.app
fi

# echo $python_command
pyorg=$(echo $python_command | grep "/Library/Frameworks/Python.framework")
if (( $? == 0 ))
then
  bin_dir=`dirname $python_command`
  version_dir=`dirname $bin_dir`
  versions_dir=`dirname $version_dir`
  cross "Official Python is present in $version_dir"
  echo  "  We are now going to delete that folder"
  wait_for_user

  # delete 3.10 folder
  sudo rm -rf $version_dir

  # remove symlink
  sudo rm $versions_dir/Current
fi

pyorg_configured=`grep '# Setting PATH for Python' .bash_profile .zshrc .tcshrc .xonshrc .zprofile`
if [[ $? -eq 0 ]]
then
  cross "Official Python install is still present in shell config files"
  echo  "  We are now going to remove this shell integration"
  wait_for_user
  sed -I .pyorg_uninstalled '/^# Setting PATH for Python/,/^export PATH$/d' .bash_profile .zshrc .tcshrc .xonshrc .zprofile
fi

if [ -d /Applications/Python* ]
then
  cross "Official Python apps are installed in the Applications folder"
  echo  "  We are now going to remove it"
  wait_for_user
  sudo rm -rf /Applications/Python*
fi

echo "Note: it is recommended to run this script multiple times until everything checks out!"
echo
