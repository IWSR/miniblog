#!/bin/bash

# MiniBlog Docker 服务管理脚本

# 设置颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_help() {
    echo "MiniBlog Docker 服务管理脚本"
    echo ""
    echo "用法: $0 [命令] [模式]"
    echo ""
    echo "命令:"
    echo "  start     启动服务"
    echo "  stop      停止服务"
    echo "  restart   重启服务"
    echo "  status    查看服务状态"
    echo "  logs      查看应用日志"
    echo "  db-logs   查看数据库日志（仅MariaDB模式）"
    echo "  db        连接到数据库（仅MariaDB模式）"
    echo "  clean     清理所有容器和数据（危险操作）"
    echo "  backup    备份数据库（仅MariaDB模式）"
    echo "  stats     查看资源使用情况"
    echo "  test      运行部署测试"
    echo "  help      显示此帮助信息"
    echo ""
    echo "模式（可选）:"
    echo "  memory    内存数据库模式"
    echo "  mariadb   MariaDB数据库模式"
    echo "  auto      自动检测模式（默认）"
    echo ""
    echo "示例:"
    echo "  $0 status              # 自动检测并显示状态"
    echo "  $0 logs mariadb        # 查看MariaDB模式的应用日志"
    echo "  $0 restart memory      # 重启内存数据库模式"
    echo ""
}

# 检测部署模式
detect_mode() {
    if docker ps | grep -q "miniblog-app-mariadb"; then
        echo "mariadb"
    elif docker ps | grep -q "miniblog-memory"; then
        echo "memory"
    else
        echo "none"
    fi
}

# 获取容器名称
get_containers() {
    local mode=$1
    if [ "$mode" = "mariadb" ]; then
        APP_CONTAINER="miniblog-app-mariadb"
        DB_CONTAINER="miniblog-mariadb"
    elif [ "$mode" = "memory" ]; then
        APP_CONTAINER="miniblog-memory"
        DB_CONTAINER=""
    else
        APP_CONTAINER=""
        DB_CONTAINER=""
    fi
}

start_service() {
    local mode=$1
    echo -e "${BLUE}启动MiniBlog服务 ($mode 模式)...${NC}"
    
    get_containers $mode
    
    if [ "$mode" = "mariadb" ]; then
        echo "启动数据库容器..."
        docker start $DB_CONTAINER 2>/dev/null || echo "数据库容器启动失败或已在运行"
        sleep 5
        echo "启动应用容器..."
        docker start $APP_CONTAINER 2>/dev/null || echo "应用容器启动失败或已在运行"
    elif [ "$mode" = "memory" ]; then
        echo "启动应用容器..."
        docker start $APP_CONTAINER 2>/dev/null || echo "应用容器启动失败或已在运行"
    fi
    
    echo -e "${GREEN}✅ 服务启动完成${NC}"
}

stop_service() {
    local mode=$1
    echo -e "${BLUE}停止MiniBlog服务 ($mode 模式)...${NC}"
    
    get_containers $mode
    
    if [ -n "$APP_CONTAINER" ]; then
        docker stop $APP_CONTAINER 2>/dev/null || echo "应用容器停止失败或未运行"
    fi
    
    if [ -n "$DB_CONTAINER" ]; then
        docker stop $DB_CONTAINER 2>/dev/null || echo "数据库容器停止失败或未运行"
    fi
    
    echo -e "${GREEN}✅ 服务停止完成${NC}"
}

restart_service() {
    local mode=$1
    echo -e "${BLUE}重启MiniBlog服务 ($mode 模式)...${NC}"
    stop_service $mode
    sleep 2
    start_service $mode
}

show_status() {
    local mode=$1
    echo -e "${BLUE}MiniBlog服务状态 ($mode 模式):${NC}"
    echo ""
    
    echo "容器状态:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep miniblog
    
    if [ "$mode" = "mariadb" ]; then
        echo ""
        echo "网络状态:"
        docker network ls | grep miniblog
        
        echo ""
        echo "数据卷状态:"
        docker volume ls | grep miniblog
    fi
    
    echo ""
    echo "端口监听状态:"
    if command -v netstat &> /dev/null; then
        netstat -tlnp 2>/dev/null | grep -E ":(5555|6666|3306)" || echo "未找到相关端口监听"
    else
        echo "netstat命令不可用，跳过端口检查"
    fi
}

show_logs() {
    local mode=$1
    get_containers $mode
    
    if [ -n "$APP_CONTAINER" ] && docker ps | grep -q "$APP_CONTAINER"; then
        echo -e "${BLUE}应用日志 (最近50行):${NC}"
        docker logs --tail 50 $APP_CONTAINER
    else
        echo -e "${RED}❌ 应用容器未运行${NC}"
    fi
}

show_db_logs() {
    local mode=$1
    if [ "$mode" != "mariadb" ]; then
        echo -e "${YELLOW}⚠️  数据库日志仅在MariaDB模式下可用${NC}"
        return
    fi
    
    get_containers $mode
    
    if [ -n "$DB_CONTAINER" ] && docker ps | grep -q "$DB_CONTAINER"; then
        echo -e "${BLUE}数据库日志 (最近50行):${NC}"
        docker logs --tail 50 $DB_CONTAINER
    else
        echo -e "${RED}❌ 数据库容器未运行${NC}"
    fi
}

