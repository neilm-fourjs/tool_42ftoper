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
	ftag STRING,
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
DEFINE m_pageSize SMALLINT = 0
DEFINE m_lev SMALLINT = 0
DEFINE m_scrrecs DYNAMIC ARRAY OF STRING
DEFINE m_scrrecs_f DYNAMIC ARRAY OF STRING
DEFINE m_next_single_tag SMALLINT = 1
DEFINE m_genTable BOOLEAN = FALSE

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
	CALL m_chan.writeLine(SFMT("-- Generated by %1 on %2", base.Application.getProgramName(), CURRENT))

	CALL procXML(m_node) -- pre layout

	CALL procXML2(m_node) -- layout

	CALL m_chan.writeLine("")
	CALL m_chan.writeLine("ATTRIBUTES")
	FOR x = 1 TO m_fields.getLength()
		CALL m_chan.writeLine( SFMT("%1 %2 = %3%4;", m_fields[x].wdg, m_fields[x].ftag, m_fields[x].nam, m_fields[x].att ) )
	END FOR
	IF m_scrrecs.getLength() > 0 THEN
		CALL m_chan.writeLine("")
		CALL m_chan.writeLine("INSTRUCTIONS")
		FOR x = 1 TO m_scrrecs.getLength()
			CALL m_chan.writeLine( SFMT("SCREEN RECORD %1 ( %2 );", m_scrrecs[x], m_scrrecs_f[x] ) )
		END FOR
	END IF

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
			CALL endContainer()
		END IF
	END IF
	LET m_lev = m_lev - 1

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procNode(l_n om.domNode)
	IF l_n IS NULL THEN RETURN FALSE END IF
	CASE l_n.getTagName()
		WHEN "ToolBar" CALL procToolBar(l_n)
		WHEN "ToolBarItem" CALL procToolBar(l_n)
		WHEN "TopMenu" -- ignore
		WHEN "TopMenuItem" -- ignore
		WHEN "ActionDefaults" -- ignore
		WHEN "Action" -- ignore
	END CASE
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procXML2(l_n om.domNode)
	DEFINE l_c om.domNode
	DEFINE x SMALLINT

	LET m_lev = m_lev + 1
	WHILE procNode2(l_n)
		LET l_c = l_n.getFirstChild()
		IF l_c IS NOT NULL THEN
			CALL procXML2(l_c)
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
FUNCTION procNode2(l_n om.domNode)
	IF l_n IS NULL THEN RETURN FALSE END IF
	CASE l_n.getTagName()
		WHEN "Form" CALL procContainer("LAYOUT", l_n)
		WHEN "ToolBar" -- ignore
		WHEN "ToolBarItem" -- ignore
		WHEN "TopMenu" -- ignore
		WHEN "TopMenuItem" -- ignore
		WHEN "ActionDefaults" -- ignore
		WHEN "Action" -- ignore
		WHEN "RipGraphic" -- ignore
		WHEN "VBox" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Folder" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Page" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Group" CALL procContainer(l_n.getTagName().toUpperCase(),l_n)
		WHEN "Grid" CALL procGrid(l_n)
		WHEN "Screen" CALL procGrid(l_n) -- treat legacy Screen as a grid.
		WHEN "RecordView" CALL procRecordView(l_n)
		WHEN "Link" RETURN TRUE -- procRecordView processes the links
		OTHERWISE
			CALL procGridItem(l_n)
	END CASE
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procToolBar(l_n om.domNode)
	IF l_n.getTagName() = "ToolBar" THEN
		CALL m_chan.writeLine( "TOOLBAR" )
		LET m_cont[m_lev].typ = "TOOLBAR"
	END IF
	IF l_n.getTagName() = "ToolBarItem" THEN
		CALL m_chan.writeLine( " ITEM "||l_n.getAttribute("name") )
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION procGridItem(l_n om.domNode)
	DEFINE x, y, w, y_arr, l_nudge SMALLINT
	DEFINE l_tag, l_txt STRING

	LET l_tag = l_n.getTagName()
	IF l_tag = "Matrix" THEN
		IF genTable( l_n ) THEN
			LET y = y + 1
		END IF
	END IF
	IF l_tag = "FormField" OR l_tag = "TableColumn" OR l_tag = "Matrix" THEN
		IF l_tag = "FormField" THEN LET m_pageSize = 0 END IF
		LET m_fldno = m_fldno + 1
		LET m_fields[ m_fldno ].nam = l_n.getAttribute("name")
		LET m_fields[ m_fldno ].wdg = "EDIT"
		IF l_n.getAttribute("notNull") = "1" THEN
			LET m_fields[ m_fldno ].att = m_fields[ m_fldno ].att.append(", NOT NULL")
		END IF
		IF l_n.getAttribute("required") = "1" THEN
			LET m_fields[ m_fldno ].att = m_fields[ m_fldno ].att.append(", REQUIRED")
		END IF
		LET m_got_ff = TRUE
		RETURN
	END IF

	LET l_txt = l_n.getAttribute("text")
	LET x = l_n.getAttribute("posX") + 1
	LET y = l_n.getAttribute("posY") + 1
	LET w = l_n.getAttribute("width")

	IF m_got_ff THEN
		LET m_fields[ m_fldno ].wdg = l_n.getTagName().toUpperCase()
		LET m_fields[ m_fldno ].ftag = "f"||m_fldno
		IF l_n.getTagName() = "CheckBox" AND l_txt.getLength() > 0 THEN
			LET m_fields[ m_fldno ].att = ",TEXT=\""||l_txt||"\""
		END IF
		IF l_n.getAttribute("valueMax") IS NOT NULL THEN
			LET m_fields[ m_fldno ].att = m_fields[ m_fldno ].att.append(", VALUEMAX="||l_n.getAttribute("valueMax") )
		END IF
		IF l_n.getAttribute("valueMin") IS NOT NULL THEN
			LET m_fields[ m_fldno ].att = m_fields[ m_fldno ].att.append(", VALUEMIN="||l_n.getAttribute("valueMin") )
		END IF
		IF l_n.getAttribute("shift") = "up" THEN
			LET m_fields[ m_fldno ].att = m_fields[ m_fldno ].att.append(", UPSHIFT")
		END IF
		IF l_n.getAttribute("shift") = "down" THEN
			LET m_fields[ m_fldno ].att = m_fields[ m_fldno ].att.append(", DOWNSHIFT")
		END IF
	END IF

	LET l_nudge = 0
	DISPLAY "Grid y:",y," x:",x, " w:",w," txt:",l_txt," wdg:", l_n.getTagName()
	WHILE m_grid[y].line[x] != " " AND m_grid[y].line[x] != "]" 
		LET l_nudge = l_nudge + 1
		LET x = x + 1
	END WHILE
	IF m_got_ff THEN
		IF w = 1 THEN
			LET m_fields[ m_fldno ].ftag = ASCII(96+m_next_single_tag)
			LET m_next_single_tag = m_next_single_tag + 1
		END IF
		IF m_grid[y].line[x] = "]" THEN
			LET m_grid[y].line[x,x+w] = "|"||m_fields[ m_fldno ].ftag
		ELSE
			LET m_grid[y].line[x,x+w] = "["||m_fields[ m_fldno ].ftag
		END IF
		LET m_grid[y].line[x+w+1] = "]"
		DISPLAY SFMT("procGridItem:%1 X=%2 Y=%3 W=%4 FF=%5",l_n.getTagName(), x, y, w, m_fldno )
		IF m_pageSize > 0 THEN
			DISPLAY SFMT("Adding array lines: %1 to %2", y+1, y+(m_pageSize-1) )
			FOR y_arr = y+1 TO y+(m_pageSize-1)
				IF m_grid[y_arr].line[x] = "]" THEN
					LET m_grid[y_arr].line[x,x+w] = "|"||m_fields[ m_fldno ].ftag
				ELSE
					LET m_grid[y_arr].line[x,x+w] = "["||m_fields[ m_fldno ].ftag
				END IF
				LET m_grid[y_arr].line[x+w+1] = "]"
			END FOR
		END IF
	ELSE
		IF m_grid[y].line[x] = "]" THEN
			LET l_nudge = l_nudge + 1
			LET x = x + 1
		END IF
		IF l_txt IS NULL OR l_txt.getLength() < 1 THEN LET l_txt = "[\"\"]" END IF
		LET m_grid[y].line[x,x+l_txt.getLength()] = l_txt
		DISPLAY SFMT("procGridItem:%1 X=%2 Y=%3 W=%4 TXT=%5",l_n.getTagName(), x, y, w, NVL(l_txt,"NULL"))
	END IF
	IF l_nudge > 0 THEN
		DISPLAY SFMT("WARNING: Fld: %1 Nudged x by %2 !", m_fields[ m_fldno ].nam, l_nudge )
	END IF

	LET m_got_ff = FALSE

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
	DEFINE x SMALLINT
	IF m_start_grid THEN
		DISPLAY "EndGrid:",m_lev
		FOR x = 1 TO m_grid.getLength()
			IF m_grid[x].line IS NOT NULL THEN
				CALL m_chan.writeLine( m_grid[x].line CLIPPED)
			ELSE
				CALL m_chan.writeLine( "[\"\"]" )
			END IF
		END FOR
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
	CALL m_chan.writeLine(SFMT("END -- %1 %2",m_cont[m_lev].typ, m_cont[m_lev].nam))
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
	CALL l_line.append(l_tag||" ")
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
--------------------------------------------------------------------------------
FUNCTION procRecordView( l_n om.domNode )
	DEFINE l_nam STRING	
	DEFINE x SMALLINT
	DEFINE l_n_link om.domNode
	LET l_nam = l_n.getAttribute("tabName")
	DISPLAY "procRecordView: ", l_nam
	IF l_nam = "formonly" THEN RETURN END IF
	FOR x = 1 TO m_scrrecs.getLength()
		IF m_scrrecs[x] = l_nam THEN EXIT FOR END IF
	END FOR
	IF x > m_scrrecs.getLength() THEN
		LET m_scrrecs[ x ] = l_n.getAttribute("tabName")
	END IF
	LET l_n_link = l_n.getFirstChild()
	WHILE l_n_link IS NOT NULL 
		LET m_scrrecs_f[x] = m_scrrecs_f[x].append( l_n_link.getAttribute("colName") )
		LET l_n_link = l_n_link.getNext()
		IF l_n_link IS NOT NULL THEN
			LET m_scrrecs_f[x] = m_scrrecs_f[x].append( ", " )
		END IF
	END WHILE
