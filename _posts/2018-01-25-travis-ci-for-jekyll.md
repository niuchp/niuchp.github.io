---
layout: post
title: 用 Travis CI 免费自动构建和部署 Jekyll
categories: Jekyll
description: 手动构建和发布 Jekyll 繁琐又费时，利用 Travsi CI 来解放自己的时间和双手。
keywords: jekyll, travis-ci
---

>前一段时间搭建了个人博客，一直说要记录一下搭建过程，由于懒拖到现在……我的博客的搭建过程分为两阶段，第一阶段是利用 Github Pages 蹭免费环境，启动博客；第二阶段是利用 Travsi 持续集成，把环境迁到自己的云服务器。之所以迁到自己的云服务器，主要原因是 Github Pages 禁止百度蜘蛛，意味着百度不能收录网站，搜索站点名称的时候就搜索不到，这对于我这种喜欢“炫耀”的银来说必须不能接受。本文介绍在云服务器中搭建博客的完整过程。

整个搭建过程思路如下：

1. fork 博客到 Github ，修改博客属性
2. 本地 Markdown 编写博客，push md 文件到 Github
2. 配置 Travis CI 执行自动编译，生成 html 文件
3. 编译后 Travis CI push html文件到新的 Github 仓库
4. Travis CI 重启云服务器中的容器，拉取 Github 中的 html 文件完成更新  



### 1. 利用 Github Pages 搭建个人博客

利用 Github Pages 搭建个人博客在网上已经有很多资料了，有的人可能会觉得这是在占小便宜，其实完全是多虑了， Github 是鼓励个人建站滴，所以放下大胆的享受红利吧。


想要享受 Github 的红利当然前提条件是要有 Github 账户，注册方法就不提了，我们直接开始 fork 博客模板。

