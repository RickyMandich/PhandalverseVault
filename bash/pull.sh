git fetch --all
echo "_____________"
git status
echo "_____________"
git pull
echo "_____________"
echo "last commit:    $(git log -1 --pretty=%s)"
