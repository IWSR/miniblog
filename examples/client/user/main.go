// Copyright 2024 孔令飞 <colin404@foxmail.com>. All rights reserved.
// Use of this source code is governed by a MIT style
// license that can be found in the LICENSE file. The original repo for
// this file is https://github.com/onexstack/miniblog. The professional
// version of this repository is https://github.com/onexstack/onex.

package main

import (
	"context"
	"flag"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
	"k8s.io/utils/ptr"

	"github.com/onexstack/miniblog/examples/helper"
	"github.com/onexstack/miniblog/internal/pkg/known"
	apiv1 "github.com/onexstack/miniblog/pkg/api/apiserver/v1"
)

var (
	addr  = flag.String("addr", "localhost:6666", "The grpc server address to connect to.")
	limit = flag.Int64("limit", 10, "Limit to list users.")
)

func main() {
	flag.Parse()

	// 建立与 gRPC 服务器的连接
	conn, err := grpc.NewClient(*addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect to grpc server: %v", err)
	}
	defer conn.Close() // 确保连接在函数结束时关闭

	client := apiv1.NewMiniBlogClient(conn) // 创建 MiniBlog 客户端

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)

	defer cancel()

	_ = uuid.New().String()

	createUserRequest := helper.ExampleCreateUserRequest()
	createUserResponse, err := client.CreateUser(ctx, createUserRequest)
	if err != nil {
		log.Fatalf("Failed to create user: %v, username: %s", err, createUserRequest.Username)
	}
	log.Printf("[CreateUser     ] Success to create user, userID: %s", createUserResponse.UserID)

	loginResponse, err := client.Login(ctx, &apiv1.LoginRequest{
		Username: createUserRequest.Username,
		Password: createUserRequest.Password,
	})
	if err != nil {
		log.Fatalf("Failed to login: %v", err)
	}
	if loginResponse.Token == "" {
		log.Printf("Failed to validate token string: received an empty toke")
		return
	}
	log.Printf("[Login          ] Success to login")

	// 创建 metadata，用于传递 Token
	md := metadata.Pairs("Authorization", "Bearer "+loginResponse.Token, known.XUserID, createUserResponse.UserID)
	// 将 metadata 附加到上下文中
	ctx = metadata.NewOutgoingContext(ctx, md)

	defer func() {
		_, _ = client.DeleteUser(ctx, &apiv1.DeleteUserRequest{UserID: createUserResponse.UserID})
	}()

	refreshTokenResponse, err := client.RefreshToken(ctx, &apiv1.RefreshTokenRequest{})
	if err != nil {
		log.Printf("Failed to refresh token: %v", err)
		return
	}
	if refreshTokenResponse.Token == "" {
		log.Printf("Token cannot be empty")
		return
	}
	log.Printf("[RefreshToken   ] Success to refresh token")

	// 请求 UpdateUser 接口
	_, err = client.UpdateUser(ctx, &apiv1.UpdateUserRequest{
		UserID:   createUserResponse.UserID,
		Nickname: ptr.To("令飞孔"),
	})
	if err != nil {
		log.Printf("Failed to update user: %v", err)
		return
	}
	log.Printf("[UpdateUser     ] Success to update user: %v", createUserResponse.UserID)

	// 请求 ChangePassword 接口
	newPassword := "onex(#)888"
	_, err = client.ChangePassword(ctx, &apiv1.ChangePasswordRequest{
		UserID:      createUserResponse.UserID,
		OldPassword: createUserRequest.Password,
		NewPassword: newPassword,
	})
	if err != nil {
		log.Printf("Failed to change password: %v", err)
		return
	}
	log.Printf("[ChangePassword ] Success to change password")

	loginResponse, err = client.Login(ctx, &apiv1.LoginRequest{
		Username: createUserRequest.Username,
		Password: newPassword,
	})
	if err != nil {
		log.Printf("Failed to login with new password: %v", err)
		return
	}
	log.Printf("[Login          ] Success to login with new password")
	// 创建 metadata，用于传递 Token
	md = metadata.Pairs("Authorization", "Bearer "+loginResponse.Token, known.XUserID, createUserResponse.UserID)
	// 将 metadata 附加到上下文中
	ctx = metadata.NewOutgoingContext(ctx, md)

	getUserResponse, err := client.GetUser(ctx, &apiv1.GetUserRequest{UserID: createUserResponse.UserID})
	if err != nil {
		log.Printf("Failed to get user: %v", err)
		return
	}
	if getUserResponse.User.UserID != createUserResponse.UserID || getUserResponse.User.Username != createUserRequest.Username {
		log.Printf("Failed to get user: Username or UserID does not match")
		return
	}
	log.Printf("[GetUser        ] Success to get user: %v", createUserResponse.UserID)

	listResponse, err := client.ListUser(ctx, &apiv1.ListUserRequest{Offset: 0, Limit: *limit})
	if err != nil {
		if !strings.Contains(err.Error(), "PermissionDenied") {
			log.Printf("Failed to list user: %v", err)
			return
		}
		log.Printf("[ListUser       ] Success to verified that regular users cannot access the user list")
	} else {
		log.Printf("Failed to validate permission: regular users can access the user list")
		return
	}

	ctx = helper.MustWithAdminToken(ctx, client)

	// 请求 ListUser 接口
	listResponse, err = client.ListUser(ctx, &apiv1.ListUserRequest{Offset: 0, Limit: *limit})
	if err != nil {
		log.Printf("Failed to list user: %v", err)
		return
	}
	log.Printf("[ListUser       ] Success to list user, totalCount: %d", listResponse.TotalCount)
	found := false
	for _, user := range listResponse.Users {
		if user.UserID == createUserResponse.UserID && user.Username == createUserRequest.Username {
			found = true
			break
		}
	}
	if found {
		log.Printf("[ListUser       ] Success to found the previously created user")
	}

	// 请求 DeleteUser 接口
	_, err = client.DeleteUser(ctx, &apiv1.DeleteUserRequest{UserID: createUserResponse.UserID})
	if err != nil {
		log.Printf("Failed to delete user: %v", err)
		return
	}
	log.Printf("[DeleteUser     ] Success to delete user: %v", createUserResponse.UserID)

	log.Printf("[All            ] Success to test all user api")
}
