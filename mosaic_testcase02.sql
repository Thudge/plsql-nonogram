set feedback off serveroutput on
spool output\mosaic_testcase02.html
begin
  -- just 3 hints
  mozaiek.oplossen
  ( mozaiek.diagram
    ( '   '
    , ' 8 '
    , ' 53'
    )
  );
end;
/
spool off
set termout on feedback on
host output\mosaic_testcase02.html
