# aws-VPN-install
在aws上安装VPN的脚本

### 使用说明

1. 在 aws 上新开一个 Ubuntu Server 14.04 LTS 的实例，使用现有实例也可以
2. 配置安全组端口
  ![image](http://imgchr.com/images/QQ20151011-0.jpg)
3. 待实例启动后用 ssh 登录，在终端运行安装脚本: 
```bash
# 先切换到su用户
sudo su
# 安装脚本
sh <(curl https://goo.gl/oysXfg -L)
```

Good Luck!
