#!/bin/bash

# パッケージの名前をスペースで区切って入力させ、同時にアップデート開始時刻を設定
read -p "パッケージの名前をスペースで区切って入力してください: " packages
start_time=$(date '+%Y-%m-%d %H:%M:%S')

# 現在のバージョンと利用できるバージョンを表示する関数
function display_versions() {
    local package=$1
    if rpm -q $package > /dev/null 2>&1; then
        current_version=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}\n' $package)
        available_version=$(yum check-update $package | grep $package | awk '{print $2}')
        if [ -z "$available_version" ]; then
            echo "アップデートできるパッケージはありません。"
            return 1
        fi
        echo "現在のバージョン: $current_version"
        echo "利用できるバージョン: $available_version"
        return 0  # インストールされている場合
    else
        echo "$package はインストールされていません。"
        available_version=$(yum --showduplicates list $package | grep $package | tail -1 | awk '{print $2}')
        echo "インストールできるバージョン: $available_version"
        return 1  # インストールされていない場合
    fi
}

# アップデートまたはインストールを行う関数
function update_or_install_package() {
    local package=$1
    if rpm -q $package > /dev/null 2>&1; then
        echo "アップデートを開始します..."
        start_update=$(date '+%Y-%m-%d %H:%M:%S')
        if sudo yum update -y $package; then
            end_update=$(date '+%Y-%m-%d %H:%M:%S')
            echo "アップデートを完了しました。"
            echo "アップデート開始時刻: $start_update"
            echo "アップデート終了時刻: $end_update"
        else
            echo "アップデートに失敗しました。"
            exit 1
        fi
    else
        echo "インストールを開始します..."
        start_install=$(date '+%Y-%m-%d %H:%M:%S')
        if sudo yum install -y $package; then
            end_install=$(date '+%Y-%m-%d %H:%M:%S')
            echo "インストールを完了しました。"
            echo "インストール開始時刻: $start_install"
            echo "インストール終了時刻: $end_install"
        else
            echo "インストールに失敗しました。"
            exit 1
        fi
    fi
    new_version=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}\n' $package)
    echo "現在のバージョンは $new_version です。"
}

# ログを保存する関数
function save_log() {
    local package=$1
    read -p "ログを保存するディレクトリを入力してください: " log_dir
    if [ ! -d "$log_dir" ]; then
        echo "ディレクトリが存在しません。"
        exit 1
    fi
    log_filename="${log_dir}/${package}_$(date '+%Y%m%d%H%M').log"
    echo "ログを保存しています..."
    sudo awk -v start="$start_time" '{
        cmd = "date -d \"" start "\" +\"%s\"";
        cmd | getline start_epoch;
        close(cmd);
        log_time = $1 " " $2 " " $3;
        cmd = "date -d \"" log_time "\" +\"%s\"";
        cmd | getline log_epoch;
        close(cmd);
        if (log_epoch >= start_epoch) {
            print;
        }
    }' /var/log/messages | sudo tee "$log_filename" > /dev/null
    echo "ログを $log_filename に保存しました。"
}

# メインスクリプト
read -p "ログを保存しますか？ (yes/no): " save_log_input
if [ "$save_log_input" == "yes" ]; then
    save_log
else
    echo "操作を中止しました。"
fi

for package in $packages; do
    if display_versions $package; then
        read -p "$package をアップデートしますか？ (yes/no): " action
    else
        read -p "$package をインストールしますか？ (yes/no): " action
    fi

    if [ "$action" == "yes" ]; then
        update_or_install_package $package
    else
        echo "$package の操作を中止しました。"
    fi
done