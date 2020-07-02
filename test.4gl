MAIN
	DEFINE l_form STRING
	LET l_form = ARG_VAL(1)
	IF l_form IS NULL THEN LET l_form = "generated" END IF
	OPEN FORM f FROM l_form
	DISPLAY FORM f
	MENU
		ON ACTION close EXIT MENU
		ON ACTION quit EXIT MENU
		ON ACTION dump
			CALL ui.window.getCurrent().getNode().getFirstChild().writeXml("dump.xml")
	END MENU
END MAIN
