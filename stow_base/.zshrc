# Greeter. This MUST stay above the Powerlevel10k instant-prompt block below:
# p10k warns (and the prompt jumps) if anything writes to the console after it.
# The logo is drawn with the kitty graphics protocol, so only run where that
# exists -- a plain TTY would render the escape sequence as garbage.
if [[ -o interactive && -t 1 && -z "$TMUX" && -z "$NO_GREETER" ]]; then
  case "$TERM" in
    xterm-ghostty|ghostty|xterm-kitty|kitty)
      # Pick a layout that fits: the full one needs ~100 columns, and anything
      # narrower wraps the CPU line back under the logo and breaks the box.
      if command -v fastfetch >/dev/null; then
        if (( ${COLUMNS:-0} >= 100 )); then
          fastfetch
        else
          fastfetch -c ~/.config/fastfetch/compact.jsonc
        fi
      fi
      ;;
  esac
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# =============================================================================
# OH MY ZSH CORE CONFIGURATION
# =============================================================================
# Path to your Oh My Zsh installation (CachyOS/Arch system location)
export ZSH="/usr/share/oh-my-zsh"

# Set ZSH_THEME to empty if loading Powerlevel10k or Starship externally below.
# To use a built-in Oh My Zsh theme, comment out the Powerlevel10k/Starship lines
# in the THEME SELECTION section and set ZSH_THEME here.
ZSH_THEME=""

# Shell behavior toggles
DISABLE_MAGIC_FUNCTIONS="true"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
HYPHEN_INSENSITIVE="true"

# Which plugins would you like to load?
# Note: zsh-autosuggestions and zsh-syntax-highlighting are loaded via Arch system plugins below.
plugins=(
  git
  sudo
  extract
  python
  web-search
  colored-man-pages
  zsh-interactive-cd
)

source $ZSH/oh-my-zsh.sh

# =============================================================================
# THEME SELECTION (TAILORED FOR YOUR WORKFLOW)
# =============================================================================
# Choose ONE of the following theme options according to your workflow:
#
# Option 1: Powerlevel10k (RECOMMENDED - Gold Standard for AI/ML/Dev workflow)
#   - Asymmetric prompt showing Git branch, Conda/Virtualenv, CUDA status, and compile times
#   - Instant prompt (<10ms startup)
#   - Customize anytime by running: p10k configure
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Option 2: Starship (The cross-shell minimalist prompt written in Rust)
#   - Fast, zero-config detection of Python, Conda, Dart, Java, C++, and Git
#   - Uncomment the line below (and comment out Option 1 above) to switch:
# eval "$(starship init zsh)"

# Option 3: Classic Oh My Zsh Themes
#   - Uncomment ONE of the ZSH_THEME lines below AND comment out Option 1 above:
# ZSH_THEME="agnoster"       # Classic Powerline breadcrumb aesthetic
# ZSH_THEME="robbyrussell"   # Clean, minimal default with git status
# ZSH_THEME="af-magic"       # Rich multi-line prompt with full path & git
# ZSH_THEME="bira"           # Multi-line prompt with user@host and git

# =============================================================================
# REMEMBRANCE OF COMMANDS (HISTORY MEMORY)
# =============================================================================
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=50000
export SAVEHIST=50000
export HISTCONTROL=ignoreboth
export HISTORY_IGNORE="(\&|[bf]g|c|clear|history|exit|q|pwd|* --help)"

setopt EXTENDED_HISTORY          # Store timestamp and runtime of commands
setopt SHARE_HISTORY             # Share history across all open terminal tabs instantly
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when history is full
setopt HIST_IGNORE_DUPS          # Don't record duplicate consecutive commands
setopt HIST_IGNORE_ALL_DUPS      # Delete old duplicate events when new ones arrive
setopt HIST_FIND_NO_DUPS         # Don't show duplicates during history search
setopt HIST_IGNORE_SPACE         # Don't record commands starting with space
setopt HIST_SAVE_NO_DUPS         # Do not write duplicate events to history file
setopt HIST_VERIFY               # Don't execute immediately upon history expansion

# =============================================================================
# FISH-LIKE AUTOCOMPLETE SUGGESTIONS & SYNTAX HIGHLIGHTING
# =============================================================================
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Autosuggestions configuration
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'        # Sleek grey suggestion text
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)    # Suggest from both history and completions
bindkey '^ ' autosuggest-accept                        # Ctrl+Space to accept suggestion (in addition to Right Arrow)