END FUNCTION
--------------------------------------------------------------------------------
-- In all the Matrix elements are on the same line, try and make table.
FUNCTION genTable( l_n om.domNode )
	DEFINE l_n1 om.domNode
	DEFINE l_nl om.nodeList
	DEFINE x, y, x1, x2, r, p, ps, w SMALLINT
	DISPLAY "genTable:", m_genTable
	IF m_genTable THEN RETURN TRUE END IF
	LET l_n1 = l_n.getParent()
	LET l_nl = l_n1.selectByTagName("Matrix")
	LET r = 0
	LET ps = 0
	LET w = 0
	LET x1 = 0
	FOR x = 1 TO l_nl.getLength()
		LET l_n = l_nl.item(x)
		LET p = l_n.getAttribute("pageSize")
		IF ps = 0 THEN LET ps = p END IF
		LET m_pageSize = p
		DISPLAY "Matrix: pageSize: ",m_pageSize
		IF p != ps THEN
			# Matrix elements are not all the same pageSize! - abort
			RETURN FALSE
		END IF
		LET l_n = l_n.getFirstChild()
		LET y = l_n.getAttribute("posY")	
		IF x1 = 0 THEN
			LET x1 = l_n.getAttribute("posX")	
		END IF
		LET x2 = l_n.getAttribute("posX")	-- we need x of the last column
		LET w = l_n.getAttribute("gridWidth")	 -- we need the width of the last column
		IF r = 0 THEN LET r = y END IF	
		IF r != y THEN
			# Matrix elements are not all on the same line! - abort	
			RETURN FALSE
		END IF
	END FOR	
	LET m_genTable = TRUE
	IF x1 = 1 THEN LET x1 = 1 END IF
	LET m_grid[y].line[x1,x1+5] = "<T tab"
	IF w < 7 THEN LET w = 7 END IF
	LET m_grid[y].line[x2+w+3] = ">"
	DISPLAY SFMT("x1: %1 x2: %2 w: %3", x1,x2,w)

	RETURN TRUE

END FUNCTION