这里我使用的是大佬[马壮](https://github.com/mzlogin/mzlogin.github.io)修改样式后的模板，fork 以后需要做以下修改：  


1. 正确设置项目名称与分支。

    按照 GitHub Pages 的规定，名称为 username.github.io 的项目的 master 分支，或者其它名称的项目的 gh-pages 分支可以自动生成 GitHub Pages 页面。

2. 修改域名。

    如果你需要绑定自己的域名，那么修改 CNAME 文件的内容；如果不需要绑定自己的域名，那么删掉 CNAME 文件。

3. 修改配置。

    网站的配置基本都集中在 _config.yml 文件中，将其中与个人信息相关的部分替换成你自己的，比如网站的 url、title、subtitle 和第三方评论模块的配置等。

4. 评论模块:  
    目前支持 disqus、gitment 和 gitalk，选用其中一种就可以了。可参看以前的博文 [「jekyll中添加gitment留言板」](https://kago.site/2017/12/09/gitment/)。


5. 删除原有的文章与图片。  

    如下文件夹中除了 template.md 文件外，都可以全部删除，然后添加你自己的内容。  
        _posts 文件夹中是已发布的博客文章。  
        _drafts 文件夹中是尚未发布的博客文章。  
        _wiki 文件夹中是已发布的 wiki 页面。  
        images 文件夹中是文章和页面里使用的图片。  

6. 修改「关于」页面。

    pages/about.md 文件内容对应网站的「关于」页面，里面的内容多为个人相关，将它们替换成你自己的信息，包括 _data 目录下的 skills.yml 和 social.yml 文件里的数据。

修改完后，增加 CNAME 中的域名与 Github Pages 解析关系，登录到购买域名的网站增加域名到 192.30.252.153 的解析。其中， 192.30.252.153 是Github Pages 的服务器地址。接下来，就可以打开浏览器访问你的博客啦~  

Clone 你的网站代码库到本地，使用常见的编辑器（本人使用的是 vs code ）写博客，然后再push到 Github 即可。由于该该博客模板是利用 Jekyll 实现的静态网站，支持 Markdown ，这简直是太方便了，按照 Markdown 的语法尽情的写博客就好了， Github Pages 会自动识别 Markdown 格式的。

### 2. 利用 Travis 持续集成

#### 2.1 添加 Github 仓库至 Travis

利用 Travis 部分要感谢 [漠然](https://mritd.me/) 在博客中分析的他的实现方法。  

注册 Travis CI 账号，然后点击最左侧 + 按钮添加项目  

![增加仓库](/images/posts/travis/增加仓库.png)  

选择添加到 Travis 的仓库  

![选择仓库](/images/posts/travis/选择仓库.png)  

点击仓库旁的设置

![配置仓库](/images/posts/travis/配置仓库.png)  

#### 2.2 创建.travis.yaml
在博客的根路径下创建 .travis.yaml 配置文件，实现基本集成配置：
```yaml
language: ruby
rvm:
- 2.3.3
script:
- bundle install
- bundle exec jekyll build
branches:
  only:
  - master
env:
  global:
  - NOKOGIRI_USE_SYSTEM_LIBRARIES=true
```
更多travis.yaml配置参考官方文档 <https://docs.travis-ci.com/>  

#### 2.3 添加 deploy keys 

在 .travis.yaml 中进行加密配置，是为了使 Travis CI 可以免密码访问 Github 

生成密钥对，并添加公钥至 Github 的Deploy keys  
```bash
ssh-keygen -t rsa -C "youremail@example.com"  
```
![deploy_keys](/images/posts/travis/deploy_keys.png) 

#### 2.4 安装并登陆travis

此步骤主要是为了生成 travis 的 keys

安装
```bash
gem install travis
travis login --auto
Successfully logged in as niuchp!
```

#### 2.5 加密

在加密之前我们先在项目根目录下需有 .travis.yaml 文件。加密的就是第一步生成的密钥id_rsa

拷贝在 2.3 步骤中生成密钥对至项目根目录下，并执行：
```bash
travis encrypt-file ssh_key --add
```

这时候看最后一句**Commit all changes to your .travis.yml.。

我们的 .travis.yaml 文件中多了一句:(私人内容使用XXX代替)

- openssl aes-256-cbc -K $encrypted_XXXXXXXX_key -iv $encrypted_XXXXXXXX_iv -in id_rsa.enc -out ~/.ssh/id_rsa -d

例如：
```yaml
language: ruby
rvm:
- 2.3.3
before_install:
- openssl aes-256-cbc -K $encrypted_xxxxxxx_key -iv $encrypted_xxxxxxx_iv -in id_rsa.enc -out ~/.ssh/id_rsa -d
- chmod 600 ~/.ssh/id_rsa
script:
- bundle install
- bundle exec jekyll build
env:
  global:
  - NOKOGIRI_USE_SYSTEM_LIBRARIES=true
```
再次查看我们的 Travis CI 网页，发现多了一些变化

![加密](/images/posts/travis/加密.png)

- 记得要删除 id_rsa 文件，私钥文件已经由 id_rsa.enc 替代  

#### 2.6 配置自动更新

自动更新部分是利用 Travis CI push 编译后的文件至一个新的代码库，重启容器触发 git pull 实现的。

Travis CI push 静态文件到 Github 通过 Github 的 token 实现授权，代码如下
```yaml
after_success:
- git clone https://github.com/niuchp/kago.site.git
- cd kago.site && rm -rf * && cp -r ../_site/* .
- git config user.name "niuchp"
- git config user.email "niuchp@126.com"
- git add --all .
- git commit -m "Travis CI Auto Builder"
- git push --force https://$JEKYLL_GITHUB_TOKEN@github.com/niuchp/kago.site.git master
- ssh root@kago.site "docker restart kago_site"
```
- 注意： 配置文件中的kago.site.git为新仓库！

其中，JEKYLL_GITHUB_TOKEN 是从 Github 授权得到的，然后给于相应权限即可

![travis_deploy_keys](/images/posts/travis/travis_deploy_keys.png)

得到JEKYLL_GITHUB_TOKEN后在 Travish CI的项目配置中添加环境变量$JEKYLL_GITHUB_TOKEN 如下图:

![env](/images/posts/travis/env.png)

完整的 .travis.yaml 配置文件如下：
```yaml
language: ruby
rvm:
- 2.3.3
before_install:
- openssl aes-256-cbc -K $encrypted_xxxxxxx_key -iv $encrypted_xxxxxxx_iv -in id_rsa.enc -out ~/.ssh/id_rsa -d
- chmod 600 ~/.ssh/id_rsa
script:
- bundle install
- bundle exec jekyll build
after_success:
- git clone https://github.com/niuchp/kago.site.git
- cd kago.site && rm -rf * && cp -r ../_site/* .
- git config user.name "niuchp"
- git config user.email "niuchp@126.com"
- git add --all .
- git commit -m "Travis CI Auto Builder"
- git push --force https://$JEKYLL_GITHUB_TOKEN@github.com/niuchp/kago.site.git master
- ssh root@kago.site "docker restart kago_site"
branches:
  only:
  - master
env:
  global:
  - NOKOGIRI_USE_SYSTEM_LIBRARIES=true
addons:
  ssh_known_hosts: kago.site
```

### 3. 配置 docker 容器

Travis CI 持续集成后会重启云服务器中的 docker 容器，触发 git pull 完成更新。

Dockerfile

```dockerfile
FROM nginx:1.13.6-alpine 

LABEL maintainer="Barry New <niuchp@126.com>"

ARG TZ='Asia/Shanghai'

ENV TZ ${TZ}

RUN apk upgrade --update \
    && apk add bash git \
    && rm -rf /usr/share/nginx/html \
    && git clone https://github.com/niuchp/kago.site.git /usr/share/nginx/html \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && rm -rf /var/cache/apk/*

ADD entrypoint.sh /entrypoint.sh
COPY default.conf /etc/nginx/conf.d/

WORKDIR /usr/share/nginx/html

CMD ["/entrypoint.sh"]
```
entrypoint.sh

```bash
#!/bin/bash

git pull
nginx -g "daemon off;"
```

default.conf

```conf
server {
    listen       443;
    server_name  localhost;
    ssl on;
    ssl_certificate  /usr/share/nginx/ssl/fullchain.cer;
    ssl_certificate_key  /usr/share/nginx/ssl/server.key;
    #charset koi8-r;
    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
```

到此，整个配置过程就结束了，可以通过 git push 触发 Travis CI 进行测试。

