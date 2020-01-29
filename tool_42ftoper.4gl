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
DEFINE m_cont DYNAMIC ARRAY OF STRING
DEFINE m_lev SMALLINT = 1
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

	RUN "cat "||l_fileName||".per"

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

	IF l_n IS NULL THEN RETURN END IF
	LET m_lev = m_lev + 1
	WHILE procNode(l_n)
		LET l_c = l_n.getFirstChild()
		IF l_c IS NOT NULL THEN
			CALL procXML(l_c)
		END IF
		LET l_n = l_n.getNext()
	END WHILE
	IF m_lev > 0 THEN
		IF m_cont[m_lev] IS NOT NULL THEN
			CALL m_chan.writeLine(SFMT("%1END -- %2",(m_lev-1) SPACES,m_cont[m_lev]))
		END IF
	END IF
	LET m_lev = m_lev - 1

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procNode(l_n om.domNode)
	IF l_n IS NULL THEN RETURN FALSE END IF
	DISPLAY m_lev,":",l_n.getTagName()
	CASE l_n.getTagName()
		WHEN "Form" CALL procContainer("LAYOUT", l_n)
		WHEN "VBox" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Folder" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Page" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Group" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Grid" CALL procGrid(l_n)
	END CASE
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procGrid(l_n om.domNode)
	LET m_cont[m_lev] = "GRID"
	CALL m_chan.writeLine((m_lev-1) SPACES||"GRID")
	CALL m_chan.writeLine("{")
	CALL m_chan.writeLine("}")
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procContainer(l_tag STRING, l_n om.domNode)
	DEFINE l_line base.StringBuffer
	DEFINE l_att STRING
	DEFINE l_com STRING = "("
	LET m_cont[m_lev] = l_tag
	LET l_line = base.StringBuffer.create()
	CALL l_line.append(SFMT("%1%2 ", (m_lev-1) SPACES,  l_tag ))
	LET l_att = procAttrib(l_n, l_line, l_com, "text")
	IF l_att IS NOT NULL THEN LET l_com = "," END IF
	LET l_att = procAttrib(l_n, l_line, l_com, "style")
	IF l_att IS NOT NULL THEN LET l_com = "," END IF
	IF l_com = "," THEN CALL l_line.append(" )") END IF
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
				SFMT("%1 %2=\"%3\"", l_com, l_nam.toUpperCase(), l_att))
	END IF
	RETURN l_att
END FUNCTION
