---
title: 基于docker部署wordpress
date: 2019-02-18 23:53:00
tags: [wordpress,docker,docker-compose]
categories: build-blog
---
**2019年初**，想自己搭建一个博客平台，撰写一些自己的心得总结，方案选择上基本没有犹豫，近几年WordPress已经独树一帜，在网站建设方面可谓独领风骚，深受站长的喜爱，国内的不少知名网站均基于WordPress来构建，因此也计划基于WordPress来建建设一个博客平台。
&emsp;&emsp;但是在具体操作时却泛起了多种思路，最基本思路自然是的基于LAMP环境建设，这是最为通用的方式了。但是考虑到接触LXC已经有一段时间了，何不趁此机会基于容器来实践一把呢？一方面此方案确实有其优越性，在部署、维护方面有其独特的优越性；另一方面可以借此机会实践一下容器的编排技术。
&emsp;&emsp;首先给大家介绍一下硬件背景，稍微阐述一下我苦逼的折腾过程。家中有一台自己DIY的一台黑群晖NAS服务器 ，本来群晖直接安装在物理机上，但在一次升级时不小心把系统给升死了（黑的就是不招人待见！！可黑有黑的乐趣……），由于群晖没接显示器，再次重装又少不了一番折腾，而且还担心数据丢失。一气之下，在服务器上装了一个Win10系统，安装VMWare虚拟机，然后通过虚拟器安装群晖DSM，如此一来，所有数据可以都存放到虚拟磁盘中，备份速度要快很多，但这样会牺牲一定的访问速度，不过最终结果还算差强人意，局域网内10多M的速度还是有保障的，此乃硬件背景。
&emsp;&emsp;在上述硬件条件下，软件方案就面临多种选择，可以考虑直接在群晖虚拟机上折腾，还可以再起一个虚拟机来搭建，我能想到切实可行的至少有如下四种方案：
1. 基于虚拟机中群晖自带的WordPress插件来搭建，后台仍然采用基于Debian的LAMP环境
2. 基于虚拟机中群晖的Docker来搭建
3. 新建一虚拟机，安装一linux系统，搭建LAMP环境来搭建
4. 新建一虚拟机，基于Docker在搭建

&emsp;&emsp;最终选择了第4种方案，不想再折腾群晖系统了，最重要的原因是考虑到数据的重要性，一旦把数据折腾丢了亏大了。另外群晖应该是基于Debian的系统，但已经被官方折腾的面目全非了，不再具备开源系统的通用性，软件安装和配置方面已不合常规，这种折腾还是能省就省吧。
&emsp;&emsp;新建虚拟机基于CentOS系统，此处不再赘述此系统在服务器领域的地位和配置方式，默认为观看此篇博客的人都具备虚拟机的安装以及基本的Linux系统配置基础。
## 安装docker
&emsp;&emsp; Docker从1.13版本之后采用时间线的方式作为版本号，分为社区版CE和企业版EE。社区版是免费提供给个人开发者和小型团体使用的，企业版会提供额外的收费服务，比如经过官方测试认证过的基础设施、容器、插件等。社区版按照stable和edge两种方式发布，每个季度更新stable版本，如17.06，17.09；每个月份更新edge版本，如17.09，17.10。
1. 设置yum源
```bash
$ sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```
2. 安装依赖包
```bash
$ sudo yum install -y yum-utils device-mapper-persistent-data lvm2
```
3. 安装docker-ce
```bash
sudo yum install docker-ce
```
4. 启动docker守护进程并设置为开机启动
```bash
$ sudo systemctl start docker
$ sudo systemctl enable docker
```
5. 验证安装结果
```bash
$ docker version
Client:
 Version:           18.09.0
 API version:       1.39
 Go version:        go1.10.4
 Git commit:        4d60db4
 Built:             Wed Nov  7 00:48:22 2018
 OS/Arch:           linux/amd64
 Experimental:      false
Server: Docker Engine - Community
 Engine:
  Version:          18.09.0
  API version:      1.39 (minimum version 1.12)
  Go version:       go1.10.4
  Git commit:       4d60db4
  Built:            Wed Nov  7 00:19:08 2018
  OS/Arch:          linux/amd64
  Experimental:     false
```


## 安装docker-compose

