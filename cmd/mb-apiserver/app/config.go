// Copyright 2024 孔令飞 <colin404@foxmail.com>. All rights reserved.
// Use of this source code is governed by a MIT style
// license that can be found in the LICENSE file. The original repo for
// this file is https://github.com/onexstack/miniblog. The professional
// version of this repository is https://github.com/onexstack/onex.

package app

import (
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
)

const (
	// defaultHomeDir 定义放置 miniblog 服务配置的默认目录.
	defaultHomeDir = ".miniblog"

	// defaultConfigName 指定 miniblog 服务的默认配置文件名.
	defaultConfigName = "mb-apiserver.yaml"
)

// 注意：onInitialize 和 setupEnvironmentVariables 函数已被移除
// 因为项目现在使用 core.OnInitialize 来处理配置初始化

// searchDirs 返回默认的配置文件搜索目录.
func searchDirs() []string {
	// 获取用户主目录
	homeDir, err := os.UserHomeDir()
	// 如果获取用户主目录失败，则打印错误信息并退出程序
	cobra.CheckErr(err)
	return []string{filepath.Join(homeDir, defaultHomeDir), "."}
}

// filePath 获取默认配置文件的完整路径.
func filePath() string {
	home, err := os.UserHomeDir()
	// 如果不能获取用户主目录，则记录错误并返回空路径
	cobra.CheckErr(err)
	return filepath.Join(home, defaultHomeDir, defaultConfigName)
}
