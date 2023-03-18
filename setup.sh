#!/usr/bin/env bash
set -eu

if [ "$(uname)" != "Darwin" ] ; then
  echo 'Not macOS!'
  exit 1
fi

chflags nohidden ~/Library # ~/Library ディレクトリを見えるようにする

defaults write com.apple.finder _FXShowPosixPathInTitle -bool true          # Finder のタイトルバーにフルパスを表示する
defaults write com.apple.finder _FXSortFoldersFirst -bool true              # 名前で並べ替えを選択時にディレクトリを前に置くようにする
defaults write com.apple.finder AnimateWindowZoom -bool false               # フォルダを開くときのアニメーションを無効にする
defaults write com.apple.finder AppleShowAllFiles YES                       # 不可視ファイルを表示する
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false  # 拡張子変更時の警告を無効化する
defaults write com.apple.finder ShowPathbar -bool true                      # パスバーを表示する
defaults write com.apple.finder ShowStatusBar -bool true                    # ステータスバーを表示する
defaults write com.apple.finder ShowTabView -bool true                      # タブバーを表示する

killall Finder

echo 'Make Working Directories'
work_dir="$HOME/00_Main"
mkdir -p "$work_dir/01_InBox" # とりあえず一旦何でも放り込む用
mkdir -p "$work_dir/project"  # 各プロジェクト関連
mkdir -p "$work_dir/ghq"      # git管理対象のコード
mkdir -p "$work_dir/code"     # git管理対象外のコード
mkdir -p "$work_dir/bin"      # 自作バイナリとか
mkdir -p "$work_dir/material" # その他資料類

echo 'Install Rosetta2'
softwareupdate --install-rosetta --agree-to-license

echo 'Install xcode-select'
if ! (xcode-select -p  > /dev/null 2>&1); then
    xcode-select --install
    sleep 1
    osascript << EOD
tell application "System Events"
    tell process "Install Command Line Developer Tools"
        keystroke return
        click button "Agree" of window "License Agreement"
    end tell
end tell
EOD

    while ! (xcode-select -p  > /dev/null 2>&1); do
        sleep 10
    done
    sleep 5
    osascript << EOD
tell application "System Events"
    tell process "Install Command Line Developer Tools"
        click button "Done" of window 1
    end tell
end tell
EOD
fi

echo 'Install Homebrew'
if ! (type brew > /dev/null 2>&1); then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # shellcheck disable=SC2016
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> "$HOME/.zprofile"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo 'Install packages requiring password'
brew install --cask 1password zoom karabiner-elements aquaskk jetbrains-toolbox docker

echo 'Install packages using frequently'
brew install git curl hstr htop speedtest-cli trash tree mas

brew install --cask alfred aws-vault clipy discord gather google-chrome iterm2 \
     jetbrains-toolbox miro openinterminal postman sublime-text visual-studio-code vivaldi

echo 'Install terminal font'
if [ ! -e "$HOME/Library/Fonts/SFMonoSquare-Regular.otf" ]; then
    brew tap delphinus/sfmono-square
    brew install sfmono-square
    cp "$(brew --prefix sfmono-square)/share/fonts/SFMonoSquare-Regular.otf" "$HOME/Library/Fonts/SFMonoSquare-Regular.otf"
fi

echo 'Install coding font'
if [ ! -e "$HOME/Library/Fonts/Myrica.TTC" ]; then
    curl -LO https://github.com/tomokuni/Myrica/raw/master/product/Myrica.zip
    ditto -V -x -k --rsrc Myrica.zip Myrica
    cp './Myrica/Myrica.TTC' "$HOME/Library/Fonts/Myrica.TTC"
    rm -rf Myrica.zip Myrica
fi

echo 'Install packages via asdf'
if ! (type asdf > /dev/null 2>&1); then
    brew install asdf
    echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> "${ZDOTDIR:-$HOME}/.zshrc"
    soruce "${ZDOTDIR:-$HOME}/.zshrc"
fi
asdf-install() {
    local plugin=$1;
    local plugin_version=$2
    local arch=${3:-arm64}
    if ! (asdf plugin list | grep -q "^${plugin}$"); then
        asdf plugin add "$plugin"
    fi
    echo "asdf install $plugin $plugin_version"
    arch -"$arch" asdf install "$plugin" "$plugin_version"
    asdf global "$plugin" "$plugin_version"
}

while read -r plugin; do
    asdf-install "$plugin" "$(asdf latest "$plugin" || echo 'latest')"
done << EOD
aws-sam-cli
awscli
delta
direnv
fd
ghq
github-cli
golang
gradle
grpcurl
helm
helmfile
jq
k6
k9s
kubectl
kubectx
lazygit
maven
minikube
neovim
peco
python
ripgrep
sbt
scala
sccache
shellcheck
starship
stern
terraform
terraformer
tokei
yq
EOD

# nodejs
asdf-install nodejs lts

if ! (type brew > /dev/null 2>&1); then
    echo 'Install JDK 17'
    asdf-install java "$(asdf list-all java | grep '^temurin-17.*' | tail -1)"
    echo -e '\n. ~/.asdf/plugins/java/set-java-home.zsh' >> "${ZDOTDIR:-$HOME}/.zshrc"
    echo 'java_macos_integration_enable = yes' >> "$HOME/.asdfrc"
fi

echo 'Install x86_6d packages via asdf'
while read -r plugin; do
    asdf-install "$plugin" "$(asdf latest "$plugin" || echo 'latest')" x86_64
done << EOF
dprint
exa
hyperfine
EOF

sort -u "$HOME/.tool-versions" -o "$HOME/.tool-versions"

echo 'Install Rust'
if ! (type rustup > /dev/null 2>&1); then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

cargo install toml-cli
toml set "$HOME/.cargo/config.toml" build.rustc-wrapper "$(which sccache)" 1<> "$HOME/.cargo/config.toml"

cargo install cargo-update cargo-make cargo-edit

echo 'Install Variant'
if ! (type variant > /dev/null 2>&1); then
    curl -sL https://raw.githubusercontent.com/variantdev/get/master/get | sudo INSTALL_TO=/usr/local/bin sh
fi

echo 'Install AppStore Applications'
mas install 1429033973 # Run Cat
mas install 1423210932 # Flow
