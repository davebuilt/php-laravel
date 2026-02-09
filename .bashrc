# ~/.bashrc - Laravel Dev Container Shell Configuration
# Sourced for interactive bash sessions

# Exit early for non-interactive shells
[[ $- != *i* ]] && return

# ----------------------------------------------------------------
# Environment
# ----------------------------------------------------------------

export PATH="$HOME/.local/bin:$PATH"

# Source Laravel .env if in project directory
if [ -f /var/www/.env ]; then
    set -a
    source /var/www/.env
    set +a
fi

# ----------------------------------------------------------------
# History
# ----------------------------------------------------------------

HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T  "
shopt -s histappend

# ----------------------------------------------------------------
# Shell Options
# ----------------------------------------------------------------

shopt -s checkwinsize
shopt -s globstar 2>/dev/null
shopt -s nocaseglob
shopt -s cdspell

# ----------------------------------------------------------------
# Prompt
# ----------------------------------------------------------------

__git_prompt() {
    local branch status indicators=""

    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
    status=$(git status --porcelain 2>/dev/null)

    [[ $status == *" M"* || $status == *"??"* || $status == *" D"* ]] && indicators+="*"
    [[ $status == *"M "* || $status == *"A "* || $status == *"D "* || $status == *"R "* ]] && indicators+="+"
    [[ $status == *"??"* ]] && indicators+="?"

    if [ -z "$status" ]; then
        # Clean - green
        printf ' (\033[32m%s\033[0m)' "$branch"
    else
        # Dirty - yellow
        printf ' (\033[33m%s%s\033[0m)' "$branch" "$indicators"
    fi
}

__build_prompt() {
    local last_exit=$?
    local reset='\[\033[0m\]'
    local bold_cyan='\[\033[1;36m\]'
    local bold_blue='\[\033[1;34m\]'
    local green='\[\033[32m\]'
    local red='\[\033[31m\]'

    # App name from Laravel .env or fallback
    local app_name="${APP_NAME:-laravel}"
    # Strip quotes if present
    app_name="${app_name%\"}"
    app_name="${app_name#\"}"

    # Directory: replace /var/www with ~
    local dir="${PWD/#\/var\/www/\~}"

    # Git info (non-escaped - evaluated at prompt time)
    local git_info
    git_info=$(__git_prompt)

    # Prompt colour based on last exit code
    local prompt_colour
    if [ $last_exit -eq 0 ]; then
        prompt_colour="$green"
    else
        prompt_colour="$red"
    fi

    PS1="\n${bold_cyan}[${app_name}]${reset} ${bold_blue}${dir}${reset}${git_info}\n${prompt_colour}\$${reset} "
}

PROMPT_COMMAND=__build_prompt

# ----------------------------------------------------------------
# Bash Completion
# ----------------------------------------------------------------

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

# ----------------------------------------------------------------
# Aliases - Directory
# ----------------------------------------------------------------

alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'

# ----------------------------------------------------------------
# Aliases - Laravel
# ----------------------------------------------------------------

alias art='php artisan'
alias tinker='php artisan tinker'
alias fresh='php artisan migrate:fresh --seed'
alias seed='php artisan db:seed'
alias routes='php artisan route:list'
alias serve='php artisan serve'
alias sail='vendor/bin/sail'
alias pest='vendor/bin/pest'
alias pint='vendor/bin/pint'

# ----------------------------------------------------------------
# Aliases - Composer
# ----------------------------------------------------------------

alias ci='composer install'
alias cu='composer update'
alias cr='composer require'
alias cda='composer dump-autoload'

# ----------------------------------------------------------------
# Aliases - Git
# ----------------------------------------------------------------

alias gs='git status'
alias gl='git log --oneline -20'
alias gd='git diff'
alias gds='git diff --staged'

# ----------------------------------------------------------------
# Aliases - Testing
# ----------------------------------------------------------------

alias t='php artisan test'
alias tf='php artisan test --filter'
alias tp='php artisan test --parallel'

# ----------------------------------------------------------------
# Aliases - npm
# ----------------------------------------------------------------

alias dev='npm run dev'
alias build='npm run build'
alias watch='npm run dev -- --watch'

# ----------------------------------------------------------------
# Aliases - Navigation
# ----------------------------------------------------------------

alias ..='cd ..'
alias ...='cd ../..'
alias cls='clear'

# ----------------------------------------------------------------
# Tool Integrations - bat
# ----------------------------------------------------------------

if command -v bat &>/dev/null; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p --theme=ansi'"
    export BAT_THEME="ansi"
fi

# ----------------------------------------------------------------
# Tool Integrations - fzf
# ----------------------------------------------------------------

if command -v fzf &>/dev/null; then
    eval "$(fzf --bash)"
fi

if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# ----------------------------------------------------------------
# Tool Integrations - Coloured man pages (fallback)
# ----------------------------------------------------------------

export LESS_TERMCAP_mb=$'\e[1;31m'
export LESS_TERMCAP_md=$'\e[1;34m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;32m'
