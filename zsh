#!/bin/sh
# Copyright 2024 tah5.com. MIT license.
# shellcheck disable=SC3043 # In POSIX sh, 'local' is undefined.
# sh -c "$(curl -fsSL https://tah5.com/s/zsh)" -- [OPTIONS]

set -o errexit
set -o nounset

SCRIPT_NAME="zsh"
readonly SCRIPT_NAME
SCRIPT_DESCRIPTION="Installs Zsh, a powerful shell for interactive use."
readonly SCRIPT_DESCRIPTION
SCRIPT_VERSION="1.4.0 (2024-09-16)"
readonly SCRIPT_VERSION
SCRIPT_CATEGORY="System"
# shellcheck disable=SC2034 # Unused variable.
readonly SCRIPT_CATEGORY
SUPPORTED_ARCHS="x86_64 amd64 arm64 aarch64"
readonly SUPPORTED_ARCHS
SUPPORTED_PLATFORMS="linux"
readonly SUPPORTED_PLATFORMS

# Define 'local' if not available
ensure_local() {
    local _has_local
}
ensure_local 2>/dev/null || alias local=typeset

# Display usage message
display_usage() {
    cat <<HELPMSG
${SCRIPT_NAME} ${SCRIPT_VERSION}

${SCRIPT_DESCRIPTION}

Usage: ${SCRIPT_NAME} [options]

OPTIONS:
  -a, --add-aliases
          Add aliases to the zshrc file
  -h, --help
          Print help
  -p, --powerlevel
          Install Powerlevel10k theme with Nerd Fonts
  -v, --version
          Print version
HELPMSG
}

# Convert input to lowercase
convert_to_lowercase() {
    tr '[:upper:]' '[:lower:]'
}

# Get the kernel name in lowercase
get_kernel_name() {
    uname -s | convert_to_lowercase
}

# Get the machine hardware name in lowercase
get_hardware_name() {
    uname -m | convert_to_lowercase
}

# Check if the output is a terminal
is_terminal() {
    [ -t 1 ]
}

# Set terminal color if output is a terminal
if is_terminal; then
    set_terminal_color() {
        printf "\033[%s;%sm" "$1" "$2"
    }
else
    set_terminal_color() {
        :
    }
fi

# Apply terminal color
apply_color() {
    set_terminal_color "$1" "$2"
}

bold_red="$(apply_color 1 31)"
readonly bold_red
reset_color="$(apply_color 0 0)"
readonly reset_color

# Print informational message
print_info() {
    printf "%s\n" "${*}"
}

# Print error message and exit
print_error() {
    printf "${bold_red}ERROR${reset_color}: %s\n" "${*}" >&2
    exit 1
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect the package manager
detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists apk; then
        echo "apk"
    else
        print_error "Unsupported package manager. This script supports only Ubuntu (apt) and Alpine (apk)."
    fi
}

# Check if a package exists
package_exists() {
    case "$(detect_package_manager)" in
    apt)
        dpkg-query -W -f='${Status}' "$1" 2>/dev/null
        ;;
    apk)
        apk info -e "$1" >/dev/null 2>&1
        ;;
    esac
}

# Ensure a command is available
require_command() {
    if ! command_exists "$1"; then
        print_error "need '$1' (command not found)"
    fi
}

# Check if the script is running as root
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Run a command and exit if it fails
run_command() {
    if ! "$@"; then print_error "command failed: $*"; fi
}

# Run a command as root or with sudo
if is_root; then
    run_command_as_root() {
        run_command "$@"
    }
else
    run_command_as_root() {
        run_command sudo "$@"
    }
fi

