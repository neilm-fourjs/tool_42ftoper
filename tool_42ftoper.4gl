IMPORT os
DEFINE m_node om.domNode
DEFINE m_chan base.channel
DEFINE m_grid DYNAMIC ARRAY OF RECORD
	line CHAR(200)
END RECORD
DEFINE m_fields DYNAMIC ARRAY OF RECORD
	id STRING,
	typ STRING,
	tab STRING,
	nam STRING,
	wdg STRING,
	att STRING
END RECORD
DEFINE m_fldno SMALLINT = 0
DEFINE m_got_ff BOOLEAN = FALSE
DEFINE m_start_grid BOOLEAN = FALSE
DEFINE m_cont DYNAMIC ARRAY OF RECORD
		typ STRING,
		nam STRING
	END RECORD
DEFINE m_lev SMALLINT = 0
MAIN
	DEFINE l_fileName STRING
	DEFINE x SMALLINT
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

	CALL m_chan.writeLine("ATTRIBUTES")
	FOR x = 1 TO m_fields.getLength()
		CALL m_chan.writeLine( SFMT("%1 f%2 = %3%4;", m_fields[x].wdg, x, m_fields[x].nam, m_fields[x].att ) )
	END FOR

	CALL m_chan.close()

	RUN "cat "||l_fileName||".per"

END MAIN
--------------------------------------------------------------------------------
FUNCTION openFile(l_fname STRING)
	DEFINE l_doc om.domDocument
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
	DEFINE x SMALLINT

	LET m_lev = m_lev + 1
	WHILE procNode(l_n)
		LET l_c = l_n.getFirstChild()
		IF l_c IS NOT NULL THEN
			CALL procXML(l_c)
		END IF
		LET l_n = l_n.getNext()
	END WHILE
	IF m_lev > 0 THEN
		IF m_cont[m_lev].typ IS NOT NULL THEN
			IF m_cont[m_lev].typ = "GRID" THEN
				CALL endGrid()
			ELSE
				CALL endContainer()
			END IF
		END IF
	END IF
	LET m_lev = m_lev - 1

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procNode(l_n om.domNode)
	IF l_n IS NULL THEN RETURN FALSE END IF
	CASE l_n.getTagName()
		WHEN "Form" CALL procContainer("LAYOUT", l_n)
		WHEN "VBox" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Folder" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Page" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Group" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Grid" CALL procGrid(l_n)
		WHEN "RecordView" RETURN TRUE -- DISPLAY "Ignoring RecordView"
		WHEN "Link" RETURN TRUE -- DISPLAY "Ignoring Link"
		OTHERWISE
			CALL procGridItem(l_n)
	END CASE
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procGridItem(l_n om.domNode)
	DEFINE x,y,w, l_nudge SMALLINT
	DEFINE l_txt STRING

	IF l_n.getTagName() = "FormField" THEN
		LET m_fldno = m_fldno + 1
		LET m_fields[ m_fldno ].nam = l_n.getAttribute("name")
		LET m_fields[ m_fldno ].wdg = "EDIT"
		LET m_got_ff = TRUE
		RETURN
	END IF

	IF m_got_ff THEN
		LET m_fields[ m_fldno ].wdg = l_n.getTagName().toUpperCase()
	END IF

	LET x = l_n.getAttribute("posX") + 1
	LET y = l_n.getAttribute("posY")
	LET w = l_n.getAttribute("width")

	LET l_nudge = 0
	WHILE m_grid[y].line[x] != " " AND m_grid[y].line[x] != "]" 
		LET l_nudge = l_nudge + 1
		LET x = x + 1
	END WHILE
	IF m_got_ff THEN
		IF m_grid[y].line[x,x] = "]" THEN
			LET m_grid[y].line[x,x+w] = "|f"||m_fldno
		ELSE
			LET m_grid[y].line[x,x+w] = "[f"||m_fldno
		END IF
		LET m_grid[y].line[x+w+1] = "]"
		DISPLAY SFMT("procGridItem:%1 X=%2 Y=%3 W=%4 FF=%5",l_n.getTagName(), x, y, w, m_fldno )
	ELSE
		LET l_txt = l_n.getAttribute("text")
		LET m_grid[y].line[x,x+l_txt.getLength()] = l_txt
		DISPLAY SFMT("procGridItem:%1 X=%2 Y=%3 W=%4 TXT=%5",l_n.getTagName(), x, y, w, l_txt)
	END IF
	IF l_nudge > 0 THEN
		DISPLAY SFMT("WARNING: Fld: %1 Nudged x by %2 !", m_fields[ m_fldno ].nam, l_nudge )
	END IF
	CALL m_chan.writeLine( m_grid[y].line CLIPPED)

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procGrid(l_n om.domNode)
	DISPLAY "procGrid:",m_lev
	CALL m_grid.clear()
	LET m_cont[m_lev].typ = "GRID"
	CALL m_chan.writeLine("GRID")
	CALL m_chan.writeLine("{")
	LET m_start_grid = TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION endGrid()
	IF m_start_grid THEN
		DISPLAY "EndGrid:",m_lev
		CALL m_chan.writeLine("}")
		LET m_start_grid = FALSE
		CALL m_chan.writeLine("END -- GRID")
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION endContainer()
	DEFINE x SMALLINT
	IF m_cont[ m_lev ].typ IS NULL OR m_cont[ m_lev ].typ = "GRID" THEN RETURN END IF
	DISPLAY "EndContainer:",m_lev,":", m_cont[ m_lev ].typ,":", m_cont[ m_lev ].nam
	CALL m_chan.writeLine(SFMT("%1END -- %2 %3",(m_lev-1) SPACES,m_cont[m_lev].typ, m_cont[m_lev].nam))
	FOR x = m_lev TO m_cont.getLength()
		CALL m_cont.deleteElement(x)
	END FOR
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procContainer(l_tag STRING, l_n om.domNode)
	DEFINE l_line base.StringBuffer
	DEFINE l_att, l_nam STRING
	DEFINE l_com STRING = "("

	CALL endGrid()
	LET l_nam = l_n.getAttribute("name")
	DISPLAY "procContainer:",m_lev,":",l_tag,":",l_nam,":",l_n.getAttribute("text")

	IF m_cont[m_lev].typ IS NOT NULL THEN
		CALL endContainer()
	END IF

	LET m_cont[m_lev].typ = l_tag
	LET m_cont[m_lev].nam = l_nam
	LET l_line = base.StringBuffer.create()
	CALL l_line.append(SFMT("%1%2 ", (m_lev-1) SPACES,  l_tag))
	IF l_tag != "LAYOUT" AND l_nam IS NOT NULL THEN
		CALL l_line.append(l_nam||" ")
	END IF
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
		CALL l_line.append(SFMT("%1 %2=\"%3\"", l_com, l_nam.toUpperCase(), l_att))
	END IF
	RETURN l_att
END FUNCTION
