#!/bin/bash
while getopts d:s:p: option
do
case "${option}"
in
d) DEST=${OPTARG};;
s) SOURCE=${OPTARG};;
p) MAIN_FOLDER=${OPTARG};;
esac
done

SAN_DEST=${DEST//./}
SAN_SOURCE=${SOURCE//./}

echo "Version :" $DEST;
echo "Source :" $SOURCE;

if [ -d "$MAIN_FOLDER/versions/$DEST" ]
then
  echo "$MAIN_FOLDER/versions/$DEST  directory already exists!"
  exit -1
else
  echo "Starting the copy of $SOURCE to $DEST";
    cp -Rdp $MAIN_FOLDER/versions/$SOURCE $MAIN_FOLDER/versions/$DEST/
    echo "... Done.";

  echo "Cleaning old prestashop cache ($DEST)";
    find $MAIN_FOLDER/versions/$DEST/cache ! -name 'index.php' -type f -exec rm -f {} +
    echo "... Done";

  echo "Cleaning old prestashop img cache ($DEST)";
    find $MAIN_FOLDER/versions/$DEST/img/tmp ! -name 'index.php' -type f -exec rm -f {} +
    echo "... Done";

  echo "Cleaning old prestashop /var/ cache ($DEST)";
    rm -rf $MAIN_FOLDER/versions/$DEST/var/cache
    echo "... Done";

  echo "Config Edit";
    sed -i "s/prestashop$SAN_SOURCE/prestashop$SAN_DEST/g" $MAIN_FOLDER/versions/$DEST/app/config/parameters.php
    echo "... Done";

  echo "Dumping the source database";
    mysqldump -u christophe -p --add-drop-database --routines  --databases prestashop$SAN_SOURCE > $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
    echo "... Done.";

  echo "Changing the database name";
    sed -i "s/prestashop$SAN_SOURCE/prestashop$SAN_DEST/g" $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
    echo "... Done.";

  echo "Changing the prestashop url";
    sed -i "s/staging.manoecrea.com/test.manoecrea.com/g" $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
    echo "... Done";

  echo "Importing the new database";
    mysql -u christophe -p < $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
    echo "... Done.";

  echo "Granting the permissions to prestashop";
    mysql -u christophe -p -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON prestashop"$SAN_DEST".* TO 'prestashop'@'localhost';"
    echo "... Done.";

  echo "Updating the symlink";
    ln -sfn $MAIN_FOLDER/versions/$DEST $MAIN_FOLDER/staging
    echo "... Done";

  echo "Fixing the directories permissions";
    find $MAIN_FOLDER/versions/$DEST -type d -exec chmod 775 {} \;
    echo "... Done";

  echo "Fixing the files permissions";
    find $MAIN_FOLDER/versions/$DEST -type f -exec chmod 664 {} \;
    echo "... Done.";

  echo "Cleaning mysql dump";
      rm $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
      echo "... Done.";

  echo "Don't forget to reload apache to update the symlinks cache"
fi
