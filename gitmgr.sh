#!/usr/bin/env bash
#
#

### DEFAULTS ###
repository="jrvalverde/SPanalysis"
branch="main"
method="ssh"
email="jrvalverde@cnb.csic.es}"


# get and process command line arguments
function get_args()
{
    unset extra_args
    declare -g -a extra_args		# global array
    local tmp
    local parameter
    local value
    #echo "get_args()"
    #echo "Parameters are '$*'"
    until [ -z "$1" ]
    do
        tmp="$1"
        #echo "Processing parameter: '$tmp'"
        if [ "${tmp:0:1}" = '-' ] ; then
            tmp="${tmp:1}"		# remove leading '-'
	    # check if it has a second leading '-' (supposedly a long option)
	    if [ "${tmp:0:1}" = '-' ] ; then
                tmp="${tmp:1}"		# Finish removing leading '--'
	    fi
	    #echo "$tmp ${tmp:0:1}"			### DBG ###
	    # we'll treat the same '-' and '--' options
	    
	    # detect special cases:
	    #	options without name (- -- --=something) cannot save a
	    #   subsequent value into a 'noname' variable: set them 
	    #	separately
	    if [[ -z "$tmp" || "${tmp:0:1}" == *'=' ]] ; then
	        #echo "$tmp ${tmp:0:1}"			### DBG ###
	        # add them to extra_args, remove and proceed to next
		extra_args+=( "$1" )
		shift
		continue;
	    fi
	    
	    # Now we have two possibilities:
	    # the option was of the type 
            #	[-[-]]o[pt]=val 
            # or 
            #	[-[-]]o[pt] val
	    # let us now tell them apart
	    if [ `expr index "$tmp" "="` -gt 1 ] ; then 
	        #echo "opt $tmp has an ="		### DBG ###
	        # it has a name and an '=', must be a [-]-opt=val
		# if we did 'eval $tmp' it would fail with embedded spaces
		parameter="${tmp%%=*}"     # Extract name (remove = and after).
		parameter="${parameter//-/_}"	# change any middle '-' to '_'
        	value="${tmp#*=}"         # Extract value (remove up to and including =).
	    else
		# there is no '=', it must be [-]-opt val
		#echo "opt $tmp stands alone"		### DBG ###
		parameter="$tmp"
	        parameter="${parameter//-/_}"	# change any middle '-' to '_'
		shift		# get next argument
		# value can be '' or start with a '-' (e.g. -1.2e3) or a '='
		value="$1"
	  fi
	  #echo "Parameter: '$parameter', value: '$value'" ### DBG ###
	  # do the assignment
	  #echo "assigning '$parameter'='$value'"	### DBG ###
          eval "$parameter"="$value"
          shift
	else
	    # If a parameter does not start with '-'
	    # we will not assign this argument because we do not know
	    # which variable name to give it.
	    # But we can save it in a 'leftovers' array
	    extra_args+=( "$tmp" )
	    shift
	fi
    # echo "extra=${extra_args[@]}"			### DBG ###
    done
    # echo "extra arguments found:${extra_args[@]}"	### DBG ###
}


function is_ok() {
    val="$1"
    case "$val" in
        Y|y|Yes|yes|T|t|True|true|OK|ok)
	    return 0		### bash success
	    ;;
	N|n|No|no|F|f|False|False|KO|ko)
	    return 1
	    ;;
	*)
	    return 2
    esac
}


function is_ko() {
    val="$1"
    case "$val" in
        Y|y|Yes|yes|T|t|True|true|OK|ok)
	    return 1
	    ;;
	N|n|No|no|F|f|False|False|KO|ko)
	    return 0		### bash success
	    ;;
	*)
	    return 2
    esac
}

function usage()
{
    me=`basename $0`
    cat <<END
	$me [--repository=u/r] [--branch=b] [--method=m] [--email=u@h]
	    [--initialize=F] [--user=u] [--repo=r] [--local-update=F]
	    [--remote-update=F] [--log=opt] [--message="the msg"]
	    [--config=F]
	    [status] [diff] 
	
	repository	the repository to work with (default is
		$defrepository)
	branch		the branch to work in (default is $defbranch)
	method		the connection method, https or ssh (default 
		is $defmethod)
	email		the e-mail to use to sign commits
	initialize	whether we want to initialize the current
		directory if not already initialized (default False)
	user		repository user (will override value in --repository)
	repo		repository name (will override value in --repository)
	local-update
	local_update	update local copy to be in sync with remote repository
			(default is False unless initialize is True)
	remote-update
	remote_update	update remote repository from the local copy (default
			is False)
	patch		show the differences of each commit (default False)
	log		show additional information, depending on 'opt':
		''	show all log entries
		number	show last (positive) number entires
		stat	show a few stats for each commit
		graph	show a text graph of the repository
		g       show a text graph with just one line for commit
		(default is '', show all log entries)
	message		message to use for commit default ('Batch upload')
	config		create a config file (default False)
	status		show status
	diff		show differences between remote and local copies
		(without modifying anything)
	help		print this help (default False)

END
}


function git_initialize() {
    
    echo "Initializing GIT directory using 'main' as the main branch"
    #git init -b main
    # for older git CLI use
    git init 

    echo "Setting GIT head to main"
    git symbolic-ref HEAD refs/heads/main

}


function git_file_configure() {
cat > .gitconfig <<END
[user]
  name = "$user"
  email = "$email"
[apply]
  whitespace = fix
[core]
  excludesfile = ~/.gitignore
END

cat > .gitignore <<END
# see https://github.com/github/gitignore for ideas
    *.DS_Store
    *~
    *.log
    *.zip
    *.pkg
    *.rar
    tmp/
    hs_err_pid*
    replay_pid*
    __pycache__/
    *.py[cod]
    *$py.class

END

}


function git_set_user() {
    local user="$1"
    local email="$2"
    # configure user and e-mail
    if [ ! -z "$user" ] ; then
        git config --global user.name "${user}"
    fi
    if [ ! -z "$email" ] ; then
        git config --global user.email "${email}"
    fi
}


function git_set_origin() {
    local user="$1"
    local repo="$2"
    local method="$3"

    # select origin repository
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
}


function git_local_update() {
    local branch="$1"
    
    echo "Syncing local copy with remote copy"
    git pull origin "$branch"
}


function git_remote_update() {
    local branch="$1"
    local message="$2"
    
    echo "Adding ALL files in current directory"
    git add -v .
    # Adds the files in the local repository and stages them for commit. 
    # To unstage a file, use 'git reset HEAD YOUR-FILE'.


    echo "Setting GIT commit message"
    git commit -m "$message"
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
}


############################################################################
#printenv | sort > kkk
get_args "$@"		# process command line arguments
#printenv | sort > KKK
#echo "args=["${@}"]"
#echo "extra_args=["${extra_args[@]}"]"
#echo "re=$repository"
#exit

# assign remaining args
for i in "${extra_args[@]}" ; do
    eval "$i"="$i"
done
#echo $#

if [ ! -z "${help+x}" ] ; then usage ; exit ; fi
if is_ok "$help" ; then usage ; exit 0 ; fi

# Sanity checks
if [ "$repository" = "" ] ; then
    echo "cannot work without a repository"
    exit 1
fi
if [ "$branch" = "" ] ; then
    echo "cannot work without a branch"
    exit 1
fi


# compute derived variables (note: a repo "user/user" may be stated as "user")
user="${user:-${repository%/*}}"
repo="${repo:-${repository#*/}}"

# Check if we are in a GIT repository (required for any further commands)
if [ ! -d .git ] ; then
    if is_ko "$initialize" ; then exit 0 ; fi	# not a repo and must not be
    if is_ok "$initialize" ; then
        git_initialize
    else
	echo "Current directory is not a GIT directory"
	echo "Do you want to initialize "
	echo "    "`pwd`
	read -p "as a GIT directory for $user/$repo? [N/y] " initialize
	if is_ok "$initialize" ; then
	    git_initialize
	else
	    exit 0	# not a repo, cannot continue
	fi
    fi
fi

# create a config file
# we do not need this to be a repo to create a config file, but...
if is_ok config ; then
    git_file_configure "$user" "$email"
fi

# now that we are in a GIT directory, we can proceed
git_set_user "$user" "$email"

# configure default username and email
echo "Selecting repository github:${user}/${repo} as $email"

git_set_origin "$user" "$repo" "$method"

if is_ok "$initialize" || is_ok "$local_update" ; then
    # before adding anything, ensure we have any files already in
    # the repository (e.g. README.md and LICENSE may be added
    # automatically upon repository creation)
    git_local_update "$branch"
fi

if is_ok "$remote_update" ; then
    # if $message was set in the command line, use it
    msg="${message:-Batch uploaded}"
    git_remote_update "$branch" "$msg"
fi


if is_ok "$patch" ; then git log -p ; fi

# substitute log by x only if log is set: is log is not set, no substitution
# takes place, log becomes '' and -z is true, if log is set, it is changed to
# 'x' and -z is false
if [ -z "${log+x}" ] ; then 
    if   [ "$log" = "" ] ; then git log
    elif [ "$log" = "stat" ] ; then git log --stat
    elif [ "$log" = "graph" ] ; then git log --graph
    elif [ "$log" = "g" ] ; then git log --graph --oneline
    elif [[ $var =~ ^?[0-9]+$ ]] ; then git log -$log	# positive integer
    else git log
    fi
fi


# if there are any remaining unprocessed arguments, pass them directly to
# git
if [ ${#extra_args} -gt 0 ] ; then
    echo "about to execute 'git "${extra_args[@]}"'"
    read -p "Proceed? [N/y] " ans
    if is_ok "$ans" ; then
        git "${extra_args[@]}"
    fi
fi
