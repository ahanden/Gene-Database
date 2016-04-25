#Gene-Database
A MySQL database populated from NCBI

##Dependencies
Before using this code, you will need to have the following installed on your machine:
- Perl
  - DBI
  - Term::ReadKey
  - IO::Handle
- MySQL Server

##Files
This repository has the code to create and update the database, but does not automatically download the files you need. You will need to manually download the following files from the NCBI Gene FTP site ((ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/)):
- gene_info
- gene_history
- gene2accession
- gene_refseq_uniprot_collab

##Setting up the database
You will need to create a MySQL database and grant access to the proper users. Once that is done, initialize the database structure using the structure.sql file.

`mysql -u [USER] -p [DATABASE] < structure.sql`

You should re-initialize the database structure every time you update the database.

##Populating the database
Run the perl scripts included with their specified arguments to update the database. The order in which you run the scripts does not matter.

```
perl gene_info.pl gene_info
perl gene_history.pl gene_history
perl uniprot.pl gene2accession gene_refseq_uniprot_collab 
```

