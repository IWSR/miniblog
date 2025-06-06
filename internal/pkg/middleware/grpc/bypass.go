// Copyright 2024 孔令飞 <colin404@foxmail.com>. All rights reserved.
// Use of this source code is governed by a MIT style
// license that can be found in the LICENSE file. The original repo for
// this file is https://github.com/onexstack/miniblog. The professional
// version of this repository is https://github.com/onexstack/onex.

package grpc

import (
	"context"

	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"

	"github.com/onexstack/miniblog/internal/pkg/contextx"
	"github.com/onexstack/miniblog/internal/pkg/known"
	"github.com/onexstack/miniblog/internal/pkg/log"
)

// AuthnBypassInterceptor 是一个 gRPC 拦截器，模拟所有请求都通过认证。
func AuthnBypassInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, _ *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		// 从请求头中获取用户 ID
		userID := "user-000001" // 默认用户 ID
		if md, ok := metadata.FromIncomingContext(ctx); ok {
			// 获取 header 中指定的用户 ID，假设 Header 名为 "x-user-id"
			if values := md.Get(known.XUserID); len(values) > 0 {
				userID = values[0]
			}
		}

		log.Debugw("Simulated authentication successful", "userID", userID)

		// 将默认的用户信息存入上下文
		//nolint: staticcheck
		ctx = context.WithValue(ctx, known.XUserID, userID)

		// 为 log 和 contextx 提供用户上下文支持
		ctx = contextx.WithUserID(ctx, userID)

		// 继续处理请求
		return handler(ctx, req)
	}
}