# =============================================================================
# FISH-LIKE HISTORY SUBSTRING SEARCH (UP / DOWN ARROW REMEMBRANCE)
# =============================================================================
# Typing prefix and pressing UP/DOWN searches history for matching commands
if [[ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    bindkey -M vicmd 'k' history-substring-search-up
    bindkey -M vicmd 'j' history-substring-search-down
    [[ -n "$terminfo[cuu1]" ]] && bindkey "$terminfo[cuu1]" history-substring-search-up
    [[ -n "$terminfo[cud1]" ]] && bindkey "$terminfo[cud1]" history-substring-search-down
fi

# =============================================================================
# FUZZY SEARCH (FZF) & DIRECTORY REMEMBRANCE (ZOXIDE)
# =============================================================================
export FZF_BASE=/usr/share/fzf
[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

# Smart Directory Remembrance ('z' / 'zi' jump to any previously visited directory)
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init --cmd z zsh)"
fi

# pkgfile "command not found" handler
[[ -f /usr/share/doc/pkgfile/command-not-found.zsh ]] && source /usr/share/doc/pkgfile/command-not-found.zsh

# =============================================================================
# USER WORKFLOW & ENVIRONMENT CONFIGURATION
# =============================================================================
export TERMINAL=wezterm

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/run/media/gaffer/Sid/conda_env/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/run/media/gaffer/Sid/conda_env/etc/profile.d/conda.sh" ]; then
        . "/run/media/gaffer/Sid/conda_env/etc/profile.d/conda.sh"
    else
        export PATH="/run/media/gaffer/Sid/conda_env/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# Aliases
alias ls='exa --icons -a 2>/dev/null || eza --icons -a'
alias ll='exa --icons -la 2>/dev/null || eza --icons -la'
alias la='exa --icons -a 2>/dev/null || eza --icons -a'
alias make="make -j$(nproc)"
alias ninja="ninja -j$(nproc)"
alias update="sudo pacman -Syu"
alias cleanup="sudo pacman -Rsn \$(pacman -Qtdq)"
alias jctl="journalctl -p 3 -xb"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"

# Qt & KDE Desktop Theming
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=kvantum
export XDG_CURRENT_DESKTOP=KDE
export KDE_SESSION_VERSION=6

# Dart CLI completion
[[ -f /home/reign/.dart-cli-completion/zsh-config.zsh ]] && . /home/reign/.dart-cli-completion/zsh-config.zsh || true

# --- Hiddify Proxy Switcher ---
HIDDIFY_PORT="12334"

function pon() {
    export http_proxy="http://127.0.0.1:$HIDDIFY_PORT"
    export https_proxy="http://127.0.0.1:$HIDDIFY_PORT"
    export all_proxy="socks5://127.0.0.1:$HIDDIFY_PORT"
    export HTTP_PROXY=$http_proxy
    export HTTPS_PROXY=$https_proxy
    export ALL_PROXY=$all_proxy
    export no_proxy="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"
    echo "🔒 Proxy ACTIVATED on port $HIDDIFY_PORT"
    echo "   Checking connection..."
    curl -I --connect-timeout 3 https://pypi.org | head -n 1
}

function poff() {
    unset http_proxy https_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
    unset no_proxy
    echo "🔓 Proxy DEACTIVATED (Direct Connection)"
}

function pcheck() {
    if [ -z "$http_proxy" ]; then
        echo "❌ Proxy is OFF"
    else
        echo "✅ Proxy is ON ($http_proxy)"
    fi
}

# Added by Antigravity CLI installer
export PATH="/home/reign/.local/bin:$PATH"

# --- Migrated Env Vars from old archlinux ---
export BROWSER=brave
export HF_HOME="/home/reign/ddrive/GenAI/huggingface_cache"
export CUDA_HOME=/opt/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
export GROQ_API_KEY=""
export CEREBRAS_API_KEY=""
export PATH="$PATH:/home/reign/.lmstudio/bin"
export PATH=/home/reign/.opencode/bin:$PATH
export ANDROID_HOME=/opt/android-sdk
export JAVA_HOME=/usr/lib/jvm/default
export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin
export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)
