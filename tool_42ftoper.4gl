IMPORT os
DEFINE m_node om.domNode
DEFINE m_chan base.channel
DEFINE m_scr DYNAMIC ARRAY OF RECORD
	line CHAR(200)
END RECORD
DEFINE m_fields DYNAMIC ARRAY OF RECORD
	id STRING,
	typ STRING,
	tab STRING,
	nam STRING,
	att STRING
END RECORD

MAIN
	DEFINE l_fileName STRING
	LET m_chan = base.Channel.create()

	LET l_fileName = ARG_VAL(1)
	IF os.path.exists(l_fileName || ".per") THEN
		IF NOT os.path.exists(l_fileName || ".per") THEN
			IF os.path.copy(l_fileName || ".per", l_fileName || ".per.bak") THEN
				DISPLAY SFMT("Failed to backup %1.per", l_fileName)
				EXIT PROGRAM
			END IF
		END IF
	END IF
	IF NOT os.path.exists(l_fileName || ".42f.sav") THEN
		IF NOT os.path.exists(l_fileName || ".42f") THEN
			DISPLAY SFMT("Not found %1.42f", l_fileName)
			EXIT PROGRAM
		END IF
		IF NOT os.path.rename(l_fileName || ".42f", l_fileName || ".42f.sav") THEN
			DISPLAY SFMT("Failed to rename %1.42f", l_fileName)
			EXIT PROGRAM
		END IF
	END IF

	CALL openFile(l_fileName || ".42f.sav")

	CALL m_chan.openFile(l_fileName || ".per", "w")

	CALL procXML(m_node)

	CALL m_chan.close()

END MAIN
--------------------------------------------------------------------------------
FUNCTION openFile(l_fname STRING)
	DEFINE l_doc om.domDocument

	CALL m_scr.clear()
	CALL m_fields.clear()

	LET l_doc = om.DomDocument.create("Form")
	LET m_node = l_doc.getDocumentElement()
	DISPLAY "Reading ", l_fname.trim(), " ..."
	LET m_node = m_node.loadXml(l_fname)
	IF m_node IS NULL THEN
		DISPLAY "Failed to read:", l_fname
		EXIT PROGRAM
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procXML(l_n om.domNode)
	DEFINE l_c om.domNode

	IF l_n IS NULL THEN
		RETURN
	END IF
	WHILE procNode(l_n)
		LET l_c = l_n.getFirstChild()
		IF l_c IS NOT NULL THEN
			CALL procXML(l_c)
		END IF
		LET l_n = l_n.getNext()
	END WHILE

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procNode(l_n om.domNode)
	IF l_n IS NULL THEN
		RETURN FALSE
	END IF
	DISPLAY l_n.getTagName()
	CASE l_n.getTagName()
		WHEN "Form"
			CALL procLayout(l_n)
	END CASE
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procLayout(l_n om.domNode)
	DEFINE l_line base.StringBuffer
	DEFINE l_att STRING
	DEFINE l_com STRING
	LET l_line = base.StringBuffer.create()
	CALL l_line.append("LAYOUT (")
	LET l_att = procAttrib(l_n, l_line, l_com, "text")
	IF l_att IS NOT NULL THEN
		LET l_com = ","
	END IF
	LET l_att = procAttrib(l_n, l_line, l_com, "style")
	IF l_att IS NOT NULL THEN
		LET l_com = ","
	END IF
	CALL l_line.append(" )")
	CALL m_chan.writeLine(l_line.toString())
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procAttrib(
		l_n om.domNode, l_line base.StringBuffer, l_com STRING, l_nam STRING)
		RETURNS STRING
	DEFINE l_att STRING
	LET l_att = l_n.getAttribute(l_nam)
	IF l_att IS NOT NULL THEN
		CALL l_line.append(
				SFMT("%1 %2=\"%3\"", l_com.trim(), l_nam.toUpperCase(), l_att))
	END IF
	RETURN l_att
END FUNCTION