&emsp;&emsp;docker-compose是Docker容器进行编排的工具，使用python语言编写,与docker/swarm配合度很高，定义和运行多容器的应用，可以一条命令启动多个容器，使用Docker Compose不再需要使用shell脚本来启动容器。
&emsp;&emsp;安装之前，要求已经安装好python环境，此处强烈建议大家升级到python3，直接采用pip命令安装。
```bash
pip install docker-compose
```
此外，还可以采取直接下载的方式安装
```bash
$ sudo curl -L https://github.com/docker/compose/releases/download/1.16.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose

$ sudo chmod +x /usr/local/bin/docker-compose
```
&emsp;&emsp;安装完毕后，看查看docker-compose的版本信息，验证安装结果。
```bash
[root@swarm01 fendo]# docker-compose version
docker-compose version 1.21.2, build a133471
docker-py version: 3.3.0
CPython version: 2.7.5
OpenSSL version: OpenSSL 1.0.2k-fips  26 Jan 2017
```
&emsp;&emsp;关于docker compose的技术文档，还请各位看官移驾到[官网](https://docs.docker.com/compose/)查看，此处仅做简单介绍，后续有需要再对其做详细介绍。docker-compose是一个用来把 docker命令自动化的部署命令，通过docker-compose的配置脚本，可以把所有繁复的docker操作通过一条命令自动化完成。通过编写docker-compose.yml脚本，docker-compose会读取此脚本中的配置，将其转换为对应的docker命令逐条执行，最终完成所有部署。

## docker编排思路
&emsp;&emsp;按照docker的设计思路，应尽量将每个服务放至独立的docker容器中，相互之间会有依赖关系，但运行时绝不会相互影响。Wordpress是使用PHP语言开发的博客平台，用户可以在支持PHP和MySQL数据库的服务器上架设属于自己的网站。基于WordPress搭建博客平台，依赖于有HTTP服务、数据库服务和PHP环境，最理想的编排方案应该分别将这些服务部署在独立的容器中。
- HTTP服务
- SQL服务
- PHP环境
- Wordpress环境

&emsp;&emsp;此处为避免重新编译docker镜像，决定采取直接从docker hub上拉取官方认证的镜像，官方提供的Wordpress镜像中已经集成了PHP环境，因此不需要单独部署一个PHP docker；HTTP服务可以选择Apache或者Nginx，此处选择Nginx；SQL可以选择MySql或者MariaDB，此处选择了MariaDB。总共需要三个docker镜像。
- [WordPress](https://hub.docker.com/_/wordpress)
- [nginx](https://hub.docker.com/_/nginx)
- [mariadb](https://hub.docker.com/_/mariadb)


## 编辑docker-compose.yml脚本

```yml
version: '3'
services:

    mysql:
        image: mariadb
        container_name: mariadb
        ports:
            - '3306:3306'
        volumes:
            - ./sqldb:/var/lib/mysql
        environment:
            - MYSQL_ROOT_PASSWORD=UNJ^)-+YYunfn
            - MYSQL_DATABASE=wordpress
            - MYSQL_USER=wordpress
            - MYSQL_PASSWORD=aqwe123
        networks:
            - backend
        restart: always

    wordpress:
        depends_on:
            - mysql
        image: wordpress:5.0.3-php7.2-fpm
        container_name: wordpress
        ports:
            - '9000:9000'
        volumes:
            #- ./php-fpm:/usr/local/etc/php-fpm.d
            - ./www:/var/www/html
        environment:
            - WORDPRESS_DB_NAME=wordpress
            - WORDPRESS_TABLE_PREFIX=wp_
            - WORDPRESS_DB_HOST=mysql:3306
            - WORDPRESS_DB_USER=wordpress
            - WORDPRESS_DB_PASSWORD=aqwe123
        links:
            - mysql
        networks:
            - frontend
            - backend
        restart: always

    nginx:
        image: nginx:latest
        container_name: nginx
        ports:
            - '16001:80'
            - "11431:443"
        volumes:
            - ./nginx:/etc/nginx/conf.d
            - ./logs/nginx:/var/log/nginx
            - ./www:/var/www/html
            - /var/run/docker.sock:/tmp/docker.sock:ro
        links:
            - wordpress
        networks:
            - frontend
        restart: always

networks:
    frontend:
        #name: frontend
        driver: bridge
    backend:
        #name: backend
        driver: bridge
```

&emsp;&emsp;编辑完docker-compose.yml文件后，还需要设置nginx的配置文件，为方便制作，已经将相关代码全部放至到[github](https://github.com/kefins/docker_wpress)上，可通过git命令直接下载。
```bash
git clone https://github.com/kefins/docker_wpress.git wpress
```
&emsp;&emsp;下载完毕后，切换至wpress目录，直接执行docker-compose命令，启动服务。
```bash
$ docker-compose  up -d
Creating network "wordpress_frontend" with driver "bridge"
Creating network "wordpress_backend" with driver "bridge"
Creating mariadb ... done
Creating wordpress ... done
Creating nginx     ... done
```
&emsp;&emsp;命令执行完毕后，WordPress服务就已完成部署，通过docker命令可以查看docker容器的创建情况。
```bash
$ docker ps
CONTAINER ID        IMAGE                        COMMAND                  CREATED             STATUS              PORTS                                           NAMES
06e0f84bd9ec        nginx:latest                 "nginx -g 'daemon of…"   6 minutes ago       Up 6 minutes        0.0.0.0:16001->80/tcp, 0.0.0.0:11431->443/tcp   nginx
02e623fae167        wordpress:5.0.3-php7.2-fpm   "docker-entrypoint.s…"   6 minutes ago       Up 6 minutes        0.0.0.0:9000->9000/tcp                          wordpress
f663ddd12149        mariadb                      "docker-entrypoint.s…"   6 minutes ago       Up 6 minutes        0.0.0.0:3306->3306/tcp                          mariadb
```

&emsp;&emsp;打开浏览器，输入**x.x.x.x/wp-admin/install.php**，就会看到WordPress的安装界面。至此，就完成了所有的部署工作，可以开始配置WordPress，然后撰写第一篇博客了。














