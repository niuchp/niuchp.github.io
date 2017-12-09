---
layout: post
title: jekyll中添加gitment留言板
categories: jekyll
description: 在博客中添加gitment用于留言，留言内容记录至issue中
keywords: jekyll, gitment
---

# 前言
最近使用jekyll搭建了个人博客（https://kago.site），参考网友资料为博客添加了gitment作为留言板，罗列一下基本步骤，希望可以帮到大家。

# 申请Github OAuth Application
Github头像下拉菜单 > Settings > 左边Developer settings下的OAuth Apps > New OAuth App，填写相关信息：
1. Application name, Homepage URL, Application description 都可以随意填写
2. Authorization callback URL 一定要写自己Github Pages的URL
3. 填写完上述信息后按Register application按钮，得到Client ID和Client Secret
4. 记录Client ID和Client Secret，稍后会用到

# 在jekyll添加调用gitment
在_layout/目录下的 post.html, 添加一下代码：
```
<div id="gitmentContainer"></div>
<link rel="stylesheet" href="https://imsun.github.io/gitment/style/default.css">
<script src="https://imsun.github.io/gitment/dist/gitment.browser.js"></script>
<script>
var gitment = new Gitment({
    owner: 'Your GitHub username',
    repo: 'The repo to store comments',
    oauth: {
        client_id: 'Your client ID',
        client_secret: 'Your client secret',
    },
});
gitment.render('gitmentContainer');
</script>
```
需要修改的有4个地方

1. Your GitHub username：填写你的Github Pages博客所在的github账户名
2. The repo to store comments：填写用来存放评论的github仓库，由于评论是 通过issues来存放的，个人建议这里可以直接填Github Pages个人博客所在的仓库
3. Your client ID：上一步所申请到的应用的Client ID
4. Your client secret：上一步所申请到的应用的Client Secret

填写完这4项把代码push到github。

# 为博客初始化留言板
gitment的原理是为每一遍博文以其URL作为标识创建一个github issue， 对该篇博客的评论就是对这个issue的评论。因此，需要对博客初始化， 初始化后，评论信息会添加到github上对应的issue。
1. 上传代码成功后，博客文章下方会出现留言板，显示```Error: Comments Not Initialized```,提示需要初始化
2. 点击```login with github```,使用自己github账号登录，错误信息会变成```Initialize Comments```按钮
3. 点击按钮，完成对博文的初始化，同时创建相应的issue
![gitment](/images/posts/gitment/gitment.png)

