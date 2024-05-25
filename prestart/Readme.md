
可直接 运行 `bash preStart.sh` 然后根据提示操作

# 注意事项
**首次运行请先执行   `bash preStart.sh backup` 在所有节点备份 `/etc/fstab`  `/etc/sudoers`** 

`bash preStart.sh copymkfsMount`  分发 `mkfsMount.sh` 文件到 各主机

## 挂载相关
各个主机修改 `mkfsMount.sh` 

修改合适后   可以 执行 `bash preStart.sh bashmkfsMount` 一次性挂载, 也可以去各个节点执行 `bash mkfsMount.sh`

## 安装
各个主机修改 `mkfsMount.sh` 

修改合适后 也可以 执行 `bash preStart.sh installall`    一次性安装

## 清除
依据安装文件时候的 `mkfsMount.sh` 选项
清除安装 可执行               `bash preStart.sh clean`              不清除挂载的目录
在个主机 修改合适后  也可执行 `bash preStart.sh bashundomkfsMount`  单独清除挂载的目录 ,也可以去各个节点执行 bash mkfsMount.sh
在个主机 修改合适后  也可执行 `bash preStart.sh cleanall`           一次性清除



## 补充
会生成 `address.txt`  文件用来保存 `ip` 信息，需要手动删除

建立互信步骤: 仅在当前主机的 互信用户 目录下 拷贝 `preStart.sh` 和 `address.txt` 文件 (如不需要保留，则手动删除), 然后使用 互信的用户 执行 `bash preStart.sh trust`

