# wpclone
Clone a Wordpress blog to a new subfolder (bash+sql)

Expected folder structure is:

	htdocs				http://www.example.com
	htdocs/_template		http://www.example.com/_template/	Template Wordpress Installation
	htdocs/wpclone			http://www.example.com/wpclone		this script (unavailable online)
	htdocs/_backup			http://www.example.com/_backup/		Backup ZIP files (make this unavailable online!!)
	htdocs/clone1			http://www.example.com/clone1		Clone 1 Wordpress blog

* Typically the template wite will use the tpl_ or wp_ prefix in the database
* every cloned WP site will need a different DB prefix
