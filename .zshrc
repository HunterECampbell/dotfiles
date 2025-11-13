# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH


# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"


# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="af-magic"


# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDUM_CANDIDATES=( "robbyrussell" "agnoster" )


# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"


# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"


# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time


# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13


# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"


# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"


# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"


# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"


# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"


# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"


# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"


# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder


# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
 git
 sudo
 zsh-autosuggestions
 nvm
)


# Source Oh My Zsh. This must come BEFORE starship init and other custom configs.
source $ZSH/oh-my-zsh.sh


# User configuration


# export MANPATH="/usr/local/man:$MANPATH"


# You may need to manually set your language environment
# export LANG=en_US.UTF-8


# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi


# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.


# Scripts
source ~/scripts/zsh_scripts/*
# This source includes:
# start_minecraft_server.zsh
# virus_scan.zsh

# Script Aliases
alias mcserver='start_minecraft_server'


# Aliases
alias c='f() { if [[ -z "$1" ]]; then code .; else code "$@"; fi };f'
alias cl='clear'
alias run='npm run'
alias s='source ~/.zshrc'
alias z='code ~/.zshrc'
alias repo='f() { ~/Development/repos/$1 };f'
alias repoc='f() { ~/Development/repos/$1 && c };f'
alias update-pop='sudo apt update -y && sudo apt upgrade -y'


## Virus Scanning Specific Aliases
alias virus-scan='virus_scan'
alias full-system-virus-scan="~/Development/repos/dotfiles/clamav/clamav-full-scan"
alias quarantine-virus='f() { sudo /usr/local/bin/clamscan --move=/var/quarantine $1 };f'
alias remove-virus='f() { sudo /usr/local/bin/clamscan --remove $1 };f'


## Git Specific Aliases
alias gch='git checkout'
alias gchb='git checkout -b'
alias gp='git push'
alias gpso='git push --set-upstream origin'
alias ga='git add -A'
alias gc='git commit -m'
alias gac='f() { ga && gc $1 };f'
alias gp='git push'
alias gpo='git push --set-upstream origin $(git symbolic-ref --short HEAD)'
alias gpyolo='gp --no-verify'
alias gmagic='f() { ga && gc $1 && gp };f'
alias gmagico='f() { ga && gc $1 && gpo };f'
alias gmagicyolo='f() { ga && gc $1 --no-verify && gp --no-verify };f'
alias gmagicoyolo='f() { ga && gc $1 --no-verify && gpo --no-verify };f'

alias gchd='git checkout develop'
alias gpl='git pull'
alias fresh='f() { git checkout "${1:-develop}" && gpl; }; f' # Defaults to develop, but allows you to pass in a specific branch
alias freshm='f() { git fetch origin "${1:-develop}" && git merge "origin/${1:-develop}"; }; f' # Defaults to develop, but allows you to pass in a specific branch
alias gdiff='f() { git diff develop..$(git symbolic-ref --short HEAD) | xclip -selection clipboard };f' # Grabs the current branch's diff and adds it to the clipboard

alias rh='git reset --hard'
alias gst='git stash'
alias gstp='git stash pop'


## Docker Specific Aliases
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcdu='dcd && dcu'
alias dps='docker ps -a' # Lists all containers
alias dstart='f() { docker compose start $1 };f' # $1 is the container name to start -> Turns the container on
alias drestart='f() { docker compose restart $1 };f' # $1 is the container name to restart -> Turns the container off and then on
alias dprune='docker system prune --all --volumes'
alias dlog='f() { docker logs -f $1 };f' # $1 is the container name


## NPM Specific Aliases
alias i='npm i'
alias u='npm uninstall'
alias rb='npm run build'
alias rd='npm run dev'
alias lint='npm run lint'
alias lint:check='npm run lint:check'


## PNPM Specific Aliases
alias pi='pnpm i'
alias pu='pnpm uninstall'
alias prb='pnpm run build'
alias prd='pnpm run dev'
alias plint='pnpm run lint'


# Vasion Specific Aliases
alias mu='fresh && make pull && make up-d' # In a Window's Terminal (Admin), run `net stop http` to get this working away from port 443 - Use `latest-edge` on the app-api (wf-api) to get lastest endpoint updates
alias md='make down'
alias mdu='md && mu'
alias start-gw='gst && fresh && gstp && mu'
alias restart-gw='md && start-gw'
alias nuke='pnpm run nuke'
alias rbw='prb -w @vasion/workflow'
alias rt='npm run test'
alias rtw='npm run test:watch -w apps/workflow'
alias rtwu='npm run test:watch -w @vac/workflow'
alias rs='npm run storybook'
alias prdp='pnpm run:prod'
alias fixfe='pnpm --filter @vasion/root dev'
alias start-stage='flatpak run com.google.Chrome --disable-web-security --user-data-dir="/tmp/chrome_dev_session"google.Chrome --disable-web-security --user-data-dir="/tmp/chrome_dev_session"com.google.Chrome --disable-web-security --user-data-dir="/tmp/chrome_dev_session"flatpak run com.google.Chrome --disable-web-security --user-data-dir="/tmp/chrome_dev_session"'


## Zellij Specific Aliases
alias list-sessions='zellij list-sessions'
alias create-session='f() { zellij -s $1 };f' # $1 is the session name to create
alias attach='f() { zellij attach $1 };f' # $1 is the session name to attach to
alias delete-session='f() { zellij delete-session $1 --force };f' # $1 is the session name to delete


# Go Setup
# export GOROOT=/usr/local/go-1.21.3
# export GOPATH=$HOME/go
# export PATH=$GOPATH/bin:$GOROOT/bin:$PATH


# Automatically load terminal sessions with zellij if installed and not already inside a zellij session
if command -v zellij &> /dev/null && [ -z "$ZELLIJ" ]; then
    zellij attach -c
fi


# NVM auto-use for directories with .nvmrc - Recommended by nvm
# This should be at the very end of your .zshrc
# after nvm has been sourced and any oh-my-zsh plugins.
if [[ -r .nvmrc ]]; then
 nvm use
fi
autoload -U add-zsh-hook
add-zsh-hook chpwd nvm_auto_use
nvm_auto_use() {
 if [[ -r .nvmrc ]]; then
   nvm use
 fi
}

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
