function mpv --wraps mpv --description 'mpv without MangoHud (its Vulkan layer segfaults mpv)'
    set -e MANGOHUD
    command mpv $argv
end
