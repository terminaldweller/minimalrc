autoload -Uz compinit
compinit

zmodload zsh/complist
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

eval `dircolors ~/.dir_colors`

setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_NO_STORE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt AUTO_CD
setopt AUTO_PUSHD
setopt NO_BEEP
setopt INTERACTIVE_COMMENTS
setopt PROMPT_SUBST
# no more C-s and C-q
unsetopt FLOW_CONTROL
setopt LONG_LIST_JOBS
setopt +o nomatch
export HISTFILE=~/.zsh_history
setopt LIST_PACKED
export HISTSIZE=100000
export SAVEHIST=100000


source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(fzf --zsh)"

alias ls="eza"
alias l="eza -abgnhHliSmMxUO"
alias ll="eza -F always -abgnhHliSmMxUO --changed --color-scale all --color-scale-mode gradient --icons always --git --git-repos -@"
alias la="exa -a"
alias fd="fdfind"
alias j="zoxide"
alias w3m='w3m -o user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"'
alias v="vim"

export PATH=$PATH:/usr/sbin/
export FZF_TMUX_OPTS="-p 70%,70% --border=sharp"
export FZF_DEFAULT_OPTS="--color fg:7,bg:0,hl:31,fg+:24,bg+:0,hl+:63,info:34,prompt:27,spinner:24,pointer:24,marker:22"
export WWW_HOME="https://searx.terminaldweller.com"
export COLORTERM=truecolor
export LESS_TERMCAP_mb=$'\e[01;31m'
export LESS_TERMCAP_md=$'\e[01;38;5;74m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\x1b[48;5;22m\x1b[38;5;0m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[04;38;5;146m'

source ~/powerlevel10k/powerlevel10k.zsh-theme

bindkey -v

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
eval "$(/home/devi/.local/bin/mise activate zsh)"

. "$HOME/.cargo/env"

[ -f "/home/devi/.ghcup/env" ] && . "/home/devi/.ghcup/env" # ghcup-env
bindkey "
