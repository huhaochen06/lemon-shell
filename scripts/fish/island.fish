# Dynamic island hooks for fish (uses scripts/island). Enable with:
#   ln -s /etc/xdg/quickshell/caelestia/scripts/fish/island.fish ~/.config/fish/conf.d/island.fish
# (or the same path inside your clone if you run the shell from source)
#
# - A command that ran for longer than $island_notify_after seconds posts a finished / failed banner,
#   unless its terminal is focused by then. Clicking the banner goes back to the terminal.
# - Commands in $island_live_commands (package managers by default) are a live activity while they run,
#   with a stop button.
# Set these in config.fish to change them (lists are space separated).

status is-interactive; or exit

set -q island_notify_after; or set -g island_notify_after 30 # seconds
set -q island_notify_ignore; or set -g island_notify_ignore nvim vim vi hx nano micro less more man ssh mosh \
    htop btop top nvtop yazi ranger lf nnn lazygit tig tmux zellij fish bash zsh python python3 ipython node \
    bun deno qalc watch journalctl claude codex
set -q island_live_commands; or set -g island_live_commands paru yay pacman makepkg flatpak

set -g __island_cli (path dirname (path resolve (status filename)))/../island
set -g __island_live ""

# The program a command line runs, skipping sudo, env, VAR=value and the like
function __island_cmd_name --argument-names line
    for w in (string split -n ' ' -- $line)
        switch $w
            case sudo doas run0 env time nice ionice nohup command builtin exec '*=*' '-*'
                continue
        end
        path basename -- $w
        return
    end
end

function __island_duration --argument-names ms
    set -l s (math "floor($ms / 1000)")
    if test $s -lt 60
        echo {$s}s
    else if test $s -lt 3600
        printf '%dm %02ds\n' (math "floor($s / 60)") (math "$s % 60")
    else
        printf '%dh %02dm\n' (math "floor($s / 3600)") (math "floor($s % 3600 / 60)")
    end
end

function __island_title --argument-names line
    set -l t (string replace -ra '\s+' ' ' -- $line | string trim)
    string shorten -m 48 -- $t
end

function __island_preexec --on-event fish_preexec
    set -g __island_live ""
    contains -- (__island_cmd_name $argv[1]) $island_live_commands; or return
    set -g __island_live fish-$fish_pid
    command $__island_cli start $__island_live (__island_title $argv[1]) Running --icon system_update \
        --pid $fish_pid --focus-terminal >/dev/null 2>&1 &
    disown 2>/dev/null
end

function __island_postexec --on-event fish_postexec
    set -l st $status
    set -l ms $CMD_DURATION
    set -l name (__island_cmd_name $argv[1])
    test -n "$name"; or return

    set -l took (__island_duration $ms)
    set -l title (__island_title $argv[1])
    set -l result success
    set -l subtitle "Finished · $took"
    if test $st -eq 130
        set subtitle "Interrupted · $took"
    else if test $st -ne 0
        set result error
        set subtitle "Failed (exit $st) · $took"
    end

    if test -n "$__island_live"
        set -l id $__island_live
        set -g __island_live ""
        command $__island_cli end $id $title $subtitle --status $result --quiet-if-focused >/dev/null 2>&1 &
        disown 2>/dev/null
        return
    end

    test $st -ne 130; or return
    test $ms -ge (math "$island_notify_after * 1000"); or return
    contains -- $name $island_notify_ignore; and return
    command $__island_cli notify $title $subtitle --status $result --focus-terminal --quiet-if-focused \
        --key fish-$fish_pid >/dev/null 2>&1 &
    disown 2>/dev/null
end
