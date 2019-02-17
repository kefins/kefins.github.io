hexo generate
cp -R public/* .deploy/kefins.github.io
cd .deploy/kefins.github.io
git add .
git commit -m “update”
git push origin master
