#Gene-Database
A MySQL database populated from NCBI

##Setting up the database
You will need to create a MySQL database and grant access to the proper users. Once that is done, initialize the database structure using the structure.sql file.

`mysql -u [USER] -p [DATABASE] < structure.sql`

You should re-initialize the database structure every time you update the database.

##Populating the database
To fill a database, simply run `make`. It's that easy!
