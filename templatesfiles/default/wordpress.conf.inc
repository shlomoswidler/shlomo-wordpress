ServerSignature Off

## Block Sensitive Files ##
Options All -Indexes
<files .htaccess>
Order allow,deny
Deny from all
</files>
<files readme.html>
Order allow,deny
Deny from all
</files>
<files license.txt>
Order allow,deny
Deny from all
</files>
<files install.php>
Order allow,deny
Deny from all
</files>
<files wp-config.php>
Order allow,deny
Deny from all
</files>
<files error_log>
Order allow,deny
Deny from all
</files>
<files fantastico_fileslist.txt>
Order allow,deny
Deny from all
</files>
<files fantversion.php>
Order allow,deny
Deny from all
</files>
