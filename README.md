# wpclone
Clone a Wordpress blog to a new subfolder (bash+sql)

* 
* Typically the template site will use the tpl_ or wp_ prefix in the database
* every cloned WP site will need a different DB prefix
* uses a backup of the WP site created with the CYAN Backup plugin
* copy all Wordpress files
* change wp-config.php file (different DB prefix)
* change DB export file (different DB prefix, title, ...)

Expected folder structure is:

	htdocs				http://www.example.com			
	htdocs/_template		http://www.example.com/_template/	Template Wordpress Installation
	htdocs/wpclone			http://www.example.com/wpclone		this script (unavailable online)
	htdocs/_backup			http://www.example.com/_backup/		Backup ZIP files (make this unavailable online!!)
	htdocs/clone1			http://www.example.com/clone1		Clone 1 Wordpress blog
	htdocs/clone2			http://www.example.com/clone2		Clone 2 Wordpress blog

