# gitpod-k3s-helm-installer

## 1. Install k3s binary

```shell
$ cd /usr/local/bin
$ sudo curl -sSLO https://github.com/rancher/k3s/releases/download/v1.18.8%2Bk3s1/k3s
$ sudo chmod +x k3s
```


## 2. Run `gitpod.sh`

```shell
$ sudo ./gitpod.sh gitpod.example.com gitlab.exemple.com 2ce8bfb95d9a1e0ed305427f35e10a6bdd1eef090b1890c68e5f8370782d05ee a5447d23643f7e71353d9fc3ad1c15464c983c47f6eb2e80dd37de28152de05e
```

See `sudo ./gitpod.sh -h` for details.
