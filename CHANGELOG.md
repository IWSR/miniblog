# [1.0.0](https://github.com/onexstack/miniblog/compare/v1.0.1...v1.0.0) (2025-09-15)



## [1.0.1](https://github.com/onexstack/miniblog/compare/f52c7bdaf1cdc6bcab31ea038f0fea468967c559...v1.0.1) (2025-09-15)


### Bug Fixes

* **ci:** resolve GitHub Actions Docker tag and lint issues ([e914e18](https://github.com/onexstack/miniblog/commit/e914e18f613e74fb0ab04a6336728f87e26dc222))
* improve production deployment script with better error handling ([c62eddd](https://github.com/onexstack/miniblog/commit/c62edddb26b4cf3a2bf73ca4c275c25345f46812))
* 修复MariaDB容器启动超时问题 ([07e9350](https://github.com/onexstack/miniblog/commit/07e935073b94043ed33582253e70c4099c837920))
* 修复MariaDB镜像拉取失败问题 ([b93fca8](https://github.com/onexstack/miniblog/commit/b93fca87b43ac50a32eb8613b1dd4a5931acd2a4))
* 修复数据库初始化和应用启动配置 ([b21466b](https://github.com/onexstack/miniblog/commit/b21466bc5a0a2a8e1207885d2800d7b235f93013))
* 修复部署脚本错误处理逻辑 ([6d90245](https://github.com/onexstack/miniblog/commit/6d90245514f332ebe96ab355970d78fb8c9bed77))
* 修复镜像标签传递和拉取问题 ([7b9d0e6](https://github.com/onexstack/miniblog/commit/7b9d0e6598c1e4c041dea4b93842ac26ca14ce69))
* 切换到内存模式部署，避免MariaDB网络问题 ([86ae5f8](https://github.com/onexstack/miniblog/commit/86ae5f8f25b5e3685035fc2df7b0443d108c60bd))
* 移除不兼容的docker pull --progress参数 ([fe8eda9](https://github.com/onexstack/miniblog/commit/fe8eda9a599c501c0d5653f1bef9c5af30e60609))
* 简化安全扫描 ([dfaf20b](https://github.com/onexstack/miniblog/commit/dfaf20b80f41145c425dd3e2f71439040cda7379))
* 简化部署脚本，移除复杂逻辑 ([0a0f5bd](https://github.com/onexstack/miniblog/commit/0a0f5bd15fd29394cab3a84c0a92bdd97c90a1e2))
* 触发分支修改回master ([83d8163](https://github.com/onexstack/miniblog/commit/83d8163032c0c9c11afdc6a2ca86f4bca6e634f0))


### chore

* 配置docker & GitHub Action & git commit 规范 ([4488fd5](https://github.com/onexstack/miniblog/commit/4488fd5416893e882141de489d88fd833ebfbd0c))


### Features

* mb-apiserver添加日志打印功能 ([3f8c9e6](https://github.com/onexstack/miniblog/commit/3f8c9e62c3b02aa2426c09e4aa8da14a076b9115))
* update ([a19fa68](https://github.com/onexstack/miniblog/commit/a19fa6894605cfe96278919e3c949565883af2f0))
* update README.md ([348d333](https://github.com/onexstack/miniblog/commit/348d333827cbf9d2dea7b2715c682f11864517b2))
* Wire依赖注入实现 ([2c8cfe4](https://github.com/onexstack/miniblog/commit/2c8cfe42ad90208855622d9c108286ecb27d4096))
* 优化部署流程，增加实时进度显示和超时时间 ([eb06c26](https://github.com/onexstack/miniblog/commit/eb06c26bbc78418fa5f4bb62ac4e72e088b543e7))
* 创建Cobra应用程序 ([895c4d9](https://github.com/onexstack/miniblog/commit/895c4d9ab4146f9d387058723468336177a901fb))
* 初始化Go项目 ([52161bb](https://github.com/onexstack/miniblog/commit/52161bb188415dfe65c9b7242794ec2b6c4ac58d))
* 基于Gin实现HTTP服务器 ([bedbb9a](https://github.com/onexstack/miniblog/commit/bedbb9afc0f76a7c1ae28013b11ce3fa213493a8))
* 增加Gin中间件支持 ([dee77ed](https://github.com/onexstack/miniblog/commit/dee77edb4bbd4392c2475f251659eef00f5f7e30))
* 增加请求参数校验功能 ([2825c10](https://github.com/onexstack/miniblog/commit/2825c109208697a01351051f402664dc281a301a))
* 大幅优化部署流程，解决镜像拉取超时问题 ([eea7673](https://github.com/onexstack/miniblog/commit/eea7673090acf8308fe3330a7957f1928fc092b7))
* 定义简洁架构Store层的数据类型 ([052cd50](https://github.com/onexstack/miniblog/commit/052cd500cec3984709b3e568fe94b7aad1940ffb))
* 实现gRPC服务器 ([e0fd89b](https://github.com/onexstack/miniblog/commit/e0fd89b036ab07af8df4388a40343fa0db07ba65))
* 实现HTTPS通信功能 ([bbb20a7](https://github.com/onexstack/miniblog/commit/bbb20a73de8aea1b395831ade1f9ad486b9197c3))
* 实现HTTP反向代理服务器 ([209c55d](https://github.com/onexstack/miniblog/commit/209c55d224f527ddd37f9c49d872e1bde0d394ac))
* 实现内存数据库 ([70cc4e0](https://github.com/onexstack/miniblog/commit/70cc4e068d29355f0767a97bad7f90e3be73f546))
* 实现授权功能 ([5b8d8ee](https://github.com/onexstack/miniblog/commit/5b8d8eedd3d7b5c2967895fbd91c56e59dc58a48))
* 实现版本号打印功能 ([a78f143](https://github.com/onexstack/miniblog/commit/a78f14328407e7e23837bdd85d54dc7456298c2b))
* 实现简洁架构的Biz层 ([8104b99](https://github.com/onexstack/miniblog/commit/8104b99e651f98e8de9ec9a71e63dd8f30fe71df))
* 实现简洁架构的Handler层 ([59c5ff2](https://github.com/onexstack/miniblog/commit/59c5ff20f505e6b57af7bd9dd1d7fd69a2578424))
* 实现简洁架构的Store层 ([47b428a](https://github.com/onexstack/miniblog/commit/47b428a839c93f2d3360cdcc84e5bbbfcab4737f))
* 实现认证功能 ([0cb2f72](https://github.com/onexstack/miniblog/commit/0cb2f72f9130d7e95c1a19aecf13965d653a0da0))
* 实现运行时代码 ([58eaf44](https://github.com/onexstack/miniblog/commit/58eaf44bbc0d29685f8516212d10630b6734bf14))
* 实现配置功能 ([cca39b7](https://github.com/onexstack/miniblog/commit/cca39b7b7ff9c7fcafe5bac0e329d17d029a32b1))
* 强化MariaDB部署方案，解决镜像拉取问题 ([9cd943f](https://github.com/onexstack/miniblog/commit/9cd943f267be593fc4cea0207de989591a89528a))
* 支持优雅关停功能 ([34bd1f1](https://github.com/onexstack/miniblog/commit/34bd1f170ea647009b9427eedf2094300b02f860))
* 支持错误码 ([132fb7a](https://github.com/onexstack/miniblog/commit/132fb7a083a9d89011f1a62b383661219d753dc7))
* 支持默认值设置功能 ([a66f42f](https://github.com/onexstack/miniblog/commit/a66f42f1f20c40826c59612f2138d30d7def8dec))
* 添加Bypass认证中间件（放通所有认证） ([75eeb90](https://github.com/onexstack/miniblog/commit/75eeb903297b273cfbf6beb304868f104716a15b))
* 添加gRPC拦截器 ([87bd2fb](https://github.com/onexstack/miniblog/commit/87bd2fb80119633611b9384b0bd27def392b26c8))
* 添加完整的MariaDB+应用部署支持 ([6724637](https://github.com/onexstack/miniblog/commit/672463730048d04c697ee608db8652ae11da31dd))
* 添加日志包log ([f05e989](https://github.com/onexstack/miniblog/commit/f05e98994ada4a42767b1c1b1ae6ac630bac9c7c))
* 添加生产环境部署脚本 ([9cb873c](https://github.com/onexstack/miniblog/commit/9cb873c284d6252e12a4c433ecd7a053ce4309db))
* 第一次提交 ([f52c7bd](https://github.com/onexstack/miniblog/commit/f52c7bdaf1cdc6bcab31ea038f0fea468967c559))
* 软件架构升级 ([22a020c](https://github.com/onexstack/miniblog/commit/22a020c9bd76e5aea2303e2f867256893916a162))


### Performance Improvements

* 性能优化第2步 - 优化isValidUsername函数性能 ([e9441e7](https://github.com/onexstack/miniblog/commit/e9441e7ac7db2228ff9b4a8113900a04f263c602))
* 性能优化第3步 - 优化同类函数性能 ([1b0e2bb](https://github.com/onexstack/miniblog/commit/1b0e2bba3b41e1a04a07c924df8b2ea4623aff97))


### BREAKING CHANGES

* 涉及docker文件与action文件



