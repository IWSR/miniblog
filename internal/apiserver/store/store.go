// Copyright 2024 孔令飞 <colin404@foxmail.com>. All rights reserved.
// Use of this source code is governed by a MIT style
// license that can be found in the LICENSE file. The original repo for
// this file is https://github.com/onexstack/miniblog. The professional
// version of this repository is https://github.com/onexstack/onex.

package store

//go:generate mockgen -destination mock_store.go -package store github.com/onexstack/miniblog/internal/apiserver/store IStore,UserStore,PostStore,ConcretePostStore

import (
	"context"
	"sync"

	"github.com/google/wire"
	"github.com/onexstack/onexstack/pkg/store/where"
	"gorm.io/gorm"
)

// ProviderSet 是一个 Wire 的 Provider 集合，用于声明依赖注入的规则.
// 包含 NewStore 构造函数，用于生成 datastore 实例.
// wire.Bind 用于将接口 IStore 与具体实现 *datastore 绑定，
// 从而在依赖 IStore 的地方，能够自动注入 *datastore 实例.
var ProviderSet = wire.NewSet(NewStore, wire.Bind(new(IStore), new(*datastore)))

var (
	once sync.Once
	// S 全局变量，方便其它包直接调用已初始化好的 datastore 实例.
	S *datastore
)

// IStore 定义了 Store 层需要实现的方法.
type IStore interface {
	// DB 返回 Store 层的 *gorm.DB 实例，在少数场景下会被用到.
	DB(ctx context.Context, wheres ...where.Where) *gorm.DB
	TX(ctx context.Context, fn func(ctx context.Context) error) error

	User() UserStore
	Post() PostStore
	// ConcretePost ConcretePosts 是一个示例 store 实现，用来演示在 Go 中如何直接与 DB 交互.
	ConcretePost() ConcretePostStore
}

// transactionKey 用于在 context.Context 中存储事务上下文的键.
type transactionKey struct{}

// datastore 是 IStore 的具体实现.
type datastore struct {
	core *gorm.DB

	// 可以根据需要添加其他数据库实例
	// fake *gorm.DB
}

// 确保 datastore 实现了 IStore 接口.
var _ IStore = (*datastore)(nil)

// NewStore 创建一个 IStore 类型的实例.
func NewStore(db *gorm.DB) *datastore {
	// 确保 S 只被初始化一次
	once.Do(func() {
		S = &datastore{db}
	})

	return S
}

// DB 根据传入的条件（wheres）对数据库实例进行筛选.
// 如果未传入任何条件，则返回上下文中的数据库实例（事务实例或核心数据库实例）.
func (store *datastore) DB(ctx context.Context, wheres ...where.Where) *gorm.DB {
	db := store.core
	// 从上下文中提取事务实例
	if tx, ok := ctx.Value(transactionKey{}).(*gorm.DB); ok {
		db = tx
	}

	// 遍历所有传入的条件并逐一叠加到数据库查询对象上
	for _, whr := range wheres {
		db = whr.Where(db)
	}
	return db
}

// TX 返回一个新的事务实例.
// nolint: fatcontext
func (store *datastore) TX(ctx context.Context, fn func(ctx context.Context) error) error {
	return store.core.WithContext(ctx).Transaction(
		func(tx *gorm.DB) error {
			ctx = context.WithValue(ctx, transactionKey{}, tx)
			return fn(ctx)
		},
	)
}

// User 返回一个实现了 UserStore 接口的实例.
func (store *datastore) User() UserStore {
	return newUserStore(store)
}

// Post 返回一个实现了 PostStore 接口的实例.
func (store *datastore) Post() PostStore {
	return newPostStore(store)
}

// ConcretePost 返回一个实现了 ConcretePostStore 接口的实例.
func (store *datastore) ConcretePost() ConcretePostStore {
	return newConcretePostStore(store)
}
