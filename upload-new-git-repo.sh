fullrepo="${1:-jrvalverde/SPanalysis}"
branch="${2:-main}"
method="${3-ssh}"

user="${fullrepo%/*}"
repo="${fullrepo#*/}"
email="${user}@cnb.csic.es}"		### NOTE ### this needs customizing

echo "Initializing GIT directory using main as main branch"
#git init -b main
# for older git CLI use
git init 

echo "Setting GIT head to main"
git symbolic-ref HEAD refs/heads/main


echo "Selecdting repository github:${user}/${repo} as $email"
# configure user and e-mail
git config --global user.name "${user}"
git config --global user.email "${email}"

echo "Selecting origin as ${user}/${repo} using ${method}"
# first ensure there is not an 'origin' already selected
git remote remove origin

if [ "$method" = "https" ] ; then
    # to do it over HTTPS (better avoided since the dawn of 2FA
    git remote add origin https://github.com/jrvalverde/"$repo".git
elif [ "$method" = "ssh" ] ; then
    # to do it over SSH
    git remote add origin git@github.com:"${user}/${repo}".git
else
    echo "unknown method, exiting..."
    exit
fi

# check if it is OK
echo 
echo "CHECK IF IT LOOKS OK"
echo 
git remote -v
echo
echo "Did you see...???"
echo "origin  git@github.com:${user}/${repo}.git (fetch)"
echo "origin  git@github.com:${user}/${repo}.git (push)"
read -p "Push RETURN to continue or ^C to stop" ans



# before adding anything, ensure we have any files already in
# the repository (e.g. README.md and LICENSE may be added
# automatically upon repository creation)
echo "Syncing local copy with remote copy"
git pull origin "$branch"


echo "Adding ALL files in current directory"
git add -v .
# Adds the files in the local repository and stages them for commit. 
# To unstage a file, use 'git reset HEAD YOUR-FILE'.


echo "Setting GIT commit message"
git commit -m "Batch uploaded"
# Commits the tracked changes and prepares them to be pushed to a 
# remote repository. To remove this commit and modify the file, use 
# 'git reset --soft HEAD~1' and commit and add the file again.

echo "Selecting ${branch} as default GIT branch"
git branch -M "$branch"

# and now send all the committed changes to the remote server
echo "Saving ALL contents of current directory to the remote repository"
git push origin "${branch}"

# just paranoia, re-get the repository
echo "Updating the local repository contents from the remote repository"
git pull origin "${branch}"

