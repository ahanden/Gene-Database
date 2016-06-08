DROP TABLE IF EXISTS `discontinued_genes`;
CREATE TABLE `discontinued_genes` (
	`entrez_id` int(10) unsigned NOT NULL,
	`discontinued_id` int(10) unsigned NOT NULL,
	`discontinued_symbol` varchar(30) DEFAULT NULL,
	PRIMARY KEY (`discontinued_id`),
	KEY `discontinued_symbol` (`discontinued_symbol`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `gene_xrefs`;
CREATE TABLE `gene_xrefs` (
	`entrez_id` int(10) unsigned NOT NULL,
	`Xref_db` varchar(20) NOT NULL,
	`Xref_id` varchar(30) NOT NULL,
	PRIMARY KEY (`entrez_id`,`Xref_db`,`Xref_id`),
	KEY `Xref_db` (`Xref_db`),
	KEY `Xref_id` (`Xref_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `gene_synonyms`;
CREATE TABLE `gene_synonyms` (
	`entrez_id` int(10) unsigned NOT NULL,
	`symbol` varchar(30) NOT NULL,
	PRIMARY KEY (`entrez_id`,`symbol`),
	KEY `symbol` (symbol)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `genes`;
CREATE TABLE `genes` (
	`entrez_id` int(10) unsigned NOT NULL,
	`symbol` varchar(30) DEFAULT NULL,
	`name` varchar(255) DEFAULT NULL,
	`tax_id` int(10) unsigned NOT NULL,
	PRIMARY KEY (`entrez_id`),
	KEY `symbol` (`symbol`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `annotations`;
CREATE TABLE `annotations` (
	`entrez_id` int(10) unsigned NOT NULL,
	`annotation` varchar(255) NOT NULL,
	`db` varchar(255) NOT NULL,
	PRIMARY KEY (`entrez_id`, `annotation`, `db`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
