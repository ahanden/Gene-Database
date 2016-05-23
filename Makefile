
# Variables
DATE ?= `date +%Y_%m_%d`
DATA_DIR ?= data

SPECIES=9606

all : update
	tar -cvf backup.$(DATE).tar $(DATA_DIR)/
	7z a backup.$(DATE).tar.7z backup.$(DATE).tar
	rm backup.$(DATE).tar
	rm -f auth.cnf

# Gene Info
$(DATA_DIR)/genes.sql $(DATA_DIR)/gene_synonyms.sql : structure $(DATA_DIR)/gene_info
	perl gene_info.pl -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene_info
	DB=$$(grep -P "^database=" auth.cnf | sed 's/^database=//'); \
	mysqldump --defaults-file=auth.cnf $${DB} genes > $(DATA_DIR)/genes.sql; \
	mysqldump --defaults-file=auth.cnf $${DB} gene_synonyms > $(DATA_DIR)/gene_synonyms.sql;
$(DATA_DIR)/gene_info :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_info.gz --output-document=$(DATA_DIR)/gene_info.gz
	gunzip $(DATA_DIR)/gene_info.gz

# Gene History
$(DATA_DIR)/discontinued_genes.sql : structure $(DATA_DIR)/gene_history
	perl gene_history.pl -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene_history
	DB=$$(grep -P "^database=" auth.cnf | sed 's/^database=//'); \
	mysqldump --defaults-file=auth.cnf $${DB} discontinued_genes> $(DATA_DIR)/discontinued_genes.sql
$(DATA_DIR)/gene_history :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_history.gz --output-document=$(DATA_DIR)/gene_history.gz
	gunzip $(DATA_DIR)/gene_history.gz

# Gene To Accession
$(DATA_DIR)/gene_xrefs.sql : structure $(DATA_DIR)/genes.sql $(DATA_DIR)/gene2accession $(DATA_DIR)/gene_refseq_uniprotkb_collab $(DATA_DIR)/sec_ac.txt
	perl uniprot.pl -s $(SPECIES) -c auth.cnf $(DATA_DIR)/gene2accession $(DATA_DIR)/gene_refseq_uniprotkb_collab
	perl sec_ac.pl -c auth.cnf $(DATA_DIR)/sec_ac.txt
	DB=$$(grep -P "^database=" auth.cnf | sed 's/^database=//'); \
	mysqldump --defaults-file=auth.cnf $${DB} gene_xrefs> $(DATA_DIR)/gene_xrefs.sql
$(DATA_DIR)/gene2accession :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2accession.gz --output-document=$(DATA_DIR)/gene2accession.gz
	gunzip $(DATA_DIR)/gene2accession.gz
$(DATA_DIR)/gene_refseq_uniprotkb_collab :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_refseq_uniprotkb_collab.gz --output-document=$(DATA_DIR)/gene_refseq_uniprotkb_collab.gz 
	gunzip $(DATA_DIR)/gene_refseq_uniprotkb_collab.gz
$(DATA_DIR)/sec_ac.txt :
	wget ftp://ftp.uniprot.org/pub/databases/uniprot/knowledgebase/docs/sec_ac.txt --output-document=$(DATA_DIR)/sec_ac.txt

# Remove the data files
clean :
	rm -f $(DATA_DIR)/gene_info
	rm -f $(DATA_DIR)/gene_history
	rm -f $(DATA_DIR)/gene2accession
	rm -f $(DATA_DIR)/gene_refseq_uniprot_collab
	rm -f $(DATA_DIR)/sec_ac.txt
	rm -f auth.cnf

# Update the database
update : structure $(DATA_DIR)/gene_info $(DATA_DIR)/gene_history $(DATA_DIR)/gene2accession $(DATA_DIR)/gene_refseq_uniprotkb_collab $(DATA_DIR)/sec_ac.txt
	perl gene_info.pl    -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene_info
	perl gene_history.pl -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene_history
	perl uniprot.pl      -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene2accession $(DATA_DIR)/gene_refseq_uniprotkb_collab
	perl sec_ac.pl       -c auth.cnf -v $(DATA_DIR)/sec_ac.txt

# Apply the database structure
structure : auth.cnf
	mysql --defaults-file=auth.cnf < structure.sql

# Database credentials
auth.cnf :
	@echo "[client]" > auth.cnf
	@read -p "Database: " db; echo "database=$$db" >> auth.cnf
	@read -p "Username: " user; echo "user=$$user" >> auth.cnf
	@read -s -p "Password: " passwd; echo "password=$$passwd" >> auth.cnf
	chmod 400 auth.cnf
