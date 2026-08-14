set feedback off serveroutput on
spool output\mosaic_testcase01.html
begin
  -- just simple hints
  mozaiek.oplossen
  ( mozaiek.diagram
    ( '221'
    , '  3'
    , ' 8 '
    , '   '
    )
  );
end;
/
spool off
set termout on feedback on
host output\mosaic_testcase01.html
