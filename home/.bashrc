# mise comes from the vendor installer on both platforms.
export PATH="$HOME/.local/bin:$PATH"

# Android SDK and the JDK Gradle runs on. Set here, not only in fish, because
# agents run commands through `bash -lc`. The same paths are in config.fish,
# home/.androidrc.{macos,linux} and mise.simlock-worker.toml; change all four.
case "$(uname)" in
    Darwin)
        export ANDROID_HOME="$HOME/Library/Android/sdk"
        export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
        ;;
    Linux)
        export ANDROID_HOME="$HOME/android-sdk"
        export JAVA_HOME="/usr/lib/jvm/default"
        ;;
esac
export ANDROID_SDK_ROOT="$ANDROID_HOME"
# JDK on PATH for tools that ignore JAVA_HOME; see config.fish.
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$JAVA_HOME/bin:$PATH"

# Local additions run before mise so noninteractive commands prefer its shims.
[[ -f ~/.bashrc.local ]] && . ~/.bashrc.local

if command -v mise >/dev/null 2>&1; then
    if [[ $- == *i* ]]; then
        eval "$(mise activate bash)"
    else
        eval "$(mise activate bash --shims)"
    fi
fi