connect_db() {
    local mode=$1
    if [ "$mode" != "mariadb" ]; then
        echo -e "${YELLOW}⚠️  数据库连接仅在MariaDB模式下可用${NC}"
        return
    fi
    
    get_containers $mode
    
    if [ -n "$DB_CONTAINER" ] && docker ps | grep -q "$DB_CONTAINER"; then
        echo -e "${BLUE}连接到MariaDB数据库...${NC}"
        echo "数据库信息:"
        echo "  数据库: miniblog"
        echo "  用户名: miniblog"
        echo "  密码: miniblog1234"
        echo ""
        docker exec -it $DB_CONTAINER mysql -u miniblog -pminiblog1234 miniblog
    else
        echo -e "${RED}❌ 数据库容器未运行${NC}"
    fi
}

clean_all() {
    local mode=$1
    echo -e "${RED}⚠️  警告: 这将删除所有MiniBlog相关的容器、网络和数据！${NC}"
    echo -e "${RED}⚠️  所有数据将永久丢失！${NC}"
    echo ""
    echo "当前检测到的模式: $mode"
    echo ""
    read -p "确定要继续吗？(输入 'yes' 确认): " confirm
    
    if [ "$confirm" = "yes" ]; then
        echo -e "${BLUE}清理MiniBlog资源...${NC}"
        
        # 停止并删除所有相关容器
        docker stop miniblog-app-mariadb miniblog-mariadb miniblog-memory 2>/dev/null || true
        docker rm miniblog-app-mariadb miniblog-mariadb miniblog-memory 2>/dev/null || true
        
        # 删除网络
        docker network rm miniblog-network 2>/dev/null || true
        
        # 删除数据卷
        docker volume rm miniblog-db-data 2>/dev/null || true
        
        # 删除镜像（可选）
        read -p "是否同时删除MiniBlog镜像？(y/N): " delete_image
        if [ "$delete_image" = "y" ] || [ "$delete_image" = "Y" ]; then
            docker rmi miniblog:latest 2>/dev/null || true
        fi
        
        echo -e "${GREEN}✅ 清理完成${NC}"
    else
        echo -e "${YELLOW}操作已取消${NC}"
    fi
}

backup_db() {
    local mode=$1
    if [ "$mode" != "mariadb" ]; then
        echo -e "${YELLOW}⚠️  数据库备份仅在MariaDB模式下可用${NC}"
        return
    fi
    
    get_containers $mode
    
    if [ -n "$DB_CONTAINER" ] && docker ps | grep -q "$DB_CONTAINER"; then
        echo -e "${BLUE}备份数据库...${NC}"
        BACKUP_FILE="miniblog-backup-$(date +%Y%m%d-%H%M%S).sql"
        docker exec $DB_CONTAINER mysqldump -u root -proot123456 miniblog > "$BACKUP_FILE"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ 数据库备份完成: $BACKUP_FILE${NC}"
        else
            echo -e "${RED}❌ 数据库备份失败${NC}"
        fi
    else
        echo -e "${RED}❌ 数据库容器未运行${NC}"
    fi
}

show_stats() {
    local mode=$1
    echo -e "${BLUE}资源使用情况 ($mode 模式):${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" | grep miniblog
}

run_test() {
    local mode=$1
    echo -e "${BLUE}运行部署测试 ($mode 模式)...${NC}"
    if [ -f "docker-deployment/scripts/test-deployment.sh" ]; then
        ./docker-deployment/scripts/test-deployment.sh $mode
    else
        echo -e "${RED}❌ 找不到测试脚本 docker-deployment/scripts/test-deployment.sh${NC}"
    fi
}

# 主逻辑
COMMAND=$1
MODE=${2:-"auto"}

# 如果是auto模式，自动检测
if [ "$MODE" = "auto" ]; then
    DETECTED_MODE=$(detect_mode)
    if [ "$DETECTED_MODE" = "none" ]; then
        echo -e "${YELLOW}⚠️  未检测到运行中的MiniBlog容器${NC}"
        echo ""
        echo "请先部署MiniBlog系统："
        echo "  内存数据库: ./docker-deployment/scripts/deploy-memory.sh"
        echo "  MariaDB数据库: ./docker-deployment/scripts/deploy-mariadb.sh"
        echo ""
        exit 1
    fi
    MODE=$DETECTED_MODE
fi

case "$COMMAND" in
    start)
        start_service $MODE
        ;;
    stop)
        stop_service $MODE
        ;;
    restart)
        restart_service $MODE
        ;;
    status)
        show_status $MODE
        ;;
    logs)
        show_logs $MODE
        ;;
    db-logs)
        show_db_logs $MODE
        ;;
    db)
        connect_db $MODE
        ;;
    clean)
        clean_all $MODE
        ;;
    backup)
        backup_db $MODE
        ;;
    stats)
        show_stats $MODE
        ;;
    test)
        run_test $MODE
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo -e "${RED}❌ 未知命令: $COMMAND${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac