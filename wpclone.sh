#!/bin/bash
#
# A lot of this is based on options.bash by Daniel Mills.
# @see https://github.com/e36freak/tools/blob/master/options.bash
# @see http://www.kfirlavi.com/blog/2012/11/14/defensive-bash-programming

readonly PROGNAME=$(basename $0)
readonly PROGVERSION="v0.1"
readonly PROGMODIF=$(stat -c '%y' $0 | sed 's/\.[0-9]*//')
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARGS="$@"


# Preamble {{{

# Exit immediately on error
set -e

# Detect whether output is piped or not.
[[ -t 1 ]] && piped=0 || piped=1
piped=1
# Defaults
force=0
quiet=0
verbose=0
args=()

# }}}
# Helpers {{{

out() {
  ((quiet)) && return

  local message="$@"
  if ((piped)); then
    message=$(echo $message | sed '
      s/\\[0-9]\{3\}\[[0-9]\(;[0-9]\{2\}\)\?m//g;
      s/✖/Error:/g;
      s/✔/Success:/g;
    ')
  fi
  printf '%b\n' "$message";
}
die() { out "$@"; exit 1; } >&2
err() { out " \033[1;31m✖\033[0m  $@"; } >&2
success() { out " \033[1;32m✔\033[0m  $@"; }

# Verbose logging
log() { 
	if [ $verbose -gt 0 ] ; then
		out "$@"
	fi
	}

# Notify on function success
notify() { [[ $? == 0 ]] && success "$@" || err "$@"; }

# Escape a string
escape() { echo $@ | sed 's/\//\\\//g'; }

# Unless force is used, confirm with user
confirm() {
  (($force)) && return 0;

  read -p "$1 [y/N] " -n 1;
  [[ $REPLY =~ ^[Yy]$ ]];
}

ask_param(){
	# $1 = name parameter
	# $2 = default value
	# $3 = question to ask
	NAME=$1
	DEFAULT=$2
	QUESTION=$3
	if [ -n "$QUESTION" ] ; then
		echo "$QUESTION"
	else
		echo "Enter value for [$NAME]?"
	fi
	if [ -n "$DEFAULT" ] ; then
		echo "(Default: $DEFAULT)"
	fi
	read -p "> " RESPONSE;
	if [ -n "$RESPONSE" ] ; then
		eval "$NAME=\"$RESPONSE\""
	else
		eval "$NAME=\"$DEFAULT\""
		RESPONSE="$DEFAULT"
	fi
	log "ask_param: [$1] = [$RESPONSE]"
}

read_wpconfig(){
	# $1 = name parameter
	# $2 = wp-config path
	## define('DB_NAME', 'wp_events'); 	-- type 1
	## $table_prefix  = 'tpl_';			-- type 2

	VALUE=""
	if [ ! -f "$2" ] ; then
		die "Cannot find wpconfig file [$2]"
	fi
	LINE=$(grep "$1" "$2" | grep 'define') 	&& 	VALUE=$(echo $LINE | cut -d"," -f2- | sed "s/)\s*;\s*$//" | sed "s/^\s*//" | sed "s/^.//" | sed "s/.$//");
	if [ -z "$VALUE" ] ; then
		LINE=$(grep "$1" "$2" | grep '=')	&&	VALUE=$(echo $LINE | cut -d"=" -f2- | sed "s/\s*;\s*$//" | sed "s/^\s*//" | sed "s/^.//" | sed "s/.$//");
	fi
	if [ -z "$VALUE" ] ; then
		die "Cannot find value for [$1] in [$2]"
	fi
	eval "$1=\"$VALUE\""
	log "read_wpconfig: [$1] = [$VALUE]"
}

read_sqldump(){
	# $1 = name parameter
	# $2 = sql ndump file
	# INSERT INTO `tpl_options` VALUES (2, 'home', 'http://www.example.com/_template', 'yes'); 

	VALUE=""
	if [ ! -f "$2" ] ; then
		die "Cannot find SQL file [$2]"
	fi
	LINE=$(grep "'$1'" "$2" | grep 'INSERT' | head -1) 	&& 	VALUE=$(echo $LINE | cut -d"," -f3 | sed "s/^\s*//" | sed "s/^.//" | sed "s/.$//");
	if [ -z "$VALUE" ] ; then
		die "Cannot find value for [$1] in [$2]"
	fi
	eval "$1=\"$VALUE\""
	log "read_sqldump: [$1] = [$VALUE]"
}

is_empty() {
    local var=$1

    [[ -z $var ]]
}

is_not_empty() {
    local var=$1

    [[ -n $var ]]
}

is_file() {
    local file=$1

    [[ -f $file ]]
}

is_dir() {
    local dir=$1

    [[ -d $dir ]]
}

# }}}
# Script logic -- TOUCH THIS {{{


# Print usage
usage() {
  echo -n "$PROGNAME [foldername]

Description of this script.

 Options:
  -v, --verbose     Output more
  -h, --help        Display this help and exit
      --version     Output version information and exit
"
}

# Set a trap for cleaning up in case of errors or when script exits.
rollback() {
  die
}

#################################################################################################
# Put your script here
main() {
	out "################################################"
	out "### $PROGNAME $PROGVERSION ($PROGMODIF)"
	out "### CREATE NEW CLONED WORDPRESS INSTALLATION"
	out "################################################"
	
	## GET PARAMETERS
	DAY=$(date '+%Y%m%d')
	TODAY=$(date '+%Y-%m-%d')
	TIME=$(date)
	
	if [ -d "../_backup" ] ; then
		bck_dir="../_backup"
	else 
		ask_param bck_dir	"../_backup"	"In what folder are the clone files?"
	fi
	DEFZIP=$(ls -rt $bck_dir/*.zip | tail -1)
	# ../_backup/_template.20160811.132832.zip
	ask_param bck_zip	"$DEFZIP"	"Which backup file should we use?"
	if [ ! -f "$bck_zip" ] ; then
		die "Clone file [$bck_zip] does not exist"
	fi
	bck_size=$(du -h $bck_zip | awk '{print $1}')
	
	ask_param new_dir	"../$args"	"What is the new WP folder?"
	new_subdir=$(basename "$new_dir")
	
	MAILTXT="$bck_dir/mail.$new_subdir.$TODAY.txt"
	echo "=== $TODAY - WPCLONE" > $MAILTXT
	echo "Executed: $TIME by $USER @ $HOSTNAME" >> $MAILTXT
	echo "Source: $bck_zip ($bck_size)" >> $MAILTXT
	echo "Folder: $new_dir" >> $MAILTXT

	## STEP 1: COPY AND UNZIP WP FILES
	if [ -d "$new_dir" ] ; then
		die "Destination folder [$new_dir] already exists - cannot overwrite"
	fi
	out "Create WP folder [$new_dir]"
	mkdir -pv "$new_dir"
	if [ ! -d "$new_dir" ] ; then
		die "Destination folder [$new_dir] could not be created"
	fi
	unzip -q "$bck_zip" -d "$new_dir"
	WPCFG=$(find "$new_dir" -name wp-config.php)
	old_subdir="_template"
	if [ -n "$WPCFG" ] ; then
		WPDIR=$(dirname $WPCFG)
		if [ "$WPDIR" == "$new_dir" ] ; then
			# nothing to do
			echo "Dest: $new_dir" >> $MAILTXT
		else 
			# move from ./<folder>/wp-... to current folder
			out "move content from [$WPDIR] to [$new_dir]"
			echo "Move: $WPDIR > $new_dir" >> $MAILTXT
			old_subdir=$(basename $WPDIR)
			mv "$WPDIR"/* "$new_dir/"
		fi
	else
		die "Cannot find [wp-config.php] file in [$new_dir]"
	fi
	
	## STEP 2: MODIFY WP_CONFIG
	WPCFG=$(find "$new_dir" -name wp-config.php)
	#set -ex
	read_wpconfig table_prefix "$WPCFG"
	read_wpconfig DB_NAME "$WPCFG"
	read_wpconfig DB_USER "$WPCFG"
	read_wpconfig DB_HOST "$WPCFG"
	read_wpconfig DB_PASSWORD "$WPCFG"
	
	
	old_pre="$table_prefix"
	DEFPREF=$(basename "$new_dir" | cut -c1-3)
	ask_param new_pre	"${DEFPREF}_"	"Table prefix in new WP?"
	if [ "$old_pre" == "$new_pre" ] ; then
		die "You need to use a different table prefix than the existing one [$old_pre]"
	fi
	echo "Prefix: $old_pre > $new_pre" >> $MAILTXT
	WPBACK=$new_dir/old.wp-config.php
	mv "$WPCFG" "$WPBACK"
	< "$WPBACK" sed "s/$old_pre/$new_pre/" > "$WPCFG"
	
	
	## STEP 3: MODIFY SQL FILE AND RESTORE
	SQLDB=$(find "$new_dir" -name *.sql | head -1)
	read_sqldump siteurl "$SQLDB"
	read_sqldump blogname "$SQLDB"
	read_sqldump blogdescription "$SQLDB"
	read_sqldump admin_email "$SQLDB"
	read_sqldump nickname "$SQLDB"
	old_title=$blogname
	ask_param new_title "New blog $DAY" "Blog title for new WP?"
	echo "Title: $new_title" >> $MAILTXT
	
	old_sub=$blogdescription
	ask_param new_sub	"Created with wpclone" "Blog subtitle in new WP?"
	echo "Description: $new_sub" >> $MAILTXT
	
	old_url=$siteurl
	esc_url=$(escape $old_url)
	esc_subdir=$(escape /$old_subdir)
	out "OLD URL: [$old_url]"
	out "ESCAPED: [$esc_url]"
	old_root=$(dirname $old_url)
	ask_param new_url	"$old_root/$new_subdir" "What will be the URL of the new WP?"
	echo "URL: $new_url" >> $MAILTXT
	
	new_sql="$new_dir/createdb.$TODAY.new.sql"

	< "$SQLDB" awk "{
		gsub(/$old_pre/,\"$new_pre\");
		gsub(/$old_title/,\"$new_title\");
		gsub(/$old_sub/,\"$new_sub\");
		gsub(/$esc_url/,\"$new_url\");
		gsub(/$esc_subdir/,\"/_$new_subdir\");
		gsub(/%TODAY%/,\"$TODAY\");
		print;
		}" > $new_sql
	USERLINE=$(grep $new_pre"users" $new_sql | grep INSERT | head -1)
	USERNAME=$(echo "$USERLINE" | cut -d',' -f2 | sed 's/[^a-zA-Z\.@\-\_]//g')
	USERMAIL=$(echo "$USERLINE" | cut -d',' -f5 | sed 's/[^a-zA-Z\.@\-\_]//g')
	#INSERT INTO `joa_users` VALUES (1, 'admin', '<pwhash>', 'admin', 'test@example.com', 'http://www.example.com', '2016-08-10 08:08:10', '', 0, 'admin');
	echo "Admin:    $new_url/wp-admin" >> $MAILTXT
	echo "Username: $USERNAME" >> $MAILTXT
	echo "Password: same as template WP" >> $MAILTXT
	
	
	echo "Password : $DB_PASSWORD"
	echo "Next step: mysql -h $DB_HOST -u $DB_USER -p $DB_NAME < $new_sql"

	cat $MAILTXT | mail -s "WPCLONE: setup new blog $new_title - $new_url" $admin_email
}

#################################################################################################

# }}}
# Boilerplate {{{

# Iterate over options breaking -ab into -a -b when needed and --foo=bar into
# --foo bar
optstring=h
unset options
while (($#)); do
  case $1 in
    # If option is of type -ab
    -[!-]?*)
      # Loop over each character starting with the second
      for ((i=1; i < ${#1}; i++)); do
        c=${1:i:1}

        # Add current char to options
        options+=("-$c")

        # If option takes a required argument, and it's not the last char make
        # the rest of the string its argument
        if [[ $optstring = *"$c:"* && ${1:i+1} ]]; then
          options+=("${1:i+1}")
          break
        fi
      done
      ;;
    # If option is of type --foo=bar
    --?*=*) options+=("${1%%=*}" "${1#*=}") ;;
    # add --endopts for --
    --) options+=(--endopts) ;;
    # Otherwise, nothing special
    *) options+=("$1") ;;
  esac
  shift
done
set -- "${options[@]}"
unset options

# Set our rollback function for unexpected exits.
trap rollback INT TERM EXIT

# A non-destructive exit for when the script exits naturally.
safe_exit() {
  trap - INT TERM EXIT
  exit
}

# }}}
# Main loop {{{

# Print help if no arguments were passed.
[[ $# -eq 0 ]] && set -- "--help"

# Read the options and set stuff
while [[ $1 = -?* ]]; do
  case $1 in
    -v|--verbose) verbose=1 ;;
    -h|--help) usage >&2; safe_exit ;;
    --version) out "$PROGNAME $version"; safe_exit ;;
    --endopts) shift; break ;;
    *) die "invalid option: $1" ;;
  esac
  shift
done

# Store the remaining part as arguments.
args+=("$@")

# }}}
# Run it {{{


# You should delegate your logic from the `main` function
main

# This has to be run last not to rollback changes we've made.
safe_exit

# }}}
