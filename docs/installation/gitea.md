#### Setup gitea repo

```shell
# Note: This is to setup another git-repo for home uses
1. Go to gitea http://10.0.0.58:3000/andre
2. Create a repo call "homelab"
3. From labtop
$ git remote add gitea http://10.0.0.58:3000/andre/homelab.git
$ git remote -v
$ git push gitea

4. To push to both origins
$ git push origin main & git push gitea main


```

#### Add caocunglen into gitea

```shell
1. Go to gitea http://10.0.0.58:3000/andre
2. Create a repo call "caocunglen"
3. From labtop
$ git remote add gitea http://10.0.0.58:3000/andre/caocunglen.git
$ git remote -v
$ git push gitea


```