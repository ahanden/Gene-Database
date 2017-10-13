DROP FUNCTION IF EXISTS symboltoeid;
DROP FUNCTION IF EXISTS valideid;
DROP FUNCTION IF EXISTS xrefeid;

DELIMITER //

CREATE FUNCTION symboltoeid(s VARCHAR(255))
  RETURNS INT(10) UNSIGNED
  BEGIN
  	DECLARE eid INT(10) UNSIGNED;
	SELECT entrez_id INTO eid
		FROM genes
		WHERE symbol = s
		LIMIT 1;

	IF eid IS NULL THEN
		SELECT entrez_id INTO eid
		FROM gene_synonyms
		WHERE symbol = s
		LIMIT 1;
	END IF;

	IF eid IS NULL THEN
		SELECT entrez_id INTO eid
		FROM discontinued_genes
		WHERE discontinued_symbol = s
		LIMIT 1;
	END IF;
	RETURN eid;
  END //

CREATE FUNCTION valideid(eid INT(10) UNSIGNED)
  RETURNS INT(10) UNSIGNED
  BEGIN
	DECLARE veid INT(10) UNSIGNED;
	IF NOT EXISTS(
			SELECT 1
			FROM genes
			WHERE entrez_id = eid) THEN
		SELECT entrez_id INTO veid
		FROM discontinued_genes
		WHERE discontinued_id = eid
		LIMIT 1;
		return veid;
	ELSE
		return eid;
	END IF;
  END //

CREATE FUNCTION xrefeid(xid VARCHAR(255), source VARCHAR(255))
   RETURNS INT(10) UNSIGNED
   BEGIN
   	DECLARE eid INT(10) UNSIGNED;
	SELECT entrez_id INTO eid
	FROM gene_Xrefs
	WHERE Xref_db = source
	AND xref_id = xid
	LIMIT 1;
	RETURN eid;
   END //

DELIMITER ;