# Main function
main() {
    local _platform
    _platform=$(get_kernel_name)
    if ! echo "$SUPPORTED_PLATFORMS" | grep -q "$_platform"; then
        print_info "Your platform is: $_platform"
        print_error "This script only supports the following platforms: $SUPPORTED_PLATFORMS"
    fi

    local _arch
    _arch=$(get_hardware_name)
    if ! echo "$SUPPORTED_ARCHS" | grep -q "$_arch"; then
        print_info "Your architecture is: $_arch"
        print_error "This script only supports the following architectures: $SUPPORTED_ARCHS"
    fi

    local add_aliases=false
    local powerlevel10k=false

    for arg in "$@"; do
        case "$arg" in
        --*)
            case "$arg" in
            --help)
                display_usage
                exit 0
                ;;
            --version)
                print_info "${SCRIPT_NAME} ${SCRIPT_VERSION}"
                exit 0
                ;;
            --add-aliases)
                add_aliases=true
                ;;
            --powerlevel)
                powerlevel10k=true
                ;;
            *)
                echo "Unknown option: $arg"
                exit 1
                ;;
            esac
            ;;
        -*)
            arg_chars=$(echo "$arg" | sed 's/^-//')
            while [ -n "$arg_chars" ]; do
                opt=$(echo "$arg_chars" | cut -c1)
                arg_chars=$(echo "$arg_chars" | cut -c2-)
                case "$opt" in
                h)
                    display_usage
                    exit 0
                    ;;
                v)
                    print_info "${SCRIPT_NAME} ${SCRIPT_VERSION}"
                    exit 0
                    ;;
                a)
                    add_aliases=true
                    ;;
                p)
                    powerlevel10k=true
                    ;;
                *)
                    echo "Unknown option: -$opt"
                    exit 1
                    ;;
                esac
            done
            ;;
        *) ;;
        esac
    done

    local _pkg_manager
    _pkg_manager=$(detect_package_manager)
    local _require_packages=""
    local _require_commands=""
    local _require_nonroot_packages="sudo"
    local _missing_deps=""
    for _pkg in $_require_packages; do
        if ! package_exists "${_pkg}"; then
            _missing_deps="${_missing_deps} ${_pkg}"
        fi
    done
    for _cmd in ${_require_commands}; do
        if ! command_exists "${_cmd}"; then
            _missing_deps="${_missing_deps} ${_cmd}"
        fi
    done
    if ! is_root; then
        for _dep in ${_require_nonroot_packages}; do
            if ! package_exists "${_dep}"; then
                _missing_deps="${_missing_deps} ${_dep}"
            fi
        done
    fi
    if [ -n "${_missing_deps}" ]; then
        print_error "missing dependencies:${_missing_deps}"
    fi

    case "$_pkg_manager" in
    apt)
        run_command_as_root apt-get update
        run_command_as_root apt-get install --yes curl git zsh
        ;;
    apk)
        run_command_as_root apk update
        run_command_as_root apk add curl git shadow zsh
        ;;
    esac

    print_info "Please enter your password to change the shell to zsh."
    run_command chsh -s "$(command -v zsh)"
    if [ ! -d "${HOME}/.oh-my-zsh" ]; then
        run_command sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-autosuggestions ]; then
        run_command git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-autosuggestions
    fi
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-syntax-highlighting ]; then
        run_command git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-syntax-highlighting
    fi
    run_command sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

    if [ "$add_aliases" = true ] && ! grep -q "tah5.com" ~/.zshrc; then
        run_command cat <<'ALIAS' >>~/.zshrc
# Aliases
alias t='curl -fsSL https://tah5.com/'
alias m='sh -c "$(curl -fsSL https://tah5.com/s/menu)"'
ALIAS
    fi

    if [ "$powerlevel10k" = true ]; then
        if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k ]; then
            run_command git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k
        fi

        run_command sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
        if [ ! -f ~/.p10k.zsh ]; then
            run_command cp "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k/config/p10k-pure.zsh ~/.p10k.zsh
        fi

        run_command sed -i '1i # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.\n# Initialization code that may require console input (password prompts, [y/n]\n# confirmations, etc.) must go above this block; everything else may go below.\nif [[ -r "$\{XDG_CACHE_HOME:-$\HOME/.cache}/p10k-instant-prompt-$\{(%):-%n}.zsh" ]]; then\n  source "$\{XDG_CACHE_HOME:-$\HOME/.cache}/p10k-instant-prompt-$\{(%):-%n}.zsh"\nfi\n' ~/.zshrc

        run_command cat <<'EOF' >>~/.zshrc
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
        curl -fsSL https://tah5.com/assets/sh/.p10k.zsh -o "${HOME}/.p10k.zsh"
        print_info "If you want to configure Powerlevel10k, run 'p10k configure' in your terminal."
    else
        run_command sed -i 's/^ZSH_THEME=.*/ZSH_THEME="terminalparty"/' ~/.zshrc
    fi

    print_info "You need to restart zsh with 'exec zsh'."
}

main "$@" || exit 1
